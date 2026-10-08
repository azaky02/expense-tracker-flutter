import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/ds_tokens.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../data/ledger_repository.dart';
import 'people_providers.dart';

/// Colour for a net position: they owe me (green), I owe them (red), settled (muted). UX §19.
Color netColor(BuildContext context, double net) {
  if (net > 0) return DS.success;
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
      icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_outlined)),
    );
  }
}

/// Initial-letter avatar tinted by balance direction.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.name, required this.color, this.size = 42, this.linked = false});
  final String name;
  final Color color;
  final double size;
  final bool linked;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim().characters.first;
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
        child: Text(letter, style: TextStyle(color: color, fontSize: size * 0.42, fontWeight: FontWeight.w800)),
      ),
      if (linked)
        PositionedDirectional(
          bottom: -2,
          end: -2,
          child: Container(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, shape: BoxShape.circle),
            child: const Icon(Icons.verified, size: 14, color: DS.primary),
          ),
        ),
    ]);
  }
}

/// People (PPL-01, mockup 10): search, "they owe me", "I owe them", everyone else.
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(peopleWithBalancesProvider);
    final (receivable, payable) = ref.watch(outstandingTotalsProvider);
    final q = _search.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: Text('people.title'.tr()),
        leading: const NotificationsBell(),
        actions: [
          IconButton(
            tooltip: 'people.add'.tr(),
            onPressed: () => context.push('/people/new'),
            icon: const Icon(Icons.add_circle, color: DS.primary, size: 28),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: SkeletonList()),
        error: (e, _) => ErrorState(message: 'common.loadError'.tr(), onRetry: () => ref.invalidate(peopleWithBalancesProvider)),
        data: (all) {
          if (all.isEmpty) {
            return EmptyState(
              icon: Icons.people_alt_outlined,
              title: 'people.emptyTitle'.tr(),
              message: 'people.empty'.tr(),
              actionLabel: 'people.add'.tr(),
              onAction: () => context.push('/people/new'),
            );
          }
          final people = q.isEmpty ? all : all.where((p) => p.person.name.toLowerCase().contains(q)).toList();
          final owesMe = people.where((p) => p.balance.net > 0).toList();
          final iOwe = people.where((p) => p.balance.net < 0).toList();
          final rest = people.where((p) => p.balance.net == 0).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'people.search'.tr()),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _Total(label: 'people.totalReceivable'.tr(), amount: receivable, color: DS.success)),
                const SizedBox(width: 10),
                Expanded(child: _Total(label: 'people.totalPayable'.tr(), amount: payable, color: Theme.of(context).colorScheme.error)),
              ]),
              if (owesMe.isNotEmpty) ...[SectionHeader('people.sectionOwesMe'.tr()), _Group(owesMe)],
              if (iOwe.isNotEmpty) ...[SectionHeader('people.sectionIOwe'.tr()), _Group(iOwe)],
              if (rest.isNotEmpty) ...[SectionHeader('people.sectionAll'.tr()), _Group(rest)],
            ],
          );
        },
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.people);
  final List<PersonWithBalance> people;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(children: [
        for (final p in people)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: PersonAvatar(name: p.person.name, color: netColor(context, p.balance.net), linked: p.person.linkedUserId != null),
            title: Text(p.person.name, style: theme.textTheme.titleSmall),
            subtitle: Text(
              p.balance.pendingCount > 0
                  ? 'people.pending'.tr(namedArgs: {'count': '${p.balance.pendingCount}'})
                  : netLabel(context, p.balance.net),
              style: theme.textTheme.bodySmall?.copyWith(color: p.balance.pendingCount > 0 ? DS.warning : null),
            ),
            trailing: AmountText(p.balance.net.abs(), size: 15, color: netColor(context, p.balance.net)),
            onTap: () => context.push('/people/${p.person.id}'),
          ),
      ]),
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
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        AmountText(amount, size: 18, color: color),
      ]),
    );
  }
}
