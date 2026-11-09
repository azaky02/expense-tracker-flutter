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
}
