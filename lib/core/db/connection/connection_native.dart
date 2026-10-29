import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

import '../../security/secure_storage.dart';
import '../database.dart' show unreadableDbRecoveredKey;

Future<File> _databaseFile() async {
  final dir = await getApplicationSupportDirectory();
  return File(p.join(dir.path, 'expense_tracker.sqlite'));
}

/// Runs before the app starts. If the database file exists but cannot be decrypted with the key in
/// the keystore (e.g. Android restored the file after a reinstall, but never restores keystore
/// keys), the file is moved aside so the app starts with a fresh database instead of failing.
/// The old app-lock settings are cleared too, because the PIN lived in the same lost storage.
Future<void> ensureDatabaseReadable() async {
  try {
    final file = await _databaseFile();
    if (!await file.exists()) return;
    final key = await SecureStorageService.instance.getOrCreateDbEncryptionKey();
    var readable = true;
    final db = raw.sqlite3.open(file.path);
    try {
      db.execute("PRAGMA key = '$key';");
      db.select('SELECT count(*) FROM sqlite_master');
    } on raw.SqliteException catch (e) {
      if (e.resultCode == 26) readable = false; // SQLITE_NOTADB: wrong key
    } finally {
      db.close();
    }
    if (readable) return;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final f = File('${file.path}$suffix');
      if (await f.exists()) await f.rename('${file.path}.unreadable-$stamp$suffix');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(unreadableDbRecoveredKey, true);
    await prefs.setBool('settings.appLockEnabled', false);
    await prefs.setBool('settings.biometricEnabled', false);
    await prefs.remove('settings.userPhone');
    await SecureStorageService.instance.clearPin();
  } catch (_) {
    // Never block start-up here; opening the database reports any real problem.
  }
}

/// Opens the encrypted database on a background isolate.
///
/// sqlite3_flutter_libs / sqlcipher_flutter_libs are both EOL — encryption is configured via
/// the `hooks.user_defines.sqlite3.source: sqlite3mc` key in pubspec.yaml, which builds the
/// SQLite3MultipleCiphers native library instead of the old separate plugin packages.
/// SQLite3MultipleCiphers implements the standard SQLite C API, so NativeDatabase needs no
/// code changes beyond running `PRAGMA key` in the `setup` callback below.
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    // getApplicationSupportDirectory (not ApplicationDocuments) — excluded from iCloud backup
    // on iOS, since attachment photos referenced from this DB may contain financial receipts.
    final file = await _databaseFile();
    final key = await SecureStorageService.instance.getOrCreateDbEncryptionKey();

    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        rawDb.execute("PRAGMA key = '$key';");
      },
    );
  });
}
