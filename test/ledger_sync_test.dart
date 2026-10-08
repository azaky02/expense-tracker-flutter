// Shared Ledger end-to-end: two users on two in-memory devices against the real Node server.
// Needs Node, the local Postgres on :5433 and `npm install` in server/.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/core/db/seed.dart';
import 'package:expense_tracker_flutter/core/db/tables.dart';
import 'package:expense_tracker_flutter/core/sync/sync_api.dart';
import 'package:expense_tracker_flutter/core/sync/sync_service.dart';
import 'package:expense_tracker_flutter/features/people/data/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _port = 4378;
final _url = 'http://127.0.0.1:$_port';
late Process _server;

class _Device {
  _Device(this.db, this.sync, this.repo);
  final AppDatabase db;
  final SyncService sync;
  final LedgerRepository repo;
}

Future<_Device> _signedUpDevice(String name, String email) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await seedIfNeeded(db);
  final session = await SyncApi(_url).register(email, 'password123', name, null);
  final svc = SyncService(db, SyncApi(_url, session: session));
  await svc.prepareForAccount(session.userId);
  return _Device(db, svc, LedgerRepository(db));
}

Future<PersonWithBalance> _only(LedgerRepository repo) async => (await repo.watchPeopleWithBalances().first).single;

void main() {
  setUpAll(() async {
    _server = await Process.start('node', ['--import', 'tsx', 'src/server.ts'],
        workingDirectory: 'server',
        runInShell: true,
        environment: {
          'PORT': '$_port',
          'DATABASE_URL': 'postgres://masarefy@127.0.0.1:5433/masarefy_test',
          'DB_SCHEMA': 'dart_ledger_${DateTime.now().millisecondsSinceEpoch}',
          'JWT_ACCESS_SECRET': 'dart-e2e-secret-dart-e2e-secret-1234',
          'REGISTRATION': 'open',
          'ENV_FILE': 'none',
        });
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

  tearDownAll(() => Process.run('taskkill', ['/F', '/T', '/PID', '${_server.pid}']));

  test('balance math follows the design document scenario', () {
    LedgerEntry e(LedgerKind k, LedgerDirection d, double a) => LedgerEntry(
        id: 0, entryId: 'x', kind: k, direction: d, amount: a, currency: 'EGP', date: DateTime(2026, 10, 1),
        status: LedgerStatus.confirmed, createdByMe: true, queued: false, createdAt: DateTime(2026));
    final loan = e(LedgerKind.loan, LedgerDirection.received, 100000);
    final b1 = PersonBalance.of([loan, e(LedgerKind.settlement, LedgerDirection.gave, 20000)]);
    expect(b1.iOweHim, 80000);
    expect(b1.net, -80000);
    final b2 = PersonBalance.of([loan, e(LedgerKind.loan, LedgerDirection.gave, 25000), e(LedgerKind.settlement, LedgerDirection.gave, 35000)]);
    expect(b2.heOwesMe, 25000);
    expect(b2.iOweHim, 65000);
    expect(b2.net, -40000);
  });

  test('loan from Ahmed, confirmed by Ahmed, repaid in full', () async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final me = await _signedUpDevice('Me', 'me_$stamp@example.com');
    final ahmed = await _signedUpDevice('Ahmed', 'ahmed_$stamp@example.com');

    final pid = await me.repo.createPerson(name: 'أحمد', email: 'ahmed_$stamp@example.com');
    final loanId = await me.repo.createEntry(
        personId: pid, kind: LedgerKind.loan, direction: LedgerDirection.received, amount: 100000, date: DateTime(2026, 10, 1));
    var mine = await _only(me.repo);
    expect(mine.balance.pendingCount, 1);
    expect(mine.balance.net, 0, reason: 'pending entries do not count');

    await me.sync.run();
    expect(await me.db.select(me.db.ledgerOutbox).get(), isEmpty);
    final local = await (me.db.select(me.db.ledgerEntries)..where((e) => e.entryId.equals(loanId))).getSingle();
    expect(local.status, LedgerStatus.pending);
    expect(local.queued, isFalse);
    expect((await me.db.select(me.db.people).get()).single.linkedUserId, isNotNull, reason: 'person linked to the account');

    // Ahmed's device: the entry arrives with a notification and a person for "Me" is created.
    await ahmed.sync.run();
    final theirs = await (ahmed.db.select(ahmed.db.ledgerEntries)..where((e) => e.entryId.equals(loanId))).getSingle();
    expect(theirs.direction, LedgerDirection.gave);
    expect(theirs.createdByMe, isFalse);
    expect((await ahmed.db.select(ahmed.db.people).get()).single.name, 'Me');
    expect((await ahmed.db.select(ahmed.db.appNotifications).get()).single.type, 'NEW_ENTRY');

    await ahmed.repo.confirm(loanId);
    await ahmed.sync.run();
    await me.sync.run();
    mine = await _only(me.repo);
    expect(mine.balance.iOweHim, 100000);
    expect(mine.balance.net, -100000);

    for (final amount in [20000.0, 15000.0, 65000.0]) {
      await me.repo.createEntry(
          personId: pid, kind: LedgerKind.settlement, direction: LedgerDirection.gave, amount: amount,
          date: DateTime(2026, 10, 8), settlesEntryId: loanId);
    }
    await me.sync.run();
    await ahmed.sync.run();
    final pendingForAhmed = await (ahmed.db.select(ahmed.db.ledgerEntries)
          ..where((e) => e.status.equalsValue(LedgerStatus.pending)))
        .get();
    expect(pendingForAhmed, hasLength(3));
    for (final p in pendingForAhmed) {
      await ahmed.repo.confirm(p.entryId);
    }
    await ahmed.sync.run();
    await me.sync.run();

    mine = await _only(me.repo);
    expect(mine.balance.net, 0);
    expect(mine.balance.pendingCount, 0);
    final statement = await me.repo.watchStatement(pid).first;
    expect(statement.map((l) => l.runningBalance), [-100000, -80000, -65000, 0]);
    final theirsBalance = await _only(ahmed.repo);
    expect(theirsBalance.balance.net, 0);
    expect((await ahmed.db.select(ahmed.db.appNotifications).get()).where((n) => n.type == 'SETTLEMENT_RECEIVED'), hasLength(3));

    await me.db.close();
    await ahmed.db.close();
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a person without an account: final at once; a rejected entry never counts', () async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final me = await _signedUpDevice('Me', 'me2_$stamp@example.com');
    final b = await _signedUpDevice('B', 'b2_$stamp@example.com');

    final khaled = await me.repo.createPerson(name: 'خالد');
    await me.repo.createEntry(personId: khaled, kind: LedgerKind.loan, direction: LedgerDirection.gave, amount: 300, date: DateTime(2026, 10, 2));
    final bp = await me.repo.createPerson(name: 'B', email: 'b2_$stamp@example.com');
    final bad = await me.repo.createEntry(personId: bp, kind: LedgerKind.loan, direction: LedgerDirection.gave, amount: 999, date: DateTime(2026, 10, 2));
    await me.sync.run();

    await b.sync.run();
    await b.repo.reject(bad, 'not me');
    await b.sync.run();
    await me.sync.run();

    final all = await me.repo.watchPeopleWithBalances().first;
    final k = all.firstWhere((p) => p.person.name == 'خالد');
    final bb = all.firstWhere((p) => p.person.name == 'B');
    expect(k.balance.heOwesMe, 300);
    expect(bb.balance.net, 0);
    final rejected = await (me.db.select(me.db.ledgerEntries)..where((e) => e.entryId.equals(bad))).getSingle();
    expect(rejected.status, LedgerStatus.rejected);
    expect(rejected.rejectReason, 'not me');

    await me.db.close();
    await b.db.close();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
