import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

import '../security/secure_storage.dart';
import 'database.dart' show unreadableDbRecoveredKey;

Future<File> _databaseFile() async {
  final dir = await getApplicationSupportDirectory();
  return File(p.join(dir.path, 'expense_tracker.sqlite'));
}

/// Preserve the existing encrypted native database and recovery behavior.
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
      if (e.resultCode == 26) readable = false;
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
    // Native database opening reports any remaining error.
  }
}

LazyDatabase openConnection() {
  return LazyDatabase(() async {
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
