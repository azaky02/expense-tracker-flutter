import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/core/db/seed.dart';
import 'package:expense_tracker_flutter/features/backup/data/backup_service.dart';
import 'package:expense_tracker_flutter/features/backup/data/email_backup.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('daily e-mail backup: sends once a day, encrypted attachment, errors kept', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedIfNeeded(db);

    // Not set up yet: nothing is sent.
    var calls = 0;
    Map<String, dynamic>? body;
    String? keyHeader;
    final ok = MockClient((req) async {
      calls++;
      body = jsonDecode(req.body) as Map<String, dynamic>;
      keyHeader = req.headers['api-key'];
      return http.Response('{"messageId":"x"}', 201);
    });
    expect(await sendEmailBackup(db, client: ok), isNull);
    expect(calls, 0);

    await EmailBackupStore.save(enabled: true, to: 'me@example.com', from: 'me@example.com', apiKey: 'test-key', password: 'secret123');
    expect(await sendEmailBackup(db, client: ok), isNull);
    expect(calls, 1);
    expect(keyHeader, 'test-key');
    expect((body!['to'] as List).single['email'], 'me@example.com');
    final att = (body!['attachment'] as List).single as Map<String, dynamic>;
    // The attachment is a real backup that opens with the password.
    final file = utf8.decode(base64Decode(att['content'] as String));
    final contents = await BackupService(db).open(file, 'secret123');
    expect(contents, isNotNull);

    // Same day again: not sent twice.
    expect(await sendEmailBackup(db, client: ok), isNull);
    expect(calls, 1);

    // A failure is reported and remembered.
    final bad = MockClient((_) async => http.Response('{"code":"unauthorized"}', 401));
    expect(await sendEmailBackup(db, force: true, client: bad), 'http_401');
    expect((await EmailBackupStore.load()).lastError, 'http_401');
    await db.close();
  });
}
