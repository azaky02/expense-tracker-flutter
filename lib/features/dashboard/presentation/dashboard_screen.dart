import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/settings_provider.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../payment_methods/data/card_repository.dart';
import '../../payment_methods/presentation/payment_method_providers.dart';
import '../../transactions/data/transaction_models.dart';
import '../../transactions/presentation/transaction_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final greeting = settings.userName.isNotEmpty
        ? 'dashboard.greeting'.tr(namedArgs: {'name': settings.userName})
        : 'dashboard.greetingGeneric'.tr();

    final range = ref.watch(currentMonthRangeProvider);
    final summaryAsync = ref.watch(monthSummaryProvider(range));
    final breakdownAsync = ref.watch(expenseCategoryBreakdownProvider(range));
    final recentAsync = ref.watch(recentTransactionsProvider(5));
    final cardsAsync = ref.watch(activeCardsProvider);
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    final income = summaryAsync.value?.income ?? 0;
    final expense = summaryAsync.value?.expense ?? 0;
    final remaining = income - expense;
    final breakdown = breakdownAsync.value ?? const [];

    ({CardWithBank card, int days})? upcomingDue;
    final cards = cardsAsync.value ?? const [];
    for (final c in cards) {
      if (c.card.dueDateDay == null) continue;
      final days = daysUntilNextDueDate(c.card.dueDateDay!);
      if (days <= 7 && (upcomingDue == null || days < upcomingDue.days)) {
        upcomingDue = (card: c, days: days);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(greeting),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => context.push('/reports'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'dashboard.totalSpentThisMonth'.tr(),
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 4),
                Text(
                  formatAmount(expense),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${'dashboard.income'.tr()}: ${formatAmount(income)} | ${'dashboard.remaining'.tr()}: ${formatAmount(remaining)}',
                  style: TextStyle(color: semantic.income),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (breakdown.isNotEmpty) ...[
            Text('dashboard.expenseByCategory'.tr(), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 32,
                        sections: [
                          for (var i = 0; i < breakdown.length; i++)
                            PieChartSectionData(
                              value: breakdown[i].total,
                              color: breakdown[i].categoryColor.isNotEmpty
                                  ? colorFromHex(breakdown[i].categoryColor)
                                  : semantic.chartPalette[i % semantic.chartPalette.length],
                              showTitle: false,
                              radius: 24,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final item in breakdown.take(5))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: item.categoryColor.isNotEmpty
                                        ? colorFromHex(item.categoryColor)
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(item.categoryName, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (upcomingDue != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: semantic.warningSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'dashboard.dueSoonAlert'.tr(namedArgs: {
                  'days': upcomingDue.days.toString(),
                  'cardName': upcomingDue.card.card.nickname,
                }),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text('dashboard.recentTransactions'.tr(), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...(recentAsync.value ?? const <TransactionWithDetails>[])
              .map((t) => _TransactionTile(item: t)),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.item});
  final TransactionWithDetails item;

  @override
  Widget build(BuildContext context) {
    final isExpense = item.transaction.type.name == 'expense';
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: Text(item.categoryIcon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.transaction.beneficiaryName ?? item.categoryName),
                Text(
                  item.transaction.paymentMethodType.name == 'cash'
                      ? 'common.cash'.tr()
                      : item.cardNickname ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${isExpense ? '-' : '+'}${formatAmount(item.transaction.amount)}',
            style: TextStyle(
              color: isExpense ? semantic.expense : semantic.income,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
