// End-to-end sync test: two in-memory "devices" against the real Node server (spawned here).
// Needs Node, the local Postgres on :5433 (see server/.env.example) and `npm install` in server/.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/core/db/seed.dart';
import 'package:expense_tracker_flutter/core/db/tables.dart';
import 'package:expense_tracker_flutter/core/sync/sync_api.dart';
import 'package:expense_tracker_flutter/core/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _port = 4377;
final _url = 'http://127.0.0.1:$_port';
late Process _server;

Future<AppDatabase> _device() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await seedIfNeeded(db);
  return db;
}

Future<SyncService> _login(AppDatabase db, String email, {bool register = false}) async {
  final api = SyncApi(_url);
  final session = register
      ? await api.register(email, 'password123', 'T', null)
      : await api.login(email, 'password123');
  final svc = SyncService(db, SyncApi(_url, session: session));
  await svc.prepareForAccount(session.userId);
  return svc;
}

// updated_at has one-second resolution, so edits that must win need to be at least a second later.
Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 1100));

Future<int> _addTx(AppDatabase db, double amount, {String? note}) {
  return db.into(db.transactions).insert(TransactionsCompanion.insert(
        amount: amount,
        type: TransactionType.expense,
        categoryId: 1, // seeded first category
        paymentMethodType: PaymentMethodType.cash,
        date: DateTime(2026, 10, 8),
        note: Value(note),
      ));
}

void main() {
  setUpAll(() async {
    _server = await Process.start(
      'node',
      ['--import', 'tsx', 'src/server.ts'],
      workingDirectory: 'server',
      runInShell: true,
      environment: {
        'PORT': '$_port',
        'DATABASE_URL': 'postgres://masarefy@127.0.0.1:5433/masarefy_test',
        'DB_SCHEMA': 'dart_e2e_${DateTime.now().millisecondsSinceEpoch}',
        'JWT_ACCESS_SECRET': 'dart-e2e-secret-dart-e2e-secret-1234',
        'REGISTRATION': 'open',
        'ENV_FILE': 'none',
      },
    );
    _server.stdout.transform(utf8.decoder).listen((_) {});
    _server.stderr.transform(utf8.decoder).listen((d) => stderr.write(d));
    for (var i = 0; i < 60; i++) {
      try {
        final r = await HttpClient().getUrl(Uri.parse('$_url/api/health')).then((q) => q.close());
        if (r.statusCode == 200) return;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    fail('server did not start');
  });

  tearDownAll(() async {
    await Process.run('taskkill', ['/F', '/T', '/PID', '${_server.pid}']);
  });

  test('triggers track local edits and deletes', () async {
    final db = await _device();
    final id = await _addTx(db, 10);
    var t = await (db.select(db.transactions)..where((x) => x.id.equals(id))).getSingle();
    expect(t.syncId, isNotNull);
    expect(t.dirty, isTrue);
    expect(t.updatedAt, greaterThan(0));

    await db.customStatement('UPDATE transactions SET dirty = 0');
    await (db.update(db.transactions)..where((x) => x.id.equals(id)))
        .write(const TransactionsCompanion(note: Value('hi')));
    t = await (db.select(db.transactions)..where((x) => x.id.equals(id))).getSingle();
    expect(t.dirty, isTrue, reason: 'editing a data column marks the row dirty');

    await (db.delete(db.transactions)..where((x) => x.id.equals(id))).go();
    expect(await db.select(db.syncTombstones).get(), hasLength(1));
    await db.close();
  });

  test('two devices converge: create, edit, delete, last writer wins', () async {
    final email = 'e2e_${DateTime.now().millisecondsSinceEpoch}@example.com';
    final a = await _device();
    final b = await _device();

    // A: a custom category + a transaction in it, plus one in a seeded category.
    final catId = await a.into(a.categories).insert(CategoriesCompanion.insert(
        name: 'Gym', icon: 'G', color: '#112233', type: CategoryType.expense));
    final t1 = await a.into(a.transactions).insert(TransactionsCompanion.insert(
        amount: 99.5,
        type: TransactionType.expense,
        categoryId: catId,
        paymentMethodType: PaymentMethodType.cash,
        date: DateTime(2026, 10, 1),
        beneficiaryName: const Value('Coach')));
    await _addTx(a, 5);
    final svcA = await _login(a, email, register: true);
    final r1 = await svcA.run();
    expect(r1.skipped, 0);
    expect((await a.select(a.transactions).get()).every((t) => !t.dirty), isTrue,
        reason: 'pushed rows become clean');

    // B (fresh device with its own seeded defaults) pulls everything.
    final svcB = await _login(b, email);
    final r2 = await svcB.run();
    expect(r2.skipped, 0);
    final bTx = await b.select(b.transactions).get();
    expect(bTx, hasLength(2));
    final gym = await (b.select(b.categories)..where((c) => c.name.equals('Gym'))).getSingle();
    final moved = bTx.firstWhere((t) => t.amount == 99.5);
    expect(moved.categoryId, gym.id, reason: 'foreign keys are remapped to the local ids');
    expect(moved.beneficiaryName, 'Coach');
    expect(moved.date, DateTime(2026, 10, 1));
    expect(await b.select(b.banks).get(), hasLength(12), reason: 'seeded defaults are not duplicated');
    expect((await b.select(b.categories).get()).where((c) => c.isDefault), hasLength(12));
    expect((await b.select(b.transactions).get()).every((t) => !t.dirty), isTrue,
        reason: 'applied rows are not mistaken for local edits');

    // B edits, A syncs and sees it.
    await _tick();
    await (b.update(b.transactions)..where((t) => t.id.equals(moved.id)))
        .write(const TransactionsCompanion(amount: Value(120)));
    await svcB.run();
    await svcA.run();
    expect((await (a.select(a.transactions)..where((t) => t.id.equals(t1))).getSingle()).amount, 120);

    // A edits later than B: A wins everywhere.
    await _tick();
    await (a.update(a.transactions)..where((t) => t.id.equals(t1)))
        .write(const TransactionsCompanion(amount: Value(130)));
    await svcA.run();
    await svcB.run();
    expect((await (b.select(b.transactions)..where((t) => t.id.equals(moved.id))).getSingle()).amount, 130);

    // Delete on A reaches B.
    await _tick();
    await (a.delete(a.transactions)..where((t) => t.id.equals(t1))).go();
    await svcA.run();
    expect(await a.select(a.syncTombstones).get(), isEmpty, reason: 'sent tombstones are cleared');
    await svcB.run();
    expect(await b.select(b.transactions).get(), hasLength(1));

    // Nothing left to do.
    final idle = await svcB.run();
    expect(idle.pushed, 0);
    expect(idle.pulled, 0);

    await a.close();
    await b.close();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
