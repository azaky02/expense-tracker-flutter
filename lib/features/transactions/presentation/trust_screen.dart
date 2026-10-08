import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/tables.dart';
import '../../../core/utils/currency.dart';
import '../data/transaction_models.dart';
import 'transaction_providers.dart';

/// Amanat: one row per person with what you hold for them (or what they owe you).
class TrustScreen extends ConsumerWidget {
  const TrustScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(trustBalancesProvider).value ?? const <TrustBalance>[];
    final held = balances.where((b) => b.balance > 0).fold<double>(0, (s, b) => s + b.balance);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('trust.title'.tr(context: context))),
      body: balances.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('trust.empty'.tr(context: context), textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('trust.totalHeld'.tr(context: context),
                          style: TextStyle(color: theme.colorScheme.onPrimary.withValues(alpha: 0.8))),
                      const SizedBox(height: 4),
                      Text(formatAmount(held),
                          style: TextStyle(
                              color: theme.colorScheme.onPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final b in balances)
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                      title: Text(b.name),
                      subtitle: Text(
                        '${'trust.received'.tr(context: context)} ${formatAmount(b.received)} · '
                        '${'trust.paid'.tr(context: context)} ${formatAmount(b.paid)}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatAmount(b.balance.abs()),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: b.balance > 0 ? Colors.amber.shade800 : (b.balance < 0 ? theme.colorScheme.error : null),
                            ),
                          ),
                          Text(
                            (b.balance > 0 ? 'trust.holding' : b.balance < 0 ? 'trust.owesMe' : 'trust.settled')
                                .tr(context: context),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      onTap: () => context.push('/trust/${Uri.encodeComponent(b.name)}'),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// All amanat transactions with one person.
class TrustPersonScreen extends ConsumerWidget {
  const TrustPersonScreen({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(trustTransactionsProvider(name)).value ?? const <TransactionWithDetails>[];
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final item in items)
            Card(
              child: ListTile(
                title: Text(
                  (item.transaction.type == TransactionType.trustIn ? 'transactions.trustIn' : 'transactions.trustOut')
                      .tr(context: context),
                ),
                subtitle: Text([
                  DateFormat.yMd().format(item.transaction.date),
                  if (item.transaction.note != null && item.transaction.note!.isNotEmpty) item.transaction.note!,
                ].join(' · ')),
                trailing: Text(
                  '${item.transaction.type == TransactionType.trustOut ? '-' : '+'}${formatAmount(item.transaction.amount)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade800),
                ),
                onTap: () => context.push('/transactions/${item.transaction.id}/edit'),
              ),
            ),
          if (items.isEmpty) Center(child: Text('trust.empty'.tr(context: context), style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
