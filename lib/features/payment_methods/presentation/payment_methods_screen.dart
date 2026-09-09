import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/utils/currency.dart';
import '../../transactions/presentation/transaction_providers.dart';
import 'payment_method_providers.dart';

class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(activeCardsProvider);
    final range = ref.watch(currentMonthRangeProvider);
    final cashSpendAsync = ref.watch(cashMonthSpendProvider(range));
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return Scaffold(
      appBar: AppBar(title: Text('cards.paymentMethods'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: semantic.cash, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('common.cash'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(
                  'cards.cashSpendThisMonth'.tr(namedArgs: {'amount': formatAmount(cashSpendAsync.value ?? 0)}),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          ...(cardsAsync.value ?? const []).map(
            (c) => GestureDetector(
              onTap: () => context.push('/cards/${c.card.id}'),
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colorFromHex(c.card.color),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.card.nickname,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(
                      '${c.bankName} • ${c.card.cardCategory.name == 'credit' ? 'cards.credit'.tr() : 'cards.debit'.tr()}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('**** ${c.card.last4Digits}', style: const TextStyle(color: Colors.white)),
                        if (c.card.dueDateDay != null)
                          Text(
                            '${'cards.dueDate'.tr()}: ${c.card.dueDateDay}',
                            style: const TextStyle(color: Colors.amber),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => context.push('/cards/add'),
            icon: const Icon(Icons.add),
            label: Text('cards.addNewCard'.tr()),
          ),
        ],
      ),
    );
  }
}
