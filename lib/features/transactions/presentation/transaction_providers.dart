import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../data/transaction_models.dart';
import '../data/transaction_repository.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(databaseProvider));
});

final recentTransactionsProvider = StreamProvider.family<List<TransactionWithDetails>, int>(
  (ref, limit) => ref.watch(transactionRepositoryProvider).watchRecent(limit),
);

final transactionsListProvider =
    StreamProvider.family<List<TransactionWithDetails>, TransactionFilters>(
  (ref, filters) => ref.watch(transactionRepositoryProvider).watchList(filters),
);

final cardTransactionsProvider = StreamProvider.family<List<TransactionWithDetails>, int>(
  (ref, cardId) => ref.watch(transactionRepositoryProvider).watchCardTransactions(cardId),
);

final transactionByIdProvider = FutureProvider.family((ref, int id) {
  return ref.watch(transactionRepositoryProvider).getById(id);
});

final currentMonthRangeProvider = Provider<(DateTime, DateTime)>((ref) => getMonthRange());

final monthSummaryProvider = StreamProvider.family<MonthSummary, (DateTime, DateTime)>(
  (ref, range) => ref.watch(transactionRepositoryProvider).watchMonthSummary(range.$1, range.$2),
);

final expenseCategoryBreakdownProvider =
    StreamProvider.family<List<CategoryBreakdownItem>, (DateTime, DateTime)>(
  (ref, range) =>
      ref.watch(transactionRepositoryProvider).watchExpenseCategoryBreakdown(range.$1, range.$2),
);

final categoryMonthTotalProvider =
    FutureProvider.family<double, (int categoryId, DateTime start, DateTime end)>((ref, args) {
  return ref
      .watch(transactionRepositoryProvider)
      .getCategoryMonthTotal(args.$1, args.$2, args.$3);
});

final cardMonthSpendProvider =
    StreamProvider.family<double, (int cardId, DateTime start, DateTime end)>((ref, args) {
  return ref.watch(transactionRepositoryProvider).watchCardMonthSpend(args.$1, args.$2, args.$3);
});

final cashMonthSpendProvider = StreamProvider.family<double, (DateTime, DateTime)>(
  (ref, range) => ref.watch(transactionRepositoryProvider).watchCashMonthSpend(range.$1, range.$2),
);

final expenseByPaymentMethodProvider =
    StreamProvider.family<List<PaymentMethodBreakdownItem>, (DateTime, DateTime)>(
  (ref, range) =>
      ref.watch(transactionRepositoryProvider).watchExpenseByPaymentMethod(range.$1, range.$2),
);

final monthOverMonthProvider = FutureProvider.family<List<MonthTotal>, int>(
  (ref, monthsBack) => ref.watch(transactionRepositoryProvider).getMonthOverMonthTotals(monthsBack),
);

final beneficiaryBreakdownProvider =
    FutureProvider.family<List<BeneficiaryBreakdownItem>, (DateTime, DateTime)>(
  (ref, range) => ref.watch(transactionRepositoryProvider).getBeneficiaryBreakdown(range.$1, range.$2),
);
