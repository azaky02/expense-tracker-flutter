import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart' hide Card;
import '../../../core/db/tables.dart';
import '../../../core/sync/sync_controller.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../data/ledger_repository.dart';
import 'people_providers.dart';
import 'people_screen.dart';

String kindLabel(BuildContext context, LedgerKind k) => 'ledger.kind.${k.name}'.tr(context: context);
String statusLabel(BuildContext context, LedgerStatus s) => 'ledger.status.${s.name}'.tr(context: context);
String directionLabel(BuildContext context, LedgerDirection d) =>
    (d == LedgerDirection.gave ? 'ledger.gave' : 'ledger.received').tr(context: context);

Color statusColor(BuildContext context, LedgerStatus s) => switch (s) {
      LedgerStatus.confirmed => DS.success,
      LedgerStatus.pending => DS.warning,
      LedgerStatus.rejected => Theme.of(context).colorScheme.error,
      LedgerStatus.cancelled => Theme.of(context).colorScheme.onSurfaceVariant,
    };

/// Person details (PPL-02, mockup 11): current balance, settle / statement / new entry, latest
/// transactions with their status.
class PersonScreen extends ConsumerWidget {
  const PersonScreen({super.key, required this.personId});
  final int personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(personProvider(personId)).value;
    final entries = ref.watch(personEntriesProvider(personId)).value ?? const <LedgerEntry>[];
    final balance = PersonBalance.of(entries);
    final theme = Theme.of(context);
    if (person == null) return Scaffold(appBar: AppBar());
    final net = balance.net;

    return Scaffold(
      appBar: AppBar(
        actions: [IconButton(onPressed: () => context.push('/people/$personId/edit'), icon: const Icon(Icons.more_vert))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Center(child: PersonAvatar(name: person.name, color: DS.primary, size: 72, linked: person.linkedUserId != null)),
          const SizedBox(height: 8),
          Text(person.name, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          AppCard(
            child: Column(children: [
              Text('people.currentBalance'.tr(), style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              AmountText(net.abs(), size: 30, weight: FontWeight.w800, color: netColor(context, net)),
              Text(netLabel(context, net), style: theme.textTheme.titleSmall?.copyWith(color: netColor(context, net))),
              if (balance.heOwesMe > 0 && balance.iOweHim > 0) ...[
                const Divider(height: 24),
                Row(children: [
                  Expanded(child: _Mini('people.heOwesMe'.tr(), balance.heOwesMe, DS.success)),
                  Expanded(child: _Mini('people.iOweHim'.tr(), balance.iOweHim, theme.colorScheme.error)),
                ]),
              ],
              if (balance.pendingCount > 0) ...[
                const SizedBox(height: 8),
                StatusPill('people.pending'.tr(namedArgs: {'count': '${balance.pendingCount}'}), color: DS.warning, icon: Icons.schedule),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: () => context.push('/ledger/new?personId=$personId&kind=settlement'),
                child: Text('people.settlement'.tr()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.push('/people/$personId/statement'),
                child: Text('people.statement'.tr()),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.push('/ledger/new?personId=$personId'),
            icon: const Icon(Icons.add_circle_outline),
            label: Text('people.newEntry'.tr()),
          ),
          Text(
            person.linkedUserId != null || (person.email?.isNotEmpty ?? false) ? 'people.linked'.tr() : 'people.notLinked'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          SectionHeader('people.latest'.tr()),
          if (entries.isEmpty)
            AppCard(child: EmptyState(icon: Icons.handshake_outlined, title: 'people.noEntries'.tr()))
          else
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(children: [for (final e in entries) _EntryTile(entry: e, personName: person.name)]),
            ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.amount, this.color);
  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        AmountText(amount, size: 14, color: color),
      ]);
}

/// Money in (received) shows as +green, money out (gave) as -red, like the mockups.
class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry, required this.personName});
  final LedgerEntry entry;
  final String personName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final inbound = entry.direction == LedgerDirection.received;
    final color = inbound ? DS.success : theme.colorScheme.error;
    final faded = entry.status == LedgerStatus.rejected || entry.status == LedgerStatus.cancelled;
    // Without an account nothing is ever sent, so "waiting to sync" would only be noise.
    final showQueued = entry.queued && ref.watch(syncControllerProvider).signedIn;
    final title = entry.kind == LedgerKind.settlement
        ? kindLabel(context, entry.kind)
        : (inbound ? 'ledger.receivedFrom' : 'ledger.gaveTo').tr(namedArgs: {'name': personName});
    return InkWell(
      onTap: () => showEntrySheet(context, ref, entry),
      borderRadius: BorderRadius.circular(DS.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          IconBubble(icon: inbound ? Icons.south_west : Icons.north_east, color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.titleSmall),
              Text(
                [DateFormat.yMMMd(context.locale.languageCode).format(entry.date), if (entry.description != null) entry.description!].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Opacity(opacity: faded ? 0.45 : 1, child: AmountText(inbound ? entry.amount : -entry.amount, size: 14, color: color, signed: true)),
            if (entry.status != LedgerStatus.confirmed || showQueued)
              StatusPill(
                showQueued && entry.status == LedgerStatus.confirmed ? 'ledger.queued'.tr() : statusLabel(context, entry.status),
                color: showQueued && entry.status == LedgerStatus.confirmed ? theme.colorScheme.onSurfaceVariant : statusColor(context, entry.status),
              ),
          ]),
        ]),
      ),
    );
  }
}

/// Details of one entry plus the actions allowed for this user: the other party confirms/rejects a
/// pending entry; its creator can withdraw it while pending (or void a one-sided record).
Future<void> showEntrySheet(BuildContext context, WidgetRef ref, LedgerEntry e) {
  final repo = ref.read(ledgerRepositoryProvider);
  final canAnswer = !e.createdByMe && e.status == LedgerStatus.pending;
  final canCancel = e.createdByMe &&
      (e.status == LedgerStatus.pending || (e.status == LedgerStatus.confirmed && e.counterpartUserId == null));
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(formatAmount(e.amount), style: Theme.of(ctx).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('${kindLabel(ctx, e.kind)} · ${directionLabel(ctx, e.direction)}', textAlign: TextAlign.center),
            Text(DateFormat.yMMMd(ctx.locale.languageCode).format(e.date), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(statusLabel(ctx, e.status),
                textAlign: TextAlign.center, style: TextStyle(color: statusColor(ctx, e.status), fontWeight: FontWeight.bold)),
            if (!e.createdByMe && e.counterpartName != null)
              Text('ledger.createdByOther'.tr(namedArgs: {'name': e.counterpartName!}, context: ctx), textAlign: TextAlign.center),
            if (e.description != null) ...[const SizedBox(height: 8), Text(e.description!, textAlign: TextAlign.center)],
            if (e.rejectReason != null)
              Text('ledger.rejectedBecause'.tr(namedArgs: {'reason': e.rejectReason!}, context: ctx), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (canAnswer)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final reason = await _askReason(ctx);
                        if (reason == null) return;
                        await repo.reject(e.entryId, reason);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text('ledger.reject'.tr(context: ctx)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        await repo.confirm(e.entryId);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text('ledger.confirm'.tr(context: ctx)),
                    ),
                  ),
                ],
              ),
            if (canCancel)
              TextButton(
                onPressed: () async {
                  await repo.cancel(e.entryId);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text('ledger.cancel'.tr(context: ctx), style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<String?> _askReason(BuildContext context) async {
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('ledger.reject'.tr(context: ctx)),
      content: TextField(controller: c, decoration: InputDecoration(labelText: 'ledger.rejectReason'.tr(context: ctx))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr(context: ctx))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('ledger.reject'.tr(context: ctx))),
      ],
    ),
  );
  final text = c.text;
  c.dispose();
  return ok == true ? text : null;
}
