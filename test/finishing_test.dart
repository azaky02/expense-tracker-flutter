import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/core/db/seed.dart';
import 'package:expense_tracker_flutter/features/accounts/data/account_repository.dart';
import 'package:expense_tracker_flutter/features/finishing/data/finishing_repository.dart';
import 'package:expense_tracker_flutter/features/finishing/domain/finishing_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('rules', () {
    const m = FinishingMove.new;
    test('BC-03/04/05: cost from custody, pocket and mixed', () {
      var b = FinishingRules.apply(const FinishingBalance(), const FinishingMove(FinishingKind.clientAdvance, 5000000));
      b = FinishingRules.apply(b, const FinishingMove(FinishingKind.cost, 800000, custodyShare: 800000));
      expect((b.custody, b.receivable, b.cost), (4200000, 0, 800000));
      b = FinishingRules.apply(b, const FinishingMove(FinishingKind.cost, 500000, personalShare: 500000));
      expect((b.custody, b.receivable, b.cost), (4200000, 500000, 1300000));
      b = FinishingRules.apply(b, const FinishingMove(FinishingKind.cost, 1500000, custodyShare: 1000000, personalShare: 500000));
      expect((b.custody, b.receivable, b.cost), (3200000, 1000000, 2800000));
    });

    test('BC-06..09 settlements and allocation', () {
      var b = const FinishingBalance(custody: 2000000, receivable: 700000);
      b = FinishingRules.apply(b, m(FinishingKind.reimburseFromCustody, 700000));
      expect((b.custody, b.receivable), (1300000, 0));
      b = FinishingRules.apply(b, m(FinishingKind.returnCustody, 1300000));
      expect(b.custody, 0);
      b = FinishingRules.apply(b, m(FinishingKind.personalAllocation, 2000000));
      expect((b.allocation, b.cost, b.custody), (2000000, 0, 0));
      expect(b.canClose, isTrue);
    });

    test('limits are refused', () {
      const b = FinishingBalance(custody: 100, receivable: 50);
      expect(() => FinishingRules.apply(b, m(FinishingKind.cost, 200, custodyShare: 200)), throwsA(isA<FinishingRuleError>()));
      expect(() => FinishingRules.apply(b, m(FinishingKind.cost, 200, custodyShare: 100)), throwsA(isA<FinishingRuleError>()));
      expect(() => FinishingRules.apply(b, m(FinishingKind.reimburseFromCustody, 60)), throwsA(isA<FinishingRuleError>()));
      expect(() => FinishingRules.apply(b, m(FinishingKind.clientRepayPersonal, 51)), throwsA(isA<FinishingRuleError>()));
      expect(() => FinishingRules.apply(b, m(FinishingKind.returnCustody, 101)), throwsA(isA<FinishingRuleError>()));
      expect(() => FinishingRules.apply(b, m(FinishingKind.clientAdvance, 0)), throwsA(isA<FinishingRuleError>()));
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
      amount: 1500000,
      custodyShare: 1000000,
      personalShare: 500000,
      tradeId: trade.id,
      costType: CostType.materials,
      description: 'خامات',
      date: DateTime(2026, 11, 3),
      accountId: cash.account.id,
      personalAccountId: cash.account.id,
    );
    var d = (await repo.loadProject(pid))!;
    expect((d.balance.custody, d.balance.receivable, d.balance.cost), (4000000, 500000, 1500000));
    expect(d.byTrade.first.total, 1500000);
    var bal = (await accounts.watchAccounts().first).firstWhere((a) => a.account.id == cash.account.id).balance;
    expect(bal - cash.balance, closeTo(50000 - 15000, 0.001));

    // Over custody: refused with no partial writes.
    final before = (await db.select(db.finishingEvents).get()).length;
    await expectLater(
      repo.record(eventId: 'c2', projectId: pid, kind: FinishingKind.cost, amount: 9000000, custodyShare: 9000000, tradeId: trade.id, description: 'x', date: DateTime(2026, 11, 3), accountId: cash.account.id),
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
