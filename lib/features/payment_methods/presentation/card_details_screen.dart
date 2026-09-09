import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/color_utils.dart';
import '../../../core/utils/currency.dart';
import '../../transactions/presentation/transaction_providers.dart';
import 'payment_method_providers.dart';

class CardDetailsScreen extends ConsumerWidget {
  const CardDetailsScreen({super.key, required this.cardId});
  final int cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardAsync = ref.watch(cardByIdProvider(cardId));
    final range = ref.watch(currentMonthRangeProvider);
    final spendAsync = ref.watch(cardMonthSpendProvider((cardId, range.$1, range.$2)));
    final transactionsAsync = ref.watch(cardTransactionsProvider(cardId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('cards.cardDetails'.tr())),
      body: cardAsync.when(
        data: (c) {
          if (c == null) return const SizedBox.shrink();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorFromHex(c.card.color),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.card.nickname,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('${c.bankName} • ${c.card.cardType.name} ${c.card.cardCategory.name}',
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    Text('•••• •••• •••• ${c.card.last4Digits}',
                        style: const TextStyle(color: Colors.white, letterSpacing: 2)),
                    if (c.card.creditLimit != null) ...[
                      const SizedBox(height: 8),
                      Text('${'cards.creditLimit'.tr()}: ${formatAmount(c.card.creditLimit!)}',
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (c.card.dueDateDay != null)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('cards.dueDate'.tr()),
                            Text('${c.card.dueDateDay}', style: theme.textTheme.titleMedium),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('cards.spendThisMonth'.tr()),
                          Text(formatAmount(spendAsync.value ?? 0),
                              style: theme.textTheme.titleMedium),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('cards.cardTransactions'.tr(), style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...(transactionsAsync.value ?? const []).map(
                (t) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.transaction.beneficiaryName ?? t.categoryName),
                          Text(DateFormat.yMd().format(t.transaction.date),
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                      Text(
                        '-${formatAmount(t.transaction.amount)}',
                        style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.push('/cards/$cardId/edit'),
                child: Text('cards.editCard'.tr()),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('$e')),
      ),
    );
  }
}
