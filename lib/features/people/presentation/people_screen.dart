import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/currency.dart';
import '../data/ledger_repository.dart';
import 'people_providers.dart';

/// Colour for a net position: they owe me (positive), I owe them (negative), settled.
Color netColor(BuildContext context, double net) {
  if (net > 0) return Colors.green.shade700;
  if (net < 0) return Theme.of(context).colorScheme.error;
  return Theme.of(context).colorScheme.onSurfaceVariant;
}

String netLabel(BuildContext context, double net) => net > 0
    ? 'people.heOwesMe'.tr(context: context)
    : net < 0
        ? 'people.iOweHim'.tr(context: context)
        : 'people.settled'.tr(context: context);

class NotificationsBell extends ConsumerWidget {
  const NotificationsBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;
    return IconButton(
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(peopleWithBalancesProvider).value ?? const <PersonWithBalance>[];
    final (receivable, payable) = ref.watch(outstandingTotalsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('people.title'.tr(context: context)),
        actions: [
          const NotificationsBell(),
          IconButton(
            tooltip: 'people.add'.tr(context: context),
            onPressed: () => context.push('/people/new'),
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _Total(label: 'people.totalReceivable'.tr(context: context), amount: receivable, color: Colors.green.shade700)),
              const SizedBox(width: 12),
              Expanded(child: _Total(label: 'people.totalPayable'.tr(context: context), amount: payable, color: theme.colorScheme.error)),
            ],
          ),
          const SizedBox(height: 16),
          if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Text('people.empty'.tr(context: context), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.push('/people/new'),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: Text('people.add'.tr(context: context)),
                  ),
                ],
              ),
            ),
          for (final p in people)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(p.person.linkedUserId != null ? Icons.verified_user_outlined : Icons.person_outline),
                ),
                title: Text(p.person.name),
                subtitle: p.balance.pendingCount > 0
                    ? Text('people.pending'.tr(namedArgs: {'count': '${p.balance.pendingCount}'}, context: context))
                    : null,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatAmount(p.balance.net.abs()),
                      style: TextStyle(fontWeight: FontWeight.bold, color: netColor(context, p.balance.net)),
                    ),
                    Text(netLabel(context, p.balance.net), style: theme.textTheme.bodySmall),
                  ],
                ),
                onTap: () => context.push('/people/${p.person.id}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.amount, required this.color});
  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(formatAmount(amount), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
