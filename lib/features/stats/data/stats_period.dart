import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_provider.dart';
import '../../cars/data/car_repository.dart';
import '../../installments/data/installment_repository.dart';
import '../../transactions/data/transaction_models.dart';

enum StatsPeriodKind { currentMonth, month, year, custom }

/// The period the statistics screen shows. Dates are whole days, both ends included.
class StatsPeriod {
  const StatsPeriod({required this.kind, required this.from, required this.to, this.categoryId});
  final StatsPeriodKind kind;
  final DateTime from;
  final DateTime to;

  /// Custom period only: limit expenses to this main category (and its sub-categories).
  final int? categoryId;

  int get days => to.difference(from).inDays + 1;
  bool contains(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(from) && !day.isAfter(to);
  }

  static StatsPeriod month(DateTime m) =>
      StatsPeriod(kind: StatsPeriodKind.month, from: DateTime(m.year, m.month), to: DateTime(m.year, m.month + 1, 0));

  static StatsPeriod year(int y) => StatsPeriod(kind: StatsPeriodKind.year, from: DateTime(y), to: DateTime(y, 12, 31));
}

DateTime _salaryDate(int year, int month, int day) {
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day.clamp(1, last));
}

/// The current month; with a salary day set, the financial month that runs from the last salary
/// day to the day before the next one.
StatsPeriod currentPeriod(DateTime now, int salaryDay) {
  final today = DateTime(now.year, now.month, now.day);
  if (salaryDay <= 1) {
    return StatsPeriod(kind: StatsPeriodKind.currentMonth, from: DateTime(now.year, now.month), to: DateTime(now.year, now.month + 1, 0));
  }
  var start = _salaryDate(now.year, now.month, salaryDay);
  if (start.isAfter(today)) start = _salaryDate(now.year, now.month - 1, salaryDay);
  final next = _salaryDate(start.year, start.month + 1, salaryDay);
  return StatsPeriod(kind: StatsPeriodKind.currentMonth, from: start, to: next.subtract(const Duration(days: 1)));
}

class StatsPeriodNotifier extends Notifier<StatsPeriod> {
  @override
  StatsPeriod build() => currentPeriod(DateTime.now(), ref.watch(settingsProvider.select((s) => s.salaryDay)));

  void set(StatsPeriod p) => state = p;
  void current() => state = currentPeriod(DateTime.now(), ref.read(settingsProvider).salaryDay);
}

final statsPeriodProvider = NotifierProvider<StatsPeriodNotifier, StatsPeriod>(StatsPeriodNotifier.new);

/// One installment line in the period: a payment made in it, or an installment due in it.
class InstallmentLine {
  const InstallmentLine({required this.item, required this.due, required this.date});
  final InstallmentWithSchedule item;
  final InstallmentDue due;

  /// Paid date for payments, due date otherwise.
  final DateTime date;
  bool get paid => due.isPaid;
  double get amount => due.payment?.amount ?? item.plan.installmentAmount;
}

/// Everything the statistics screen shows for a period.
class StatsData {
  StatsData({
    required this.period,
    required List<TransactionWithDetails> transactions,
    required List<CarWithStats> cars,
    required List<InstallmentWithSchedule> installments,
    Set<int>? categoryIds,
  }) {
    for (final t in transactions) {
      if (!period.contains(t.transaction.date)) continue;
      switch (t.transaction.type.name) {
        case 'income':
          income.add(t);
        case 'expense':
          if (categoryIds == null || categoryIds.contains(t.transaction.categoryId)) expenses.add(t);
      }
    }
    for (final c in cars) {
      for (final e in c.expenses) {
        if (period.contains(e.transaction.date) && (categoryIds == null || categoryIds.contains(e.transaction.categoryId))) {
          carExpenses.add((c, e));
        }
      }
    }
    carExpenses.sort((a, b) => b.$2.transaction.date.compareTo(a.$2.transaction.date));
    for (final i in installments) {
      for (final d in i.schedule) {
        if (d.isPaid && period.contains(d.payment!.paidAt)) {
          installmentLines.add(InstallmentLine(item: i, due: d, date: d.payment!.paidAt));
        } else if (!d.isPaid && period.contains(d.dueDate)) {
          installmentLines.add(InstallmentLine(item: i, due: d, date: d.dueDate));
        }
      }
    }
    installmentLines.sort((a, b) => b.date.compareTo(a.date));
  }

  final StatsPeriod period;
  final income = <TransactionWithDetails>[];
  final expenses = <TransactionWithDetails>[];
  final carExpenses = <(CarWithStats, CarExpenseItem)>[];
  final installmentLines = <InstallmentLine>[];

  double get totalIncome => income.fold(0, (s, t) => s + t.transaction.amount);
  double get totalExpense => expenses.fold(0, (s, t) => s + t.transaction.amount);
  double get net => totalIncome - totalExpense;
  double? get savingsRate => totalIncome == 0 ? null : net / totalIncome * 100;
  double get dailyAverage => totalExpense / period.days;
  double get carTotal => carExpenses.fold(0, (s, e) => s + e.$2.transaction.amount);
  double get installmentsPaid => installmentLines.where((l) => l.paid).fold(0, (s, l) => s + l.amount);
  double get installmentsDue => installmentLines.where((l) => !l.paid).fold(0, (s, l) => s + l.amount);

  /// Expenses per main category, largest first: (name, icon, colour, total).
  List<(String, String, String, double)> get byMainCategory {
    final map = <String, (String, String, String, double)>{};
    for (final t in expenses) {
      final name = t.parentCategoryName ?? t.categoryName;
      final prev = map[name];
      map[name] = (name, prev?.$2 ?? t.categoryIcon, prev?.$3 ?? t.categoryColor, (prev?.$4 ?? 0) + t.transaction.amount);
    }
    return map.values.toList()..sort((a, b) => b.$4.compareTo(a.$4));
  }

  List<(String, double)> get byAccount {
    final map = <String, double>{};
    for (final t in expenses) {
      final k = t.accountName ?? '—';
      map[k] = (map[k] ?? 0) + t.transaction.amount;
    }
    return map.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
  }

  /// Daily (≤ 62 days) or monthly buckets: (start, income, expense).
  List<(DateTime, double, double)> get trend {
    final daily = period.days <= 62;
    final buckets = <DateTime, (double, double)>{};
    DateTime key(DateTime d) => daily ? DateTime(d.year, d.month, d.day) : DateTime(d.year, d.month);
    var cursor = key(period.from);
    while (!cursor.isAfter(period.to)) {
      buckets[cursor] = (0, 0);
      cursor = daily ? DateTime(cursor.year, cursor.month, cursor.day + 1) : DateTime(cursor.year, cursor.month + 1);
    }
    for (final t in income) {
      final k = key(t.transaction.date);
      final v = buckets[k];
      if (v != null) buckets[k] = (v.$1 + t.transaction.amount, v.$2);
    }
    for (final t in expenses) {
      final k = key(t.transaction.date);
      final v = buckets[k];
      if (v != null) buckets[k] = (v.$1, v.$2 + t.transaction.amount);
    }
    return [for (final e in buckets.entries) (e.key, e.value.$1, e.value.$2)];
  }
}
