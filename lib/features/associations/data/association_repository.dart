import 'package:drift/drift.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/db/seed.dart';
import '../../../core/db/tables.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../core/settings/settings_state.dart';
import '../../../core/utils/currency.dart';
import '../../installments/data/installment_reminders.dart';
import '../../installments/data/installment_repository.dart' show dueDateFor;

/// One month of an association.
class AssociationMonth {
  const AssociationMonth({required this.number, required this.date, this.paid, this.received});
  final int number;

  /// Payment day of that month (the pot is received on the same day).
  final DateTime date;
  final AssociationPayment? paid;
  final AssociationPayment? received;
  bool get isPaid => paid != null;
}

class AssociationWithSchedule {
  const AssociationWithSchedule(this.a, this.months);
  final Association a;
  final List<AssociationMonth> months;

  AssociationMonth get myMonth => months[(a.myTurn - 1).clamp(0, months.length - 1)];
  DateTime get receiveDate => myMonth.date;
  bool get received => myMonth.received != null;
  int get paidCount => months.where((m) => m.isPaid).length;
  double get paidTotal => months.fold(0, (s, m) => s + (m.paid?.amount ?? 0));
  bool get finished => paidCount >= a.months && received;
  AssociationMonth? get nextPayment => months.where((m) => !m.isPaid).firstOrNull;
}

class AssociationRepository {
  AssociationRepository(this._db);
  final AppDatabase _db;

  Future<List<AssociationWithSchedule>> loadAll() async {
    final list = await (_db.select(_db.associations)..orderBy([(a) => OrderingTerm.desc(a.createdAt)])).get();
    final payments = await _db.select(_db.associationPayments).get();
    return [
      for (final a in list)
        AssociationWithSchedule(a, [
          for (var n = 1; n <= a.months; n++)
            AssociationMonth(
              number: n,
              date: dueDateFor(a.startMonth, a.payDay, n),
              paid: payments.where((p) => p.associationId == a.id && p.number == n && p.type == 'pay').firstOrNull,
              received: payments.where((p) => p.associationId == a.id && p.number == n && p.type == 'receive').firstOrNull,
            ),
        ]),
    ];
  }

  Stream<List<AssociationWithSchedule>> watchAll() =>
      _db.customSelect('SELECT 1', readsFrom: {_db.associations, _db.associationPayments}).watch().asyncMap((_) => loadAll());

  Future<int> create(AssociationsCompanion data) => _db.into(_db.associations).insert(data);

  Future<void> update(int id, AssociationsCompanion data) => (_db.update(_db.associations)..where((a) => a.id.equals(id))).write(data);

  Future<void> delete(int id) => _db.transaction(() async {
    await (_db.delete(_db.associationPayments)..where((p) => p.associationId.equals(id))).go();
    await (_db.delete(_db.associations)..where((a) => a.id.equals(id))).go();
  });

  Future<int?> _transaction(
    Association a,
    int accountId,
    double amount,
    DateTime date, {
    required bool income,
    required String note,
  }) async {
    final account = await (_db.select(_db.accounts)..where((x) => x.id.equals(accountId))).getSingleOrNull();
    final category = await seededCategoryId(_db, income ? 'seed-cat-association-in' : 'seed-cat-association');
    if (account == null || category == null) return null;
    return _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amount: amount,
            type: income ? TransactionType.income : TransactionType.expense,
            categoryId: category,
            paymentMethodType: account.cardId != null ? PaymentMethodType.card : PaymentMethodType.cash,
            cardId: Value(account.cardId),
            date: DateTime(date.year, date.month, date.day),
            note: Value(note),
            beneficiaryName: Value(a.owner),
            accountId: Value(accountId),
          ),
        );
  }

  /// Records month [number]: the share paid ([receive] false) or the pot received ([receive] true).
  /// With [accountId] it is also recorded as an expense / income.
  Future<void> record(Association a, int number, {required bool receive, required double amount, int? accountId, DateTime? date}) async {
    final when = date ?? DateTime.now();
    await _db.transaction(() async {
      final label = a.name.isEmpty ? a.owner : a.name;
      final txId = accountId == null
          ? null
          : await _transaction(a, accountId, amount, when, income: receive, note: '$label – $number/${a.months}');
      await _db
          .into(_db.associationPayments)
          .insert(
            AssociationPaymentsCompanion.insert(
              associationId: a.id,
              number: number,
              type: receive ? 'receive' : 'pay',
              amount: amount,
              date: when,
              transactionId: Value(txId),
            ),
            mode: InsertMode.insertOrReplace,
          );
    });
  }

  Future<void> undo(AssociationPayment p) => _db.transaction(() async {
    if (p.transactionId != null) await (_db.delete(_db.transactions)..where((t) => t.id.equals(p.transactionId!))).go();
    await (_db.delete(_db.associationPayments)..where((x) => x.id.equals(p.id))).go();
  });
}

final associationRepositoryProvider = Provider<AssociationRepository>((ref) => AssociationRepository(ref.watch(databaseProvider)));
final associationsProvider = StreamProvider<List<AssociationWithSchedule>>((ref) => ref.watch(associationRepositoryProvider).watchAll());

const _idBase = 7800;
const _max = 20;

/// Reminder at the start of the month in which the user receives the pot (1st, 10:00), plus one on
/// the receive day itself.
Future<void> rescheduleAssociationReminders(List<AssociationWithSchedule> list) async {
  final n = InstallmentReminders.instance;
  await n.cancelIds([for (var i = 0; i < _max * 2; i++) _idBase + i]);
  var i = 0;
  for (final s in list) {
    if (s.received || i >= _max) continue;
    final d = s.receiveDate;
    final args = {
      'amount': formatAmount(s.a.totalAmount),
      'name': s.a.name.isEmpty ? s.a.owner : s.a.name,
      'date': DateFormat.MMMd('ar').format(d),
    };
    await n.scheduleAt(
      id: _idBase + i * 2,
      when: DateTime(d.year, d.month, 1, 10),
      title: 'associations.reminderTitle'.tr(),
      body: 'associations.reminderMonth'.tr(namedArgs: args),
    );
    await n.scheduleAt(
      id: _idBase + i * 2 + 1,
      when: DateTime(d.year, d.month, d.day, 10),
      title: 'associations.reminderTitle'.tr(),
      body: 'associations.reminderDay'.tr(namedArgs: args),
    );
    i++;
  }
}

final associationRemindersProvider = Provider<void>((ref) {
  void run() {
    final list = ref.read(associationsProvider).value;
    if (list == null) return;
    rescheduleAssociationReminders(ref.read(settingsProvider).moduleEnabled(AppModule.associations.key) ? list : const []);
  }

  ref.listen(associationsProvider, (_, _) => run(), fireImmediately: true);
  ref.listen(settingsProvider.select((s) => s.moduleEnabled(AppModule.associations.key)), (_, _) => run());
});
