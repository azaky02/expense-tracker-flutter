import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/db/seed.dart';
import '../../../core/db/tables.dart';

/// One row of a plan's schedule.
class InstallmentDue {
  const InstallmentDue({required this.number, required this.dueDate, this.payment});
  final int number;
  final DateTime dueDate;
  final InstallmentPayment? payment;
  bool get isPaid => payment != null;
}

class InstallmentWithSchedule {
  const InstallmentWithSchedule(this.plan, this.schedule);
  final Installment plan;
  final List<InstallmentDue> schedule;

  int get paidCount => schedule.where((d) => d.isPaid).length;
  double get paidAmount => schedule.fold(0, (s, d) => s + (d.payment?.amount ?? 0));
  double get remainingAmount => (plan.totalAmount - paidAmount).clamp(0, double.infinity).toDouble();
  bool get isFinished => paidCount >= plan.months;
  InstallmentDue? get nextDue {
    for (final d in schedule) {
      if (!d.isPaid) return d;
    }
    return null;
  }
}

/// Due date of installment [number] (1-based): the plan's due day in month start+number-1,
/// clamped to that month's last day.
DateTime installmentDueDate(Installment plan, int number) => dueDateFor(plan.startMonth, plan.dueDay, number);

DateTime dueDateFor(DateTime startMonth, int dueDay, int number) {
  final month = DateTime(startMonth.year, startMonth.month + number - 1);
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  return DateTime(month.year, month.month, dueDay.clamp(1, lastDay));
}

class InstallmentRepository {
  InstallmentRepository(this._db);
  final AppDatabase _db;

  List<InstallmentDue> _schedule(Installment plan, List<InstallmentPayment> payments) {
    final byNumber = {for (final p in payments) p.number: p};
    return [
      for (var n = 1; n <= plan.months; n++) InstallmentDue(number: n, dueDate: installmentDueDate(plan, n), payment: byNumber[n]),
    ];
  }

  /// Re-emits whenever a plan or a payment changes.
  Stream<List<InstallmentWithSchedule>> watchAllWithPayments() {
    return _db
        .customSelect('SELECT 1', readsFrom: {_db.installments, _db.installmentPayments})
        .watch()
        .asyncMap((_) => loadAll());
  }

  Future<List<InstallmentWithSchedule>> loadAll() async {
    final plans = await (_db.select(_db.installments)..orderBy([(i) => OrderingTerm.desc(i.createdAt)])).get();
    final payments = await _db.select(_db.installmentPayments).get();
    return [
      for (final p in plans) InstallmentWithSchedule(p, _schedule(p, payments.where((x) => x.installmentId == p.id).toList())),
    ];
  }

  Stream<InstallmentWithSchedule?> watchOne(int id) =>
      watchAllWithPayments().map((all) => all.where((x) => x.plan.id == id).firstOrNull);

  Future<int> create(InstallmentsCompanion data) => _db.into(_db.installments).insert(data);

  Future<void> update(int id, InstallmentsCompanion data) =>
      (_db.update(_db.installments)..where((i) => i.id.equals(id))).write(data);

  Future<void> delete(int id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.installmentPayments)..where((p) => p.installmentId.equals(id))).go();
      await (_db.delete(_db.installments)..where((i) => i.id.equals(id))).go();
    });
  }

  /// Marks installment [number] paid. With [accountId] it is also recorded as an expense under
  /// "أقساط" from that account.
  Future<void> markPaid(Installment plan, int number, {required double amount, DateTime? paidAt, int? accountId}) async {
    final when = paidAt ?? DateTime.now();
    await _db.transaction(() async {
      int? txId;
      if (accountId != null) {
        final account = await (_db.select(_db.accounts)..where((a) => a.id.equals(accountId))).getSingleOrNull();
        final categoryId = await seededCategoryId(_db, 'seed-cat-installments');
        if (account != null && categoryId != null) {
          txId = await _db.into(_db.transactions).insert(TransactionsCompanion.insert(
                amount: amount,
                type: TransactionType.expense,
                categoryId: categoryId,
                paymentMethodType: account.cardId != null ? PaymentMethodType.card : PaymentMethodType.cash,
                cardId: Value(account.cardId),
                date: DateTime(when.year, when.month, when.day),
                note: Value('${plan.title} – $number/${plan.months}'),
                beneficiaryName: Value(plan.provider),
                accountId: Value(accountId),
              ));
        }
      }
      await _db.into(_db.installmentPayments).insert(
            InstallmentPaymentsCompanion.insert(
                installmentId: plan.id, number: number, amount: amount, paidAt: when, transactionId: Value(txId)),
            mode: InsertMode.insertOrReplace,
          );
    });
  }

  /// Undoes a payment (and the expense it created).
  Future<void> unmarkPaid(InstallmentPayment payment) async {
    await _db.transaction(() async {
      if (payment.transactionId != null) {
        await (_db.delete(_db.transactions)..where((t) => t.id.equals(payment.transactionId!))).go();
      }
      await (_db.delete(_db.installmentPayments)..where((p) => p.id.equals(payment.id))).go();
    });
  }
}

final installmentRepositoryProvider = Provider<InstallmentRepository>((ref) => InstallmentRepository(ref.watch(databaseProvider)));

final installmentsProvider = StreamProvider<List<InstallmentWithSchedule>>(
  (ref) => ref.watch(installmentRepositoryProvider).watchAllWithPayments(),
);

final installmentProvider = StreamProvider.family<InstallmentWithSchedule?, int>(
  (ref, id) => ref.watch(installmentRepositoryProvider).watchOne(id),
);
