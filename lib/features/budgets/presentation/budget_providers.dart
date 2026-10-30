import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../data/budget_repository.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) => BudgetRepository(ref.watch(databaseProvider)));

/// Budgets for the cycle named by [month] (salary day to salary day when one is set).
final budgetsForMonthProvider = StreamProvider.family<List<BudgetStatus>, DateTime>((ref, month) {
  final (start, end) = budgetCycleRange(month, ref.watch(settingsProvider.select((s) => s.salaryDay)));
  return ref.watch(budgetRepositoryProvider).watchMonth(start, end);
});

/// Budgeted spending per day of the cycle named by [month].
final budgetDailySpendProvider = StreamProvider.family<Map<DateTime, double>, DateTime>((ref, month) {
  final (start, end) = budgetCycleRange(month, ref.watch(settingsProvider.select((s) => s.salaryDay)));
  return ref.watch(budgetRepositoryProvider).watchDailySpend(start, end);
});

/// The month whose cycle contains today.
DateTime currentBudgetMonth(Ref ref) => budgetCycleMonthOf(DateTime.now(), ref.read(settingsProvider).salaryDay);
