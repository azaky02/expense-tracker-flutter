import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/tables.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/presentation/category_providers.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';
import '../data/budget_repository.dart';
import 'budget_providers.dart';

final budgetsMonthProvider = NotifierProvider<MonthNotifier, DateTime>(MonthNotifier.new);

Color budgetColor(BuildContext context, BudgetStatus b) => switch (b.level) {
      BudgetLevel.ok => colorFromHex(b.category.color),
      BudgetLevel.warning => DS.warning,
      BudgetLevel.reached || BudgetLevel.over => Theme.of(context).colorScheme.error,
    };

/// Budgets (UI/UX §14, mockup 15): month, each category's spent / limit with a progress bar and
/// 80 % / 100 % / over-budget states.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(budgetsMonthProvider);
    final async = ref.watch(budgetsForMonthProvider(month));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('budgets.screenTitle'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(child: MonthSelector(month: month, onChanged: (m) => ref.read(budgetsMonthProvider.notifier).set(m))),
          ),
          const SizedBox(height: 12),
          ...async.when(
            loading: () => [const SkeletonList(count: 4)],
            error: (e, _) => [ErrorState(message: 'common.loadError'.tr())],
            data: (list) => list.isEmpty
                ? [
                    AppCard(
                      child: EmptyState(
                        icon: Icons.pie_chart_outline,
                        title: 'budgets.empty'.tr(),
                        message: 'budgets.emptyHint'.tr(),
                        actionLabel: 'budgets.add'.tr(),
                        onAction: () => _editBudget(context, ref),
                      ),
                    ),
                  ]
                : [
                    for (final b in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          onTap: () => _editBudget(context, ref, existing: b),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              IconBubble(emoji: b.category.icon, color: colorFromHex(b.category.color), size: 38),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(b.category.name, style: theme.textTheme.titleSmall),
                                  Row(children: [
                                    AmountText(b.spent, size: 12, color: theme.colorScheme.onSurfaceVariant),
                                    Text(' / ', style: theme.textTheme.bodySmall),
                                    AmountText(b.limit, size: 12, color: theme.colorScheme.onSurfaceVariant),
                                  ]),
                                ]),
                              ),
                              Text('${(b.ratio * 100).round()}%',
                                  style: theme.textTheme.titleSmall?.copyWith(color: budgetColor(context, b))),
                            ]),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(value: b.ratio.clamp(0, 1), minHeight: 8, color: budgetColor(context, b)),
                            ),
                            if (b.level != BudgetLevel.ok) ...[
                              const SizedBox(height: 6),
                              Text(
                                'budgets.status.${b.level.name}'.tr(),
                                style: theme.textTheme.bodySmall?.copyWith(color: budgetColor(context, b)),
                              ),
                            ],
                          ]),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _editBudget(context, ref),
                      icon: const Icon(Icons.add),
                      label: Text('budgets.add'.tr()),
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  Future<void> _editBudget(BuildContext context, WidgetRef ref, {BudgetStatus? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BudgetSheet(existing: existing),
    );
  }
}

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({this.existing});
  final BudgetStatus? existing;

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  late int? _categoryId = widget.existing?.category.id;
  late final _limit = TextEditingController(text: widget.existing == null ? '' : widget.existing!.limit.toStringAsFixed(0));

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tree = ref.watch(categoryTreeProvider(CategoryType.expense)).value ?? const <CategoryTreeNode>[];
    final limit = double.tryParse(_limit.text.replaceAll(',', '')) ?? 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text((widget.existing == null ? 'budgets.add' : 'budgets.edit').tr(), style: Theme.of(context).textTheme.titleMedium),
        FieldLabel('transactions.category'.tr()),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final n in tree)
            ChoiceChip(
              avatar: Text(n.main.icon),
              label: Text(n.main.name),
              selected: _categoryId == n.main.id,
              onSelected: widget.existing != null ? null : (_) => setState(() => _categoryId = n.main.id),
            ),
        ]),
        FieldLabel('budgets.monthlyLimit'.tr()),
        AmountField(controller: _limit, onChanged: (_) => setState(() {})),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _categoryId == null || limit <= 0
              ? null
              : () async {
                  await ref.read(budgetRepositoryProvider).setBudget(_categoryId!, limit);
                  if (context.mounted) Navigator.pop(context);
                },
          child: Text('common.save'.tr()),
        ),
        if (widget.existing != null)
          TextButton(
            onPressed: () async {
              await ref.read(budgetRepositoryProvider).remove(widget.existing!.budget.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text('common.delete'.tr(), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
      ]),
    );
  }
}
