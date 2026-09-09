import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/tables.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../categories/presentation/category_providers.dart';
import '../data/transaction_models.dart';
import '../data/transaction_repository.dart';
import 'quick_note_dialog.dart';
import 'transaction_providers.dart';

enum _PaymentFilter { all, cash, card }

class TransactionsListScreen extends ConsumerStatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  ConsumerState<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends ConsumerState<TransactionsListScreen> {
  _PaymentFilter _paymentFilter = _PaymentFilter.all;
  int? _categoryFilterId;

  @override
  Widget build(BuildContext context) {
    final categoryTreeAsync = ref.watch(categoryTreeProvider(null));
    final categoryTree = categoryTreeAsync.value ?? const [];

    List<int>? categoryIds;
    if (_categoryFilterId != null) {
      final main = categoryTree.where((n) => n.main.id == _categoryFilterId).firstOrNull;
      categoryIds = main == null
          ? [_categoryFilterId!]
          : [main.main.id, ...main.children.map((c) => c.id)];
    }

    final filters = TransactionFilters(
      categoryIds: categoryIds,
      paymentMethodType: switch (_paymentFilter) {
        _PaymentFilter.all => null,
        _PaymentFilter.cash => PaymentMethodType.cash,
        _PaymentFilter.card => PaymentMethodType.card,
      },
    );
    final listAsync = ref.watch(transactionsListProvider(filters));

    return Scaffold(
      appBar: AppBar(title: Text('nav.transactions'.tr())),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final option in _PaymentFilter.values)
                  ChoiceChip(
                    label: Text(switch (option) {
                      _PaymentFilter.all => 'common.all'.tr(),
                      _PaymentFilter.cash => 'common.cash'.tr(),
                      _PaymentFilter.card => 'common.card'.tr(),
                    }),
                    selected: _paymentFilter == option,
                    onSelected: (_) => setState(() => _paymentFilter = option),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final node in categoryTree)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Text(node.main.icon),
                      label: Text(node.main.name),
                      selected: _categoryFilterId == node.main.id,
                      onSelected: (_) => setState(
                        () => _categoryFilterId = _categoryFilterId == node.main.id ? null : node.main.id,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: listAsync.when(
              data: (items) => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) => _TransactionRow(item: items[index]),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('$e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends ConsumerWidget {
  const _TransactionRow({required this.item});
  final TransactionWithDetails item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = item.transaction.type == TransactionType.expense;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => context.push('/transactions/${item.transaction.id}/edit'),
      onDoubleTap: () async {
        final (start, end) = getMonthRange();
        final total = await ref.read(
          categoryMonthTotalProvider((item.transaction.categoryId, start, end)).future,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'transactions.monthTotalForCategory'.tr(
                  namedArgs: {'category': item.categoryName, 'amount': formatAmount(total)},
                ),
              ),
            ),
          );
        }
      },
      onLongPress: () async {
        final note = await showQuickNoteDialog(context, item.transaction.note ?? '');
        if (note != null) {
          await ref.read(transactionRepositoryProvider).updateNote(item.transaction.id, note);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: theme.colorScheme.surface, child: Text(item.categoryIcon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.transaction.beneficiaryName ?? item.categoryName),
                  Text(
                    [
                      DateFormat.yMd().format(item.transaction.date),
                      item.transaction.paymentMethodType == PaymentMethodType.cash
                          ? 'common.cash'.tr()
                          : item.cardNickname ?? '',
                      if (item.transaction.note != null && item.transaction.note!.isNotEmpty) '📝',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              '${isExpense ? '-' : '+'}${formatAmount(item.transaction.amount)}',
              style: TextStyle(
                color: isExpense ? theme.colorScheme.error : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
