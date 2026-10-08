import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/tables.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../people/presentation/people_providers.dart';
import '../../transactions/data/transaction_models.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';

final reportsMonthProvider = NotifierProvider<MonthNotifier, DateTime>(MonthNotifier.new);

/// Reports (UI/UX §15, mockup 16): monthly total vs last month, expenses by category (donut),
/// income vs expenses over 6 months, expenses by account, and people receivables / payables.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(reportsMonthProvider);
    final range = getMonthRange(month);
    final prevRange = getMonthRange(DateTime(month.year, month.month - 1));
    final summary = ref.watch(monthSummaryProvider(range)).value;
    final prev = ref.watch(monthSummaryProvider(prevRange)).value;
    final breakdown = ref.watch(expenseCategoryBreakdownProvider(range)).value ?? const <CategoryBreakdownItem>[];
    final expenses = ref.watch(transactionsListProvider(TransactionFilters(types: const {TransactionType.expense}, from: range.$1, to: range.$2))).value ??
        const <TransactionWithDetails>[];
    final (receivable, payable) = ref.watch(outstandingTotalsProvider);
    final theme = Theme.of(context);

    final expense = summary?.expense ?? 0;
    final prevExpense = prev?.expense ?? 0;
    final change = prevExpense == 0 ? null : (expense - prevExpense) / prevExpense * 100;
    final total = breakdown.fold<double>(0, (s, i) => s + i.total);

    final byAccount = <String, double>{};
    for (final t in expenses) {
      final k = t.accountName ?? 'accounts.none'.tr();
      byAccount[k] = (byAccount[k] ?? 0) + t.transaction.amount;
    }
    final accountRows = byAccount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: Text('reports.title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(child: MonthSelector(month: month, onChanged: (m) => ref.read(reportsMonthProvider.notifier).set(m))),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Row(children: [
              IconBubble(icon: Icons.shopping_bag_outlined, color: theme.colorScheme.error, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('reports.totalExpenses'.tr(), style: theme.textTheme.bodySmall),
                  AmountText(expense, size: 24, weight: FontWeight.w800),
                ]),
              ),
              if (change != null)
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Row(children: [
                    Icon(change >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14, color: change >= 0 ? theme.colorScheme.error : DS.success),
                    Text('${change.abs().toStringAsFixed(1)}%',
                        style: TextStyle(fontWeight: FontWeight.w700, color: change >= 0 ? theme.colorScheme.error : DS.success)),
                  ]),
                  Text('reports.vsLastMonth'.tr(), style: theme.textTheme.bodySmall),
                ]),
            ]),
          ),
          SectionHeader('reports.byCategory'.tr()),
          AppCard(
            child: breakdown.isEmpty
                ? EmptyState(icon: Icons.donut_large, title: 'dashboard.noSpending'.tr())
                : Row(children: [
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: Stack(alignment: Alignment.center, children: [
                        PieChart(PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 46,
                          sections: [
                            for (final i in breakdown)
                              PieChartSectionData(value: i.total, color: colorFromHex(i.categoryColor), showTitle: false, radius: 22),
                          ],
                        )),
                        AmountText(total, size: 14),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(children: [
                        for (final i in breakdown.take(6))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: colorFromHex(i.categoryColor), shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Expanded(child: Text(i.categoryName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                              Text('${(i.total / total * 100).round()}%', style: theme.textTheme.labelMedium),
                            ]),
                          ),
                      ]),
                    ),
                  ]),
          ),
          SectionHeader('reports.incomeVsExpenses'.tr()),
          const AppCard(child: _IncomeExpenseBars()),
          SectionHeader('reports.byAccount'.tr()),
          AppCard(
            child: accountRows.isEmpty
                ? Text('dashboard.noSpending'.tr())
                : Column(children: [
                    for (final r in accountRows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Expanded(child: Text(r.key)),
                          AmountText(r.value, size: 13),
                        ]),
                      ),
                  ]),
          ),
          SectionHeader('reports.people'.tr()),
          AppCard(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('people.totalReceivable'.tr(), style: theme.textTheme.bodySmall),
                  AmountText(receivable, color: DS.success),
                ]),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('people.totalPayable'.tr(), style: theme.textTheme.bodySmall),
                  AmountText(payable, color: theme.colorScheme.error),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _IncomeExpenseBars extends ConsumerWidget {
  const _IncomeExpenseBars();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(monthOverMonthProvider(6)).value ?? const <MonthTotal>[];
    if (data.isEmpty) return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
    final maxY = data.fold<double>(0, (m, d) => [m, d.income, d.expense].reduce((a, b) => a > b ? a : b));
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      SizedBox(
        height: 170,
        child: BarChart(BarChartData(
          maxY: maxY == 0 ? 1 : maxY * 1.15,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  final parts = data[i].month.split('-');
                  return Text(DateFormat.MMM(context.locale.languageCode).format(DateTime(int.parse(parts[0]), int.parse(parts[1]))),
                      style: const TextStyle(fontSize: 10));
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(x: i, barsSpace: 3, barRods: [
                BarChartRodData(toY: data[i].income, color: DS.success, width: 8, borderRadius: BorderRadius.circular(3)),
                BarChartRodData(toY: data[i].expense, color: scheme.error, width: 8, borderRadius: BorderRadius.circular(3)),
              ]),
          ],
        )),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _Legend(color: DS.success, label: 'dashboard.income'.tr()),
        const SizedBox(width: 16),
        _Legend(color: scheme.error, label: 'dashboard.expenses'.tr()),
      ]),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]);
}
