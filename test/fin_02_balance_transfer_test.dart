import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/core/db/seed.dart';
import 'package:expense_tracker_flutter/core/db/tables.dart';
import 'package:expense_tracker_flutter/features/accounts/data/account_repository.dart';
import 'package:expense_tracker_flutter/features/transactions/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('FIN-02: transfer conserves combined balances and reverses on delete', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedIfNeeded(db);
    await ensureTrustCategory(db);
    final accounts = AccountRepository(db);
    final from = await accounts.create(name: 'Cash', type: AccountType.cash, openingBalance: 10000);
    final to = await accounts.create(name: 'Bank', type: AccountType.cash, openingBalance: 2000);
    final repo = TransactionRepository(db);
    final category = await repo.systemCategoryId(CategoryType.transfer);
    TransactionInput input(double amount, int source, int destination) => TransactionInput(
      amount: amount, type: TransactionType.transfer, categoryId: category,
      paymentMethodType: PaymentMethodType.cash, date: DateTime(2026, 11, 9),
      accountId: source, toAccountId: destination,
    );
    final id = await repo.create(input(1000, from, to));
    expect((await accounts.watchAccount(from).first)!.balance, 9000);
    expect((await accounts.watchAccount(to).first)!.balance, 3000);
    await repo.update(id, input(500, to, from));
    expect((await accounts.watchAccount(from).first)!.balance, 10500);
    expect((await accounts.watchAccount(to).first)!.balance, 1500);
    await repo.delete(id);
    expect((await accounts.watchAccount(from).first)!.balance, 10000);
    expect((await accounts.watchAccount(to).first)!.balance, 2000);
  });

  test('FIN-02: invalid transfers and amounts cannot change balances', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedIfNeeded(db);
    await ensureTrustCategory(db);
    final accounts = AccountRepository(db);
    final from = await accounts.create(name: 'Cash', type: AccountType.cash, openingBalance: 10000);
    final to = await accounts.create(name: 'Bank', type: AccountType.cash, openingBalance: 2000);
    final repo = TransactionRepository(db);
    final category = await repo.systemCategoryId(CategoryType.transfer);
    Future<void> attempt(double amount, int? source, int? destination) async {
      await expectLater(
        repo.create(TransactionInput(
          amount: amount, type: TransactionType.transfer, categoryId: category,
          paymentMethodType: PaymentMethodType.cash, date: DateTime(2026, 11, 9),
          accountId: source, toAccountId: destination,
        )),
        throwsArgumentError,
      );
    }
    await attempt(100, from, from);
    await attempt(100, null, to);
    await attempt(100, from, null);
    await attempt(100, from, 999999);
    await attempt(100, 999999, to);
    for (final amount in [0.0, -1.0, double.nan, double.infinity, double.negativeInfinity]) {
      await attempt(amount, from, to);
    }
    expect(await db.select(db.transactions).get(), isEmpty);
    expect((await accounts.watchAccount(from).first)!.balance, 10000);
    expect((await accounts.watchAccount(to).first)!.balance, 2000);
  });
  test('FIN-02: decimal transfers conserve balances within cent precision', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedIfNeeded(db);
    await ensureTrustCategory(db);
    final accounts = AccountRepository(db);
    final source = await accounts.create(name: 'Source', type: AccountType.cash, openingBalance: 100);
    final destination = await accounts.create(name: 'Destination', type: AccountType.cash, openingBalance: 50);
    final repo = TransactionRepository(db);
    final category = await repo.systemCategoryId(CategoryType.transfer);
    for (final amount in [0.1, 0.2, 0.3, 12.35, 0.01]) {
      await repo.create(TransactionInput(
        amount: amount, type: TransactionType.transfer, categoryId: category,
        paymentMethodType: PaymentMethodType.cash, date: DateTime(2026, 11, 9),
        accountId: source, toAccountId: destination,
      ));
    }
    final fromBalance = (await accounts.watchAccount(source).first)!.balance;
    final toBalance = (await accounts.watchAccount(destination).first)!.balance;
    expect(fromBalance, closeTo(87.04, 0.000001));
    expect(toBalance, closeTo(62.96, 0.000001));
    expect(fromBalance + toBalance, closeTo(150, 0.000001));
  });

  test('FIN-02: beneficiary write failure rolls back transfer insert', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedIfNeeded(db);
    await ensureTrustCategory(db);
    final accounts = AccountRepository(db);
    final source = await accounts.create(name: 'Source', type: AccountType.cash, openingBalance: 100);
    final destination = await accounts.create(name: 'Destination', type: AccountType.cash, openingBalance: 50);
    final repo = TransactionRepository(db);
    final category = await repo.systemCategoryId(CategoryType.transfer);
    await db.customStatement("""
      CREATE TRIGGER fin02_fail_beneficiary BEFORE INSERT ON beneficiaries
      BEGIN SELECT RAISE(ABORT, 'fin02_injected_failure'); END
    """);
    await expectLater(repo.create(TransactionInput(
      amount: 25, type: TransactionType.transfer, categoryId: category,
      paymentMethodType: PaymentMethodType.cash, date: DateTime(2026, 11, 9),
      accountId: source, toAccountId: destination, beneficiaryName: 'Rollback Probe',
    )), throwsA(anything));
    expect(await db.select(db.transactions).get(), isEmpty);
    expect((await accounts.watchAccount(source).first)!.balance, 100);
    expect((await accounts.watchAccount(destination).first)!.balance, 50);
  });

  test('FIN-02: concurrent retries with same key charge exactly once', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedIfNeeded(db);
    await ensureTrustCategory(db);
    final accounts = AccountRepository(db);
    final source = await accounts.create(name: 'Source', type: AccountType.cash, openingBalance: 100);
    final destination = await accounts.create(name: 'Destination', type: AccountType.cash, openingBalance: 50);
    final repo = TransactionRepository(db);
    final category = await repo.systemCategoryId(CategoryType.transfer);
    final input = TransactionInput(
      amount: 25, type: TransactionType.transfer, categoryId: category,
      paymentMethodType: PaymentMethodType.cash, date: DateTime(2026, 11, 9),
      accountId: source, toAccountId: destination, idempotencyKey: 'fin02-retry-001',
    );
    final results = await Future.wait([
      repo.create(input).then((_) => 'created').catchError((Object _) => 'rejected'),
      repo.create(input).then((_) => 'created').catchError((Object _) => 'rejected'),
    ]);
    expect(results.where((result) => result == 'created').length, 1);
    expect(results.where((result) => result == 'rejected').length, 1);
    expect((await db.select(db.transactions).get()).length, 1);
    expect((await accounts.watchAccount(source).first)!.balance, 75);
    expect((await accounts.watchAccount(destination).first)!.balance, 75);
  });

  test('FIN-02: reject amounts smaller than one cent', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedIfNeeded(db);
    await ensureTrustCategory(db);
    final accounts = AccountRepository(db);
    final source = await accounts.create(name: 'Source', type: AccountType.cash, openingBalance: 100);
    final destination = await accounts.create(name: 'Destination', type: AccountType.cash, openingBalance: 50);
    final repo = TransactionRepository(db);
    final category = await repo.systemCategoryId(CategoryType.transfer);
    for (final amount in [0.001, 0.005, 1.234, 10.999]) {
      await expectLater(repo.create(TransactionInput(
        amount: amount, type: TransactionType.transfer, categoryId: category,
        paymentMethodType: PaymentMethodType.cash, date: DateTime(2026, 11, 9),
        accountId: source, toAccountId: destination,
      )), throwsArgumentError);
    }
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  test('FIN-02: retry identity remains the synced transaction identity', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedIfNeeded(db);
    await ensureTrustCategory(db);
    final accounts = AccountRepository(db);
    final source = await accounts.create(name: 'Source', type: AccountType.cash, openingBalance: 100);
    final destination = await accounts.create(name: 'Destination', type: AccountType.cash, openingBalance: 50);
    final repo = TransactionRepository(db);
    final category = await repo.systemCategoryId(CategoryType.transfer);
    final id = await repo.create(TransactionInput(
      amount: 10, type: TransactionType.transfer, categoryId: category,
      paymentMethodType: PaymentMethodType.cash, date: DateTime(2026, 11, 9),
      accountId: source, toAccountId: destination, idempotencyKey: 'fin02-stable-sync-id',
    ));
    final saved = await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();
    expect(saved.syncId, 'fin02-stable-sync-id');
  });

}
