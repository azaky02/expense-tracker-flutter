import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/core/db/seed.dart';
import 'package:expense_tracker_flutter/features/accounts/data/account_repository.dart';
import 'package:expense_tracker_flutter/features/installments/data/installment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('FIN-01: duplicate payment cannot create a second expense', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedIfNeeded(db);
    await ensureTrustCategory(db);
    await migrateToAccounts(db);

    final accounts = AccountRepository(db);
    final cash = (await accounts.watchAccounts().first).first.account.id;
    await accounts.update(cash, name: 'Cash', openingBalance: 10000);
    final repo = InstallmentRepository(db);
    final planId = await repo.create(InstallmentsCompanion.insert(
      title: 'Fridge',
      provider: 'Bank',
      totalAmount: 3000,
      installmentAmount: 1000,
      months: 3,
      dueDay: 10,
      startMonth: DateTime(2026, 11),
    ));
    final plan = (await repo.loadAll()).single.plan;
    expect(plan.id, planId);

    await repo.markPaid(plan, 1, amount: 1000, accountId: cash);
    final originalPayment = (await repo.loadAll()).single.schedule.first.payment!;
    final originalTxId = originalPayment.transactionId;
    expect(originalTxId, isNotNull);
    expect((await accounts.watchAccount(cash).first)!.balance, 9000);

    await expectLater(
      repo.markPaid(plan, 1, amount: 1000, accountId: cash),
      throwsA(isA<StateError>()),
    );
    expect(await db.select(db.installmentPayments).get(), hasLength(1));
    final expenses = await db.select(db.transactions).get();
    expect(expenses, hasLength(1));
    expect(expenses.single.id, originalTxId);
    expect((await accounts.watchAccount(cash).first)!.balance, 9000);

    await repo.unmarkPaid(originalPayment);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.select(db.installmentPayments).get(), isEmpty);
    expect((await accounts.watchAccount(cash).first)!.balance, 10000);

    await repo.markPaid(plan, 1, amount: 1000, accountId: cash);
    expect(await db.select(db.transactions).get(), hasLength(1));
    expect((await accounts.watchAccount(cash).first)!.balance, 9000);
  });

  test('FIN-01: duplicate payment without an account is also rejected', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedIfNeeded(db);
    final repo = InstallmentRepository(db);
    await repo.create(InstallmentsCompanion.insert(
      title: 'Phone',
      provider: 'Bank',
      totalAmount: 2000,
      installmentAmount: 1000,
      months: 2,
      dueDay: 10,
      startMonth: DateTime(2026, 11),
    ));
    final plan = (await repo.loadAll()).single.plan;
    await repo.markPaid(plan, 1, amount: 1000);
    await expectLater(
      repo.markPaid(plan, 1, amount: 1000),
      throwsA(isA<StateError>()),
    );
    expect(await db.select(db.installmentPayments).get(), hasLength(1));
    expect(await db.select(db.transactions).get(), isEmpty);
  });
  test('FIN-01: invalid payment inputs never create records', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedIfNeeded(db);
    final repo = InstallmentRepository(db);
    await repo.create(InstallmentsCompanion.insert(
      title: 'Laptop',
      provider: 'Bank',
      totalAmount: 2000,
      installmentAmount: 1000,
      months: 2,
      dueDay: 10,
      startMonth: DateTime(2026, 11),
    ));
    final plan = (await repo.loadAll()).single.plan;
    for (final number in [0, -1, 3]) {
      await expectLater(repo.markPaid(plan, number, amount: 1000), throwsArgumentError);
    }
    for (final amount in [0.0, -1.0, double.nan, double.infinity, double.negativeInfinity]) {
      await expectLater(repo.markPaid(plan, 1, amount: amount), throwsArgumentError);
    }
    expect(await db.select(db.installmentPayments).get(), isEmpty);
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  test('FIN-01: concurrent submissions yield exactly one payment and expense', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedIfNeeded(db);
    await ensureTrustCategory(db);
    await migrateToAccounts(db);
    final accounts = AccountRepository(db);
    final cash = (await accounts.watchAccounts().first).first.account.id;
    await accounts.update(cash, name: 'Cash', openingBalance: 10000);
    final repo = InstallmentRepository(db);
    await repo.create(InstallmentsCompanion.insert(
      title: 'TV',
      provider: 'Bank',
      totalAmount: 3000,
      installmentAmount: 1000,
      months: 3,
      dueDay: 10,
      startMonth: DateTime(2026, 11),
    ));
    final plan = (await repo.loadAll()).single.plan;
    final outcomes = await Future.wait([
      repo.markPaid(plan, 1, amount: 1000, accountId: cash)
          .then((_) => true, onError: (Object _) => false),
      repo.markPaid(plan, 1, amount: 1000, accountId: cash)
          .then((_) => true, onError: (Object _) => false),
    ]);
    expect(outcomes.where((success) => success).length, 1);
    expect(await db.select(db.installmentPayments).get(), hasLength(1));
    expect(await db.select(db.transactions).get(), hasLength(1));
    expect((await accounts.watchAccount(cash).first)!.balance, 9000);
  });

}
