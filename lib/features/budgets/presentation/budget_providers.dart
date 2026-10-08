import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../data/budget_repository.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) => BudgetRepository(ref.watch(databaseProvider)));

/// Budgets for the month containing [month] (any day of it).
final budgetsForMonthProvider = StreamProvider.family<List<BudgetStatus>, DateTime>((ref, month) {
  final (start, end) = getMonthRange(month);
  return ref.watch(budgetRepositoryProvider).watchMonth(start, end);
});
