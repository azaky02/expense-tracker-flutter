import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('opening an encrypted database with the wrong key fails with SQLITE_NOTADB (26)', () {
    final path = '${Directory.systemTemp.createTempSync('keycheck').path}/x.sqlite';
    final a = sqlite3.open(path)..execute("PRAGMA key = 'right';");
    a.execute('CREATE TABLE t(x); INSERT INTO t VALUES (1);');
    a.close();
    final b = sqlite3.open(path)..execute("PRAGMA key = 'wrong';");
    expect(() => b.select('SELECT count(*) FROM sqlite_master'),
        throwsA(isA<SqliteException>().having((e) => e.resultCode, 'resultCode', 26)));
    b.close();
    final c = sqlite3.open(path)..execute("PRAGMA key = 'right';");
    expect(c.select('SELECT x FROM t').single['x'], 1);
    c.close();
  });
}
