import 'package:drift/drift.dart';

import '../../../core/db/database.dart';

/// A category budget for one month: limit, what was spent (sub-categories roll up), and the level.
class BudgetStatus {
  const BudgetStatus({required this.budget, required this.category, required this.spent});
  final CategoryBudget budget;
  final Category category;
  final double spent;

  double get limit => budget.monthlyLimit;
  double get remaining => limit - spent;
  double get ratio => limit <= 0 ? 0 : spent / limit;

  /// UI/UX §14: warn at 80 %, limit reached at 100 %, over budget above it.
  BudgetLevel get level => ratio > 1
      ? BudgetLevel.over
      : ratio >= 1
      ? BudgetLevel.reached
      : ratio >= 0.8
      ? BudgetLevel.warning
      : BudgetLevel.ok;
}

enum BudgetLevel { ok, warning, reached, over }

class BudgetRepository {
  BudgetRepository(this._db);
  final AppDatabase _db;

  Stream<List<BudgetStatus>> watchMonth(DateTime start, DateTime end) {
    const sql = '''
SELECT b.id AS b_id, c.id AS c_id, COALESCE((
  SELECT SUM(t.amount) FROM transactions t
  JOIN categories tc ON tc.id = t.category_id
  WHERE t.type = 'expense' AND t.date BETWEEN ? AND ?
    AND (tc.id = c.id OR tc.parent_category_id = c.id)), 0) AS spent
FROM category_budgets b JOIN categories c ON c.id = b.category_id
WHERE b.is_enabled = 1
ORDER BY spent DESC''';
    return _db
        .customSelect(
          sql,
          variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
          readsFrom: {_db.categoryBudgets, _db.categories, _db.transactions},
        )
        .watch()
        .asyncMap((rows) async {
          final budgets = {for (final b in await _db.select(_db.categoryBudgets).get()) b.id: b};
          final cats = {for (final c in await _db.select(_db.categories).get()) c.id: c};
          return [
            for (final r in rows)
              if (budgets[r.read<int>('b_id')] != null && cats[r.read<int>('c_id')] != null)
                BudgetStatus(budget: budgets[r.read<int>('b_id')]!, category: cats[r.read<int>('c_id')]!, spent: r.read<double>('spent')),
          ];
        });
  }

  /// Spending per day on budgeted categories (and their sub-categories).
  Stream<Map<DateTime, double>> watchDailySpend(DateTime start, DateTime end) {
    const sql = '''
SELECT t.date AS d, SUM(t.amount) AS s FROM transactions t
JOIN categories tc ON tc.id = t.category_id
WHERE t.type = 'expense' AND t.date BETWEEN ? AND ?
  AND EXISTS (SELECT 1 FROM category_budgets b WHERE b.is_enabled = 1
    AND (b.category_id = tc.id OR b.category_id = tc.parent_category_id))
GROUP BY t.date''';
    return _db
        .customSelect(
          sql,
          variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
          readsFrom: {_db.categoryBudgets, _db.categories, _db.transactions},
        )
        .watch()
        .map((rows) {
          final out = <DateTime, double>{};
          for (final r in rows) {
            final d = r.read<DateTime>('d');
            final k = DateTime(d.year, d.month, d.day);
            out[k] = (out[k] ?? 0) + r.read<double>('s');
          }
          return out;
        });
  }

  /// One budget per (main) category: setting it again replaces the limit.
  Future<void> setBudget(int categoryId, double monthlyLimit) async {
    final existing = await (_db.select(_db.categoryBudgets)..where((b) => b.categoryId.equals(categoryId))).getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.categoryBudgets).insert(CategoryBudgetsCompanion.insert(categoryId: categoryId, monthlyLimit: monthlyLimit));
    } else {
      await (_db.update(_db.categoryBudgets)..where((b) => b.id.equals(existing.id))).write(
        CategoryBudgetsCompanion(monthlyLimit: Value(monthlyLimit), isEnabled: const Value(true)),
      );
    }
  }

  Future<void> remove(int budgetId) => (_db.delete(_db.categoryBudgets)..where((b) => b.id.equals(budgetId))).go();
}

/// Where a month stands in time, for spending-pace indicators (budgets and reports).
class MonthPace {
  MonthPace(DateTime month, {DateTime? now})
    : this.range(DateTime(month.year, month.month), DateTime(month.year, month.month + 1, 0), now: now);

  /// A period of whole days, both ends included (e.g. a salary-day budget cycle).
  MonthPace.range(DateTime start, DateTime end, {DateTime? now}) : month = start {
    final t = now ?? DateTime.now();
    final today = DateTime(t.year, t.month, t.day);
    totalDays = end.difference(start).inDays + 1;
    elapsedDays = today.isBefore(start) ? 0 : (today.isAfter(end) ? totalDays : today.difference(start).inDays + 1);
  }

  final DateTime month;
  late final int totalDays;

  /// Days of the month already lived (all of them for past months, none for future ones).
  late final int elapsedDays;
  int get daysLeft => totalDays - elapsedDays;
  bool get isCurrent => elapsedDays > 0 && elapsedDays < totalDays;

  /// Share of the month that has passed (0..1).
  double get timeRatio => elapsedDays / totalDays;

  /// Average spend per day so far.
  double dailyRate(double spent) => elapsedDays == 0 ? 0 : spent / elapsedDays;

  /// End-of-month total if spending continues at the current pace.
  double projected(double spent) => elapsedDays == 0 ? spent : spent / elapsedDays * totalDays;

  /// How much can still be spent per day to stay within [remaining].
  double? dailyAllowance(double remaining) => daysLeft > 0 && remaining > 0 ? remaining / daysLeft : null;
}
