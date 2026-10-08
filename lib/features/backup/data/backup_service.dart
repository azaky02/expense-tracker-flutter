import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/sync/sync_schema.dart';

/// Encrypted backup of everything on the device (UI/UX §17, design doc §17 "Mobile backup").
///
/// File = small JSON envelope {format, version, kdf, salt, nonce, mac, data}, where data is the
/// AES-256-GCM encryption of the JSON dump. The key comes from the user's backup password through
/// PBKDF2-SHA256 (150k rounds), so the file is useless without the password. Attachment photos are
/// not included (they stay on the device).
class BackupService {
  BackupService(this._db);
  final AppDatabase _db;

  static const format = 'masarefy-backup';
  static const _iterations = 150000;

  /// Tables in insert order (parents first).
  List<TableInfo<Table, dynamic>> get _tables => [
        _db.banks,
        _db.categories,
        _db.cards,
        _db.accounts,
        _db.people,
        _db.beneficiaries,
        _db.transactions,
        _db.categoryBudgets,
        _db.ledgerEntries,
        _db.ledgerOutbox,
        _db.appNotifications,
      ];

  Future<SecretKey> _key(String password, List<int> salt) => Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: _iterations, bits: 256)
      .deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  Future<Map<String, dynamic>> _dump() async {
    final tables = <String, List<Map<String, dynamic>>>{};
    for (final t in _tables) {
      final rows = await _db.customSelect('SELECT * FROM ${t.actualTableName}').get();
      tables[t.actualTableName] = [for (final r in rows) r.data];
    }
    return {'schemaVersion': _db.schemaVersion, 'createdAt': DateTime.now().toUtc().toIso8601String(), 'tables': tables};
  }

  /// Returns the encrypted backup file content.
  Future<String> export(String password) async {
    final plain = utf8.encode(jsonEncode(await _dump()));
    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    final algo = AesGcm.with256bits();
    final box = await algo.encrypt(plain, secretKey: await _key(password, salt));
    return jsonEncode({
      'format': format,
      'version': 1,
      'kdf': {'name': 'pbkdf2-sha256', 'iterations': _iterations, 'salt': base64Encode(salt)},
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'data': base64Encode(box.cipherText),
    });
  }

  /// Decrypts and validates a backup without touching the database. Throws [BackupException].
  Future<BackupContents> open(String fileContent, String password) async {
    Map<String, dynamic> env;
    try {
      env = jsonDecode(fileContent) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException('not_a_backup');
    }
    if (env['format'] != format) throw const BackupException('not_a_backup');
    final kdf = env['kdf'] as Map<String, dynamic>;
    final salt = base64Decode(kdf['salt'] as String);
    final key = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: (kdf['iterations'] as num).toInt(), bits: 256)
        .deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
    List<int> plain;
    try {
      plain = await AesGcm.with256bits().decrypt(
        SecretBox(base64Decode(env['data'] as String), nonce: base64Decode(env['nonce'] as String), mac: Mac(base64Decode(env['mac'] as String))),
        secretKey: key,
      );
    } on SecretBoxAuthenticationError {
      throw const BackupException('wrong_password');
    }
    final dump = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    if (((dump['schemaVersion'] as num?) ?? 0) > _db.schemaVersion) throw const BackupException('newer_version');
    return BackupContents(dump);
  }

  /// Replaces all data on this device with the backup. Restored rows are marked as local changes
  /// so a signed-in account receives them on the next sync.
  Future<void> restore(BackupContents contents) async {
    final tables = (contents.dump['tables'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as List).cast<Map<String, dynamic>>()));
    await _db.transaction(() async {
      await _db.customStatement("INSERT OR REPLACE INTO meta(key, value) VALUES ('$syncApplyingKey', '1')");
      for (final t in _tables.reversed) {
        await _db.customStatement('DELETE FROM ${t.actualTableName}');
      }
      await _db.customStatement('DELETE FROM sync_tombstones');
      for (final t in _tables) {
        final rows = tables[t.actualTableName] ?? const [];
        final columns = {for (final c in t.$columns) c.name};
        for (final row in rows) {
          final data = {for (final e in row.entries) if (columns.contains(e.key)) e.key: e.value};
          if (data.isEmpty) continue;
          final names = data.keys.toList();
          await _db.customInsert(
            'INSERT INTO ${t.actualTableName} (${names.join(',')}) VALUES (${List.filled(names.length, '?').join(',')})',
            variables: [for (final n in names) _variable(data[n])],
          );
        }
      }
      for (final t in syncTables) {
        await _db.customStatement("UPDATE ${t.table} SET dirty = 1, updated_at = CAST(strftime('%s','now') AS INTEGER)");
      }
      // The ledger replica is re-read from the server in full on the next sync.
      await _db.customStatement("DELETE FROM meta WHERE key IN ('sync_ledger_cursor', 'sync_notification_cursor', 'sync_cursor')");
      await _db.customStatement("DELETE FROM meta WHERE key = '$syncApplyingKey'");
    });
    _db.notifyUpdates({for (final t in _tables) TableUpdate.onTable(t)});
  }

  Variable _variable(Object? v) => switch (v) {
        null => const Variable(null),
        final int i => Variable.withInt(i),
        final double d => Variable.withReal(d),
        final bool b => Variable.withBool(b),
        final String s => Variable.withString(s),
        _ => Variable.withString(v.toString()),
      };
}

class BackupContents {
  const BackupContents(this.dump);
  final Map<String, dynamic> dump;

  DateTime? get createdAt => DateTime.tryParse(dump['createdAt'] as String? ?? '')?.toLocal();
  int count(String table) => ((dump['tables'] as Map<String, dynamic>)[table] as List?)?.length ?? 0;
}

class BackupException implements Exception {
  const BackupException(this.code);
  final String code;
  @override
  String toString() => 'BackupException($code)';
}
