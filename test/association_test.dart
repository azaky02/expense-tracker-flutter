import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/core/db/seed.dart';
import 'package:expense_tracker_flutter/core/db/tables.dart';
import 'package:expense_tracker_flutter/features/accounts/data/account_repository.dart';
import 'package:expense_tracker_flutter/features/associations/data/association_repository.dart';
import 'package:expense_tracker_flutter/features/installments/data/installment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('association schedule, my turn, paying shares and receiving the pot', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedIfNeeded(db);
    await ensureTrustCategory(db);
    await migrateToAccounts(db);
    final cash = (await AccountRepository(db).watchAccounts().first).first.account.id;
    final repo = AssociationRepository(db);
    await repo.create(AssociationsCompanion.insert(
      owner: 'أم أحمد',
      totalAmount: 10000,
      shareAmount: 1000,
      months: 10,
      myTurn: 4,
      startMonth: DateTime(2026, 11),
      payDay: 31,
    ));
    var s = (await repo.loadAll()).single;
    expect(s.months, hasLength(10));
    expect(s.receiveDate, DateTime(2027, 2, 28), reason: 'turn 4 = February, day 31 clamped');
    expect(s.nextPayment!.number, 1);

    await repo.record(s.a, 1, receive: false, amount: 1000, accountId: cash, date: DateTime(2026, 11, 30));
    await repo.record(s.a, 4, receive: true, amount: 10000, accountId: cash, date: DateTime(2027, 2, 28));
    s = (await repo.loadAll()).single;
    expect(s.paidCount, 1);
    expect(s.paidTotal, 1000);
    expect(s.received, isTrue);
    final tx = await db.select(db.transactions).get();
    expect(tx.where((t) => t.type == TransactionType.expense).single.amount, 1000);
    expect(tx.where((t) => t.type == TransactionType.income).single.amount, 10000);

    await repo.undo(s.myMonth.received!);
    expect((await repo.loadAll()).single.received, isFalse);
    expect((await db.select(db.transactions).get()).where((t) => t.type == TransactionType.income), isEmpty);
    await db.close();
  });

  test('installment plans can be loans', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = InstallmentRepository(db);
    await repo.create(InstallmentsCompanion.insert(
      title: 'قرض شخصي',
      provider: 'بنك مصر',
      totalAmount: 60000,
      installmentAmount: 5000,
      months: 12,
      dueDay: 5,
      startMonth: DateTime(2026, 11),
      kind: const Value('loan'),
    ));
    await repo.create(InstallmentsCompanion.insert(
        title: 'تلاجة', provider: 'valU', totalAmount: 12000, installmentAmount: 1000, months: 12, dueDay: 5, startMonth: DateTime(2026, 11)));
    final all = await repo.loadAll();
    expect(all.map((i) => i.plan.kind).toSet(), {'loan', 'installment'});
    await db.close();
  });
}
