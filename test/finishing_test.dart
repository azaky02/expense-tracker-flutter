import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/core/db/seed.dart';
import 'package:expense_tracker_flutter/features/accounts/data/account_repository.dart';
import 'package:expense_tracker_flutter/features/finishing/data/finishing_export.dart';
import 'package:expense_tracker_flutter/features/finishing/data/finishing_repository.dart';
import 'package:expense_tracker_flutter/features/finishing/domain/finishing_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('rules', () {
    const m = FinishingMove.new;
    test('one project account: received − spent = balance', () {
      var b = FinishingRules.apply(const FinishingBalance(), m(FinishingKind.clientAdvance, 5000000));
      b = FinishingRules.apply(b, m(FinishingKind.cost, 800000));
      expect((b.net, b.received, b.cost, b.custody, b.receivable), (4200000, 5000000, 800000, 4200000, 0));
      // Spending beyond what was received is allowed: the client then owes me.
      b = FinishingRules.apply(b, m(FinishingKind.cost, 5000000));
      expect((b.net, b.custody, b.receivable), (-800000, 0, 800000));
      // The client pays it back.
      b = FinishingRules.apply(b, m(FinishingKind.clientAdvance, 800000));
      expect((b.net, b.canClose), (0, true));
    });

    test('limits are refused', () {
      const b = FinishingBalance(net: 100);
      expect(() => FinishingRules.apply(b, m(FinishingKind.returnCustody, 101)), throwsA(isA<FinishingRuleError>()));
      expect(() => FinishingRules.apply(b, m(FinishingKind.clientAdvance, 0)), throwsA(isA<FinishingRuleError>()));
      expect(FinishingRules.apply(b, m(FinishingKind.returnCustody, 100)).net, 0);
    });
  });

  test('repository: accounts move, retries are idempotent, reversal and close', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedIfNeeded(db);
    await migrateToAccounts(db);
    final accounts = AccountRepository(db);
    final cash = (await accounts.watchAccounts().first).first;
    final repo = FinishingRepository(db);
    final pid = await repo.createProject(clientName: 'أحمد', name: 'شقة أحمد', startDate: DateTime(2026, 11), trades: ['كهرباء', 'سباكة']);
    final trade = (await repo.loadProject(pid))!.trades.first;

    await repo.record(eventId: 'a1', projectId: pid, kind: FinishingKind.clientAdvance, amount: 5000000, date: DateTime(2026, 11, 2), accountId: cash.account.id);
    // Same id + same data again: nothing new.
    await repo.record(eventId: 'a1', projectId: pid, kind: FinishingKind.clientAdvance, amount: 5000000, date: DateTime(2026, 11, 2), accountId: cash.account.id);
    // Same id, different data: refused.
    await expectLater(
      repo.record(eventId: 'a1', projectId: pid, kind: FinishingKind.clientAdvance, amount: 1, date: DateTime(2026, 11, 2), accountId: cash.account.id),
      throwsA(isA<FinishingRuleError>()),
    );
    await repo.record(
      eventId: 'c1',
      projectId: pid,
      kind: FinishingKind.cost,
      amount: 5500000,
      tradeId: trade.id,
      costType: CostType.materials,
      description: 'خامات',
      date: DateTime(2026, 11, 3),
      accountId: cash.account.id,
    );
    var d = (await repo.loadProject(pid))!;
    expect((d.balance.net, d.balance.receivable, d.balance.cost), (-500000, 500000, 5500000));
    // Statement with the balance after each movement, and account movements.
    expect(d.statement.map((l) => l.after).toList(), [5000000, -500000]);
    expect((d.accounts.single.moneyIn, d.accounts.single.moneyOut), (5000000, 5500000));
    String tr(String k, {Map<String, String>? args}) => k;
    expect(buildProjectXlsx(d, tr, 'ar').length, greaterThan(1000));
    expect((await buildProjectPdf(d, tr, 'ar')).length, greaterThan(1000));
    // Attachments are listed with the project.
    await repo.addAttachment(projectId: pid, path: '/tmp/x.jpg', name: 'x.jpg', type: 'image');
    expect((await repo.loadProject(pid))!.attachments.length, 1);
    expect(d.byTrade.first.total, 5500000);
    var bal = (await accounts.watchAccounts().first).firstWhere((a) => a.account.id == cash.account.id).balance;
    expect(bal - cash.balance, closeTo(50000 - 55000, 0.001));

    // Returning money I don't hold: refused with no partial writes.
    final before = (await db.select(db.finishingEvents).get()).length;
    await expectLater(
      repo.record(eventId: 'c2', projectId: pid, kind: FinishingKind.returnCustody, amount: 100, date: DateTime(2026, 11, 3), accountId: cash.account.id),
      throwsA(isA<FinishingRuleError>()),
    );
    expect((await db.select(db.finishingEvents).get()).length, before);

    // Closing with balances is refused.
    await expectLater(repo.close(pid), throwsA(isA<FinishingRuleError>()));

    // Reverse the cost: balances and the account go back.
    final costRow = d.events.firstWhere((e) => e.kind == FinishingKind.cost);
    await repo.reverse(costRow.event.id);
    d = (await repo.loadProject(pid))!;
    expect((d.balance.custody, d.balance.receivable, d.balance.cost), (5000000, 0, 0));
    bal = (await accounts.watchAccounts().first).firstWhere((a) => a.account.id == cash.account.id).balance;
    expect(bal - cash.balance, closeTo(50000, 0.001));

    // Return the custody, then close.
    await repo.record(eventId: 'r1', projectId: pid, kind: FinishingKind.returnCustody, amount: 5000000, date: DateTime(2026, 11, 4), accountId: cash.account.id);
    await repo.close(pid);
    await expectLater(
      repo.record(eventId: 'a2', projectId: pid, kind: FinishingKind.clientAdvance, amount: 100, date: DateTime(2026, 11, 5), accountId: cash.account.id),
      throwsA(isA<FinishingRuleError>()),
    );
    await db.close();
  });
}
