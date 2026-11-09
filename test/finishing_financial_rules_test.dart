import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_flutter/features/finishing/domain/finishing_financial_rules.dart';

void main() {
  const initial = FinishingFinancialState();
  FinishingFinancialState apply(FinishingFinancialState s, FinishingEventKind kind, int amount,
      {int custody = 0, int personal = 0}) =>
      FinishingFinancialRules.apply(s, FinishingFinancialCommand(
        kind: kind, amountPiasters: amount,
        custodySharePiasters: custody, personalSharePiasters: personal));

  test('mixed expense counts cost once and separates custody and receivable', () {
    final funded = apply(initial, FinishingEventKind.clientAdvance, 5000000);
    final spent = apply(funded, FinishingEventKind.cost, 1000000,
        custody: 700000, personal: 300000);
    expect(spent.custodyPiasters, 4300000);
    expect(spent.receivablePiasters, 300000);
    expect(spent.costPiasters, 1000000);
  });

  test('custody reimbursement settles both balances without new cost', () {
    final funded = apply(initial, FinishingEventKind.clientAdvance, 500000);
    final spent = apply(funded, FinishingEventKind.cost, 300000, personal: 300000);
    final settled = apply(spent, FinishingEventKind.reimburseFromCustody, 200000);
    expect(settled.custodyPiasters, 300000);
    expect(settled.receivablePiasters, 100000);
    expect(settled.costPiasters, 300000);
  });

  test('direct client repayment does not increase custody', () {
    final spent = apply(initial, FinishingEventKind.cost, 400000, personal: 400000);
    final repaid = apply(spent, FinishingEventKind.clientRepayPersonal, 400000);
    expect(repaid.custodyPiasters, 0);
    expect(repaid.receivablePiasters, 0);
    expect(repaid.costPiasters, 400000);
  });

  test('personal allocation is not custody, receivable or project cost', () {
    final s = apply(initial, FinishingEventKind.personalAllocation, 100000);
    expect(s.personalLiquidityPiasters, 100000);
    expect(s.custodyPiasters, 0);
    expect(s.receivablePiasters, 0);
    expect(s.costPiasters, 0);
  });

  test('reject custody overdraft and allocation mismatch', () {
    expect(() => apply(initial, FinishingEventKind.cost, 10000, custody: 10000), throwsStateError);
    expect(() => apply(initial, FinishingEventKind.cost, 10000, personal: 9000), throwsArgumentError);
  });

  test('reject excess reimbursement and excess direct repayment', () {
    final s = apply(initial, FinishingEventKind.clientAdvance, 50000);
    expect(() => apply(s, FinishingEventKind.reimburseFromCustody, 10000), throwsStateError);
    expect(() => apply(s, FinishingEventKind.clientRepayPersonal, 10000), throwsStateError);
  });

  test('return custody never changes costs or receivables', () {
    final s = apply(initial, FinishingEventKind.clientAdvance, 50000);
    final returned = apply(s, FinishingEventKind.returnCustody, 20000);
    expect(returned.custodyPiasters, 30000);
    expect(returned.costPiasters, 0);
    expect(returned.receivablePiasters, 0);
  });

  test('negative and zero operations are rejected', () {
    expect(() => apply(initial, FinishingEventKind.clientAdvance, 0), throwsArgumentError);
    expect(() => apply(initial, FinishingEventKind.clientAdvance, -100), throwsArgumentError);
  });
}
