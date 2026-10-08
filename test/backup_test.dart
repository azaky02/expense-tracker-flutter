import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/core/db/seed.dart';
import 'package:expense_tracker_flutter/core/db/tables.dart';
import 'package:expense_tracker_flutter/features/accounts/data/account_repository.dart';
import 'package:expense_tracker_flutter/features/backup/data/backup_service.dart';
import 'package:expense_tracker_flutter/features/people/data/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppDatabase> _db() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await seedIfNeeded(db);
  await ensureTrustCategory(db);
  await migrateToAccounts(db);
  return db;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('backup is encrypted and restores everything onto another device', () async {
    final a = await _db();
    final bank = await AccountRepository(a).create(name: 'CIB', type: AccountType.bank, openingBalance: 1000);
    await a.into(a.transactions).insert(TransactionsCompanion.insert(
        amount: 250, type: TransactionType.expense, categoryId: 1, paymentMethodType: PaymentMethodType.cash,
        date: DateTime(2026, 10, 9), note: const Value('سوبر ماركت'), accountId: Value(bank)));
    final ledger = LedgerRepository(a);
    final ahmed = await ledger.createPerson(name: 'أحمد', phone: '01001234567');
    await ledger.createEntry(personId: ahmed, kind: LedgerKind.loan, direction: LedgerDirection.received, amount: 5000, date: DateTime(2026, 10, 1), signedIn: false);

    final file = await BackupService(a).export('secret-pass');
    expect(file.contains('سوبر'), isFalse, reason: 'content is encrypted');
    await expectLater(BackupService(a).open(file, 'wrong-pass'), throwsA(isA<BackupException>().having((e) => e.code, 'code', 'wrong_password')));
    await expectLater(BackupService(a).open('{"hello":1}', 'x'), throwsA(isA<BackupException>()));

    // A different device with its own (different) data.
    final b = await _db();
    await b.into(b.transactions).insert(TransactionsCompanion.insert(
        amount: 9, type: TransactionType.expense, categoryId: 1, paymentMethodType: PaymentMethodType.cash, date: DateTime(2026, 1, 1)));
    final contents = await BackupService(b).open(file, 'secret-pass');
    expect(contents.count('transactions'), 1);
    await BackupService(b).restore(contents);

    final tx = await b.select(b.transactions).get();
    expect(tx, hasLength(1));
    expect(tx.single.note, 'سوبر ماركت');
    expect(tx.single.dirty, isTrue, reason: 'restored rows sync up on the next sync');
    final balances = {for (final x in await AccountRepository(b).watchAccounts().first) x.account.name: x.balance};
    expect(balances['CIB'], 750);
    final people = await LedgerRepository(b).watchPeopleWithBalances().first;
    expect(people.single.person.phone, '01001234567');
    expect(people.single.balance.iOweHim, 5000);
    expect(await b.select(b.syncTombstones).get(), isEmpty, reason: 'restore does not create deletes');

    await a.close();
    await b.close();
  });
}
