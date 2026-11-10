import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/utils/attachments.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../accounts/presentation/account_widgets.dart';
import '../data/finishing_repository.dart';
import '../domain/finishing_rules.dart';
import 'finishing_reports.dart';

final finishingProjectsProvider = StreamProvider<List<ProjectSummary>>((ref) => ref.watch(finishingRepositoryProvider).watchProjects());
final finishingProjectProvider = StreamProvider.family<ProjectDetails?, int>(
  (ref, id) => ref.watch(finishingRepositoryProvider).watchProject(id),
);

const workStatuses = ['new', 'active', 'paused', 'completed'];

String _d(BuildContext context, DateTime d) => DateFormat.yMMMd(context.locale.languageCode).format(d);
double _egp(int p) => fromPiasters(p);

void _error(BuildContext context, Object e) {
  final code = e is FinishingRuleError ? e.code : 'generic';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('finishing.err.$code'.tr())));
}

Color _statusColor(BuildContext context, FinishingProject p) => p.closed
    ? Theme.of(context).colorScheme.onSurfaceVariant
    : switch (p.workStatus) {
        'paused' => DS.warning,
        'completed' => DS.success,
        'new' => DS.gold,
        _ => DS.teal,
      };

String _statusLabel(FinishingProject p) => p.closed ? 'finishing.closed'.tr() : 'finishing.status.${p.workStatus}'.tr();

/// One figure in a summary grid.
class _Figure extends StatelessWidget {
  const _Figure(this.label, this.piasters, {this.color, this.hint});
  final String label;
  final int piasters;
  final Color? color;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        AmountText(_egp(piasters), size: 15, color: color),
        if (hint != null) Text(hint!, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

// ============================================================ UI-01 Projects

class FinishingProjectsScreen extends ConsumerStatefulWidget {
  const FinishingProjectsScreen({super.key});

  @override
  ConsumerState<FinishingProjectsScreen> createState() => _FinishingProjectsScreenState();
}

class _FinishingProjectsScreenState extends ConsumerState<FinishingProjectsScreen> {
  String _query = '';
  String _filter = 'open'; // open | closed | all

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(finishingProjectsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('finishing.title'.tr()),
        actions: [
          IconButton(
            tooltip: 'finishing.compare.title'.tr(),
            icon: const Icon(Icons.compare_arrows_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FinishingCompareScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        shape: const StadiumBorder(),
        onPressed: () => context.push('/finishing/new'),
        icon: const Icon(Icons.add),
        label: Text('finishing.add'.tr()),
      ),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(message: 'common.loadError'.tr()),
        data: (all) {
          if (all.isEmpty) {
            return EmptyState(
              icon: Icons.home_repair_service_outlined,
              title: 'finishing.emptyTitle'.tr(),
              message: 'finishing.emptyMessage'.tr(),
              actionLabel: 'finishing.add'.tr(),
              onAction: () => context.push('/finishing/new'),
            );
          }
          final q = _query.trim().toLowerCase();
          final list = all.where((s) {
            if (_filter == 'open' && s.project.closed) return false;
            if (_filter == 'closed' && !s.project.closed) return false;
            return q.isEmpty || s.project.name.toLowerCase().contains(q) || s.project.clientName.toLowerCase().contains(q);
          }).toList();
          final open = all.where((s) => !s.project.closed);
          int sum(int Function(FinishingBalance b) f) => open.fold(0, (a, s) => a + f(s.balance));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            children: [
              AppCard(
                child: Row(
                  children: [
                    Expanded(child: _Figure('finishing.totalCost'.tr(), sum((b) => b.cost))),
                    Expanded(child: _Figure('finishing.custody'.tr(), sum((b) => b.custody), color: DS.teal)),
                    Expanded(child: _Figure('finishing.receivable'.tr(), sum((b) => b.receivable), color: DS.gold)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'finishing.search'.tr()),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final f in ['open', 'closed', 'all'])
                    ChoiceChip(
                      label: Text('finishing.filter.$f'.tr()),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('finishing.noMatch'.tr(), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                ),
              for (final s in list) _ProjectCard(s),
            ],
          );
        },
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard(this.s);
  final ProjectSummary s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = s.project;
    final b = s.balance;
    final budgetRatio = p.plannedBudget > 0 ? b.cost / p.plannedBudget : null;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => context.push('/finishing/${p.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(icon: Icons.home_work_outlined, color: _statusColor(context, p), size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: theme.textTheme.titleSmall),
                    Text(p.clientName, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              StatusPill(_statusLabel(p), color: _statusColor(context, p)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _Figure('finishing.cost'.tr(), b.cost)),
              Expanded(child: _Figure('finishing.custody'.tr(), b.custody, color: DS.teal)),
              Expanded(child: _Figure('finishing.receivable'.tr(), b.receivable, color: DS.gold)),
            ],
          ),
          if (budgetRatio != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: budgetRatio.clamp(0, 1).toDouble(),
                minHeight: 6,
                color: budgetRatio > 1 ? theme.colorScheme.error : DS.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'finishing.budgetUsed'.tr(namedArgs: {'p': '${(budgetRatio * 100).round()}', 'budget': formatAmount(_egp(p.plannedBudget))}),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================ UI-02 Create / edit project

class FinishingProjectFormScreen extends ConsumerStatefulWidget {
  const FinishingProjectFormScreen({super.key, this.id});
  final int? id;

  @override
  ConsumerState<FinishingProjectFormScreen> createState() => _FinishingProjectFormScreenState();
}

class _FinishingProjectFormScreenState extends ConsumerState<FinishingProjectFormScreen> {
  final _client = TextEditingController();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _budget = TextEditingController();
  DateTime _start = todayDateOnly();
  DateTime? _end;
  String _status = 'active';
  final Set<String> _trades = {for (final k in defaultTradeKeys) 'finishing.tradeName.$k'.tr()};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      ref.read(finishingRepositoryProvider).loadProject(widget.id!).then((d) {
        if (d == null || !mounted) return;
        final p = d.project;
        setState(() {
          _client.text = p.clientName;
          _name.text = p.name;
          _description.text = p.description ?? '';
          _location.text = p.location ?? '';
          _budget.text = p.plannedBudget > 0 ? _egp(p.plannedBudget).toStringAsFixed(2) : '';
          _start = p.startDate;
          _end = p.plannedEndDate;
          _status = p.workStatus;
        });
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_client, _name, _description, _location, _budget]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_client.text.trim().isEmpty || _name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('finishing.err.required'.tr())));
      return;
    }
    if (_end != null && _end!.isBefore(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('finishing.err.endDate'.tr())));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(finishingRepositoryProvider);
    try {
      if (widget.id == null) {
        final id = await repo.createProject(
          clientName: _client.text,
          name: _name.text,
          description: _description.text,
          location: _location.text,
          startDate: _start,
          plannedEndDate: _end,
          plannedBudget: toPiasters(parseAmount(_budget.text)),
          trades: _trades.toList(),
        );
        if (mounted) context.pushReplacement('/finishing/$id');
      } else {
        await repo.updateProject(
          widget.id!,
          clientName: _client.text,
          name: _name.text,
          description: _description.text,
          location: _location.text,
          startDate: _start,
          plannedEndDate: _end,
          plannedBudget: toPiasters(parseAmount(_budget.text)),
          workStatus: _status,
        );
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _error(context, e);
      }
    }
  }

  Future<DateTime?> _pickDate(DateTime initial) =>
      showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2000), lastDate: DateTime(2100));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = widget.id == null;
    return Scaffold(
      appBar: BrandFormAppBar(title: (isNew ? 'finishing.add' : 'finishing.edit').tr(), onSave: _saving ? null : _save),
      body: StickySaveLayout(
        button: BigSaveButton(label: 'common.save'.tr(), busy: _saving, onPressed: _save),
        children: [
          FieldLabel('finishing.client'.tr()),
          TextField(
            controller: _client,
            maxLength: 150,
            decoration: InputDecoration(hintText: 'finishing.clientHint'.tr(), counterText: ''),
          ),
          FieldLabel('finishing.projectName'.tr()),
          TextField(
            controller: _name,
            maxLength: 150,
            decoration: InputDecoration(hintText: 'finishing.projectNameHint'.tr(), counterText: ''),
          ),
          FieldRow([
            (
              'finishing.startDate'.tr(),
              PickerField(
                text: _d(context, _start),
                trailingIcon: Icons.calendar_month_outlined,
                onTap: () async {
                  final d = await _pickDate(_start);
                  if (d != null) setState(() => _start = d);
                },
              ),
            ),
            (
              'finishing.endDate'.tr(),
              PickerField(
                text: _end == null ? 'finishing.optional'.tr() : _d(context, _end!),
                placeholder: _end == null,
                trailingIcon: Icons.event_outlined,
                onTap: () async {
                  final d = await _pickDate(_end ?? _start);
                  if (d != null) setState(() => _end = d);
                },
              ),
            ),
          ]),
          FieldLabel('finishing.plannedBudget'.tr()),
          AmountField(compact: true, controller: _budget),
          if (!isNew) ...[
            FieldLabel('finishing.workStatus'.tr()),
            Wrap(
              spacing: 8,
              children: [
                for (final s in workStatuses)
                  ChoiceChip(
                    label: Text('finishing.status.$s'.tr()),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                  ),
              ],
            ),
          ],
          if (isNew) ...[
            FieldLabel('finishing.tradesStart'.tr()),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final k in defaultTradeKeys)
                  Builder(
                    builder: (_) {
                      final n = 'finishing.tradeName.$k'.tr();
                      return FilterChip(
                        label: Text(n),
                        selected: _trades.contains(n),
                        onSelected: (v) => setState(() => v ? _trades.add(n) : _trades.remove(n)),
                      );
                    },
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'finishing.tradesHint'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
          FieldLabel('finishing.location'.tr()),
          TextField(
            controller: _location,
            decoration: InputDecoration(hintText: 'finishing.optional'.tr()),
          ),
          FieldLabel('finishing.description'.tr()),
          TextField(controller: _description, minLines: 2, maxLines: 5, maxLength: 2000),
        ],
      ),
    );
  }
}

// ============================================================ UI-03 Project details

class FinishingProjectScreen extends ConsumerWidget {
  const FinishingProjectScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(finishingProjectProvider(id));
    return async.when(
      loading: () => Scaffold(appBar: AppBar(), body: const SkeletonList()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(message: 'common.loadError'.tr()),
      ),
      data: (d) => d == null
          ? Scaffold(
              appBar: AppBar(),
              body: ErrorState(message: 'common.loadError'.tr()),
            )
          : _ProjectView(d),
    );
  }
}

class _ProjectView extends ConsumerWidget {
  const _ProjectView(this.d);
  final ProjectDetails d;

  Future<void> _menu(BuildContext context, WidgetRef ref, String action) async {
    final repo = ref.read(finishingRepositoryProvider);
    final p = d.project;
    try {
      switch (action) {
        case 'edit':
          await context.push('/finishing/${p.id}/edit');
        case 'close':
          final ok = await _confirm(context, 'finishing.closeTitle'.tr(), 'finishing.closeBody'.tr());
          if (ok) await repo.close(p.id);
        case 'reopen':
          await repo.reopen(p.id);
        case 'delete':
          final ok = await _confirm(
            context,
            'finishing.deleteTitle'.tr(),
            'finishing.deleteBody'.tr(namedArgs: {'name': p.name}),
            danger: true,
          );
          if (ok) {
            final files = await repo.attachmentPaths(p.id);
            await repo.deleteProject(p.id);
            for (final f in files) {
              await deleteAttachment(f);
            }
            if (context.mounted) context.pop();
          }
      }
    } catch (e) {
      if (context.mounted) _error(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = d.project;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(p.name),
          actions: [
            IconButton(
              tooltip: 'finishing.report.title'.tr(),
              icon: const Icon(Icons.assessment_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FinishingReportScreen(id: p.id))),
            ),
            PopupMenuButton<String>(
              onSelected: (a) => _menu(context, ref, a),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text('finishing.edit'.tr())),
                if (!p.closed) PopupMenuItem(value: 'close', child: Text('finishing.closeAction'.tr())),
                if (p.closed) PopupMenuItem(value: 'reopen', child: Text('finishing.reopen'.tr())),
                PopupMenuItem(value: 'delete', child: Text('finishing.deleteTitle'.tr())),
              ],
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'finishing.tabSummary'.tr()),
              Tab(text: 'finishing.tabMoves'.tr()),
              Tab(text: 'finishing.tabTrades'.tr()),
              Tab(text: 'finishing.tabFiles'.tr()),
            ],
          ),
        ),
        body: TabBarView(children: [_SummaryTab(d), _MovesTab(d), _TradesTab(d), FinishingAttachmentsTab(d)]),
      ),
    );
  }
}

Future<bool> _confirm(BuildContext context, String title, String body, {bool danger = false}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.confirm'.tr()),
          ),
        ],
      ),
    ) ??
    false;

class _SummaryTab extends StatelessWidget {
  const _SummaryTab(this.d);
  final ProjectDetails d;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = d.project;
    final b = d.balance;
    final budget = p.plannedBudget;
    Widget action(IconData icon, String key, FinishingKind kind, {Color? color}) => Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        onTap: p.closed ? null : () => context.push('/finishing/${p.id}/event/${kind.name}'),
        child: Column(
          children: [
            Icon(icon, color: p.closed ? theme.disabledColor : (color ?? DS.primary)),
            const SizedBox(height: 4),
            Text(key.tr(), textAlign: TextAlign.center, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
    final maxTrade = d.byTrade.isEmpty ? 0 : d.byTrade.first.total;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(p.clientName, style: theme.textTheme.titleSmall)),
                  StatusPill(_statusLabel(p), color: _statusColor(context, p)),
                ],
              ),
              if ((p.location ?? '').isNotEmpty)
                Text('📍 ${p.location}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              Text(
                '${_d(context, p.startDate)}${p.plannedEndDate == null ? '' : ' → ${_d(context, p.plannedEndDate!)}'}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Figure('finishing.cost'.tr(), b.cost)),
                  Expanded(
                    child: _Figure('finishing.custody'.tr(), b.custody, color: DS.teal, hint: 'finishing.custodyHint'.tr()),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Figure('finishing.receivable'.tr(), b.receivable, color: DS.gold, hint: 'finishing.receivableHint'.tr()),
                  ),
                  Expanded(child: _Figure('finishing.allocation'.tr(), b.allocation, hint: 'finishing.allocationHint'.tr())),
                ],
              ),
              if (budget > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (b.cost / budget).clamp(0, 1).toDouble(),
                    minHeight: 8,
                    color: b.cost > budget ? theme.colorScheme.error : DS.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'finishing.budgetLeft'.tr(namedArgs: {'left': formatAmount(_egp(budget - b.cost)), 'budget': formatAmount(_egp(budget))}),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (p.closed)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: AppCard(
              color: DS.goldSoft,
              child: Text('finishing.closedNote'.tr(), style: theme.textTheme.bodyMedium?.copyWith(color: DS.text)),
            ),
          )
        else ...[
          const SizedBox(height: 12),
          Row(
            children: [
              action(Icons.shopping_cart_checkout_rounded, 'finishing.kind.cost', FinishingKind.cost, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              action(Icons.call_received_rounded, 'finishing.kind.clientAdvance', FinishingKind.clientAdvance, color: DS.teal),
              const SizedBox(width: 8),
              action(Icons.swap_horiz_rounded, 'finishing.settle', FinishingKind.reimburseFromCustody, color: DS.gold),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              action(Icons.payments_outlined, 'finishing.kind.clientRepayPersonal', FinishingKind.clientRepayPersonal),
              const SizedBox(width: 8),
              action(Icons.keyboard_return_rounded, 'finishing.kind.returnCustody', FinishingKind.returnCustody),
              const SizedBox(width: 8),
              action(Icons.savings_outlined, 'finishing.kind.personalAllocation', FinishingKind.personalAllocation),
            ],
          ),
          if (b.canClose && (b.cost > 0))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'finishing.readyToClose'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(color: DS.success, fontWeight: FontWeight.w600),
              ),
            ),
        ],
        SectionHeader('finishing.costByTrade'.tr()),
        AppCard(
          child: d.byTrade.every((t) => t.total == 0)
              ? Text('finishing.noCosts'.tr(), style: theme.textTheme.bodySmall)
              : Column(
                  children: [
                    for (final t in d.byTrade.where((t) => t.total > 0))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(t.trade.name, style: theme.textTheme.bodyMedium)),
                                AmountText(_egp(t.total), size: 13),
                              ],
                            ),
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: maxTrade == 0 ? 0 : t.total / maxTrade,
                                minHeight: 5,
                                color: DS.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        SectionHeader('finishing.costByType'.tr()),
        AppCard(
          child: Row(
            children: [for (final t in CostType.values) Expanded(child: _Figure('finishing.costType.${t.name}'.tr(), d.byType[t] ?? 0))],
          ),
        ),
        SectionHeader('finishing.custodyStatement'.tr()),
        AppCard(
          child: Row(
            children: [
              Expanded(child: _Figure('finishing.custodyIn'.tr(), d.custodyIn, color: DS.teal)),
              Expanded(child: _Figure('finishing.custodyUsed'.tr(), d.custodyIn - d.custodyOut - b.custody)),
              Expanded(child: _Figure('finishing.custodyReturned'.tr(), d.custodyOut)),
            ],
          ),
        ),
        if ((p.description ?? '').isNotEmpty) ...[SectionHeader('finishing.description'.tr()), AppCard(child: Text(p.description!))],
      ],
    );
  }
}

IconData _kindIcon(FinishingKind k) => switch (k) {
  FinishingKind.cost => Icons.shopping_cart_checkout_rounded,
  FinishingKind.clientAdvance => Icons.call_received_rounded,
  FinishingKind.reimburseFromCustody => Icons.swap_horiz_rounded,
  FinishingKind.clientRepayPersonal => Icons.payments_outlined,
  FinishingKind.returnCustody => Icons.keyboard_return_rounded,
  FinishingKind.personalAllocation => Icons.savings_outlined,
  FinishingKind.reversal => Icons.undo_rounded,
};

class _MovesTab extends ConsumerWidget {
  const _MovesTab(this.d);
  final ProjectDetails d;

  Future<void> _reverse(BuildContext context, WidgetRef ref, FinishingEventView e) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('finishing.reverseTitle'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('finishing.reverseBody'.tr()),
            const SizedBox(height: 8),
            TextField(
              controller: reason,
              decoration: InputDecoration(hintText: 'finishing.reverseReason'.tr()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('finishing.reverse'.tr())),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(finishingRepositoryProvider).reverse(e.event.id, reason: reason.text);
    } catch (err) {
      if (context.mounted) _error(context, err);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (d.events.isEmpty) {
      return EmptyState(icon: Icons.receipt_long_outlined, title: 'finishing.noMoves'.tr(), message: 'finishing.noMovesHint'.tr());
    }
    final byId = {for (final e in d.events) e.event.id: e};
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: d.events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final e = d.events[i];
        final ev = e.event;
        final k = e.kind;
        final muted = e.reversed || k == FinishingKind.reversal;
        final original = ev.reversesId == null ? null : byId[ev.reversesId];
        final lines = <String>[
          _d(context, ev.date),
          if (e.tradeName != null) e.tradeName!,
          if (ev.costType != null) 'finishing.costType.${ev.costType}'.tr(),
          if (k == FinishingKind.cost && ev.custodyShare > 0 && ev.personalShare > 0)
            'finishing.splitLine'.tr(namedArgs: {'c': formatAmount(_egp(ev.custodyShare)), 'p': formatAmount(_egp(ev.personalShare))})
          else if (k == FinishingKind.cost)
            (ev.custodyShare > 0 ? 'finishing.fromCustody' : 'finishing.fromPocket').tr(),
          if (d.attachments.any((a) => a.eventId == ev.id)) '📎 ${d.attachments.where((a) => a.eventId == ev.id).length}',
          if (original != null) 'finishing.reversesLine'.tr(namedArgs: {'kind': 'finishing.kind.${original.event.kind}'.tr()}),
          for (final l in e.legs) '${l.accountName} ${l.amount > 0 ? '+' : '−'}${formatAmount(_egp(l.amount.abs()))}',
        ];
        return AppCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBubble(icon: _kindIcon(k), color: muted ? theme.disabledColor : DS.primary, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ['finishing.kind.${k.name}'.tr(), if ((ev.description ?? '').isNotEmpty) ev.description!].join(' · '),
                      style: theme.textTheme.titleSmall?.copyWith(decoration: e.reversed ? TextDecoration.lineThrough : null),
                    ),
                    if ((ev.beneficiary ?? '').isNotEmpty) Text('👤 ${ev.beneficiary}', style: theme.textTheme.bodySmall),
                    Text(lines.join(' · '), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    if (e.reversed)
                      Text('finishing.reversedTag'.tr(), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText(_egp(ev.amount), size: 14, color: muted ? theme.disabledColor : null),
                  if (!muted && !d.project.closed)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'finishing.reverse'.tr(),
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      onPressed: () => _reverse(context, ref, e),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TradesTab extends ConsumerWidget {
  const _TradesTab(this.d);
  final ProjectDetails d;

  Future<void> _edit(BuildContext context, WidgetRef ref, {FinishingTrade? trade}) async {
    final c = TextEditingController(text: trade?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text((trade == null ? 'finishing.addTrade' : 'finishing.renameTrade').tr()),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 100,
          decoration: InputDecoration(hintText: 'finishing.tradeHint'.tr()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text('common.save'.tr())),
        ],
      ),
    );
    if (name == null) return;
    final repo = ref.read(finishingRepositoryProvider);
    try {
      if (trade == null) {
        await repo.addTrade(d.project.id, name);
      } else {
        await repo.renameTrade(trade, name);
      }
    } catch (e) {
      if (context.mounted) _error(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final costs = {for (final t in d.byTrade) t.trade.id: t};
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        for (final t in d.trades)
          AppCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            onTap: () => _edit(context, ref, trade: t),
            child: Row(
              children: [
                const Icon(Icons.handyman_outlined, size: 20, color: DS.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name, style: theme.textTheme.titleSmall),
                      Text(
                        'finishing.tradeCount'.tr(namedArgs: {'n': '${costs[t.id]?.count ?? 0}'}),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                AmountText(_egp(costs[t.id]?.total ?? 0), size: 13),
                if ((costs[t.id]?.count ?? 0) == 0)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () async {
                      try {
                        await ref.read(finishingRepositoryProvider).deleteTrade(t.id);
                      } catch (e) {
                        if (context.mounted) _error(context, e);
                      }
                    },
                  ),
              ],
            ),
          ),
        OutlinedButton.icon(onPressed: () => _edit(context, ref), icon: const Icon(Icons.add), label: Text('finishing.addTrade'.tr())),
      ],
    );
  }
}

// ============================================================ UI-05..08 Event forms

/// Cost entry (with funding split), client advance, allocation and the settlements.
class FinishingEventFormScreen extends ConsumerStatefulWidget {
  const FinishingEventFormScreen({super.key, required this.projectId, required this.kind});
  final int projectId;
  final FinishingKind kind;

  @override
  ConsumerState<FinishingEventFormScreen> createState() => _FinishingEventFormScreenState();
}

enum _Funding { custody, pocket, mixed }

class _FinishingEventFormScreenState extends ConsumerState<FinishingEventFormScreen> {
  late FinishingKind _kind = widget.kind;
  final _eventId = newFinishingEventId(); // stable across retries of this form
  final _amount = TextEditingController();
  final _custodyPart = TextEditingController();
  final _description = TextEditingController();
  final _beneficiary = TextEditingController();
  DateTime _date = todayDateOnly();
  int? _tradeId;
  CostType _costType = CostType.materials;
  _Funding? _funding;
  int? _accountId;
  int? _personalAccountId;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_amount, _custodyPart, _description, _beneficiary]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _amountP => toPiasters(parseAmount(_amount.text));

  /// Custody / personal shares of a cost.
  (int, int) _shares(FinishingBalance b) {
    final total = _amountP;
    final funding = _funding ?? (b.custody >= total && total > 0 ? _Funding.custody : (b.custody == 0 ? _Funding.pocket : _Funding.mixed));
    return switch (funding) {
      _Funding.custody => (total, 0),
      _Funding.pocket => (0, total),
      _Funding.mixed => () {
        final typed = _custodyPart.text.trim().isEmpty
            ? (b.custody < total ? b.custody : total)
            : toPiasters(parseAmount(_custodyPart.text));
        final c = typed.clamp(0, total);
        return (c, total - c);
      }(),
    };
  }

  _Funding _effectiveFunding(FinishingBalance b) {
    final total = _amountP;
    return _funding ?? (b.custody >= total && total > 0 ? _Funding.custody : (b.custody == 0 ? _Funding.pocket : _Funding.mixed));
  }

  bool get _needsAccount => switch (_kind) {
    FinishingKind.clientAdvance || FinishingKind.clientRepayPersonal || FinishingKind.returnCustody || FinishingKind.cost => true,
    _ => false,
  };

  Future<void> _save(ProjectDetails d, List<AccountWithBalance> accounts) async {
    if (_saving) return;
    final defaultAccount = accounts.isEmpty ? null : accounts.first.account.id;
    final (custodyShare, personalShare) = _kind == FinishingKind.cost ? _shares(d.balance) : (0, 0);
    setState(() => _saving = true);
    try {
      await ref
          .read(finishingRepositoryProvider)
          .record(
            eventId: _eventId,
            projectId: widget.projectId,
            kind: _kind,
            amount: _amountP,
            custodyShare: custodyShare,
            personalShare: personalShare,
            tradeId: _tradeId ?? (d.trades.isEmpty ? null : d.trades.first.id),
            costType: _costType,
            description: _description.text,
            beneficiary: _beneficiary.text,
            date: _date,
            accountId: _needsAccount ? (_accountId ?? defaultAccount) : null,
            personalAccountId: _personalAccountId ?? _accountId ?? defaultAccount,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('finishing.saved'.tr())));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _error(context, e);
      }
    }
  }

  Widget _accountPicker(List<AccountWithBalance> accounts, int? id, ValueChanged<int> onPicked) {
    AccountWithBalance? a;
    for (final x in accounts) {
      if (x.account.id == id) a = x;
    }
    a ??= accounts.isEmpty ? null : accounts.first;
    return PickerField(
      text: a?.account.name ?? 'accounts.choose'.tr(),
      placeholder: a == null,
      subtitle: a == null ? null : 'transactions.currentBalance'.tr(namedArgs: {'amount': formatAmount(a.balance)}),
      trailingIcon: Icons.chevron_left,
      leading: a == null ? null : AccountBubble(a, size: 28),
      onTap: () async {
        final picked = await showAccountPicker(context, selectedId: a?.account.id);
        if (picked != null) onPicked(picked);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(finishingProjectProvider(widget.projectId));
    final accounts = ref.watch(accountsProvider).value ?? const <AccountWithBalance>[];
    final d = async.value;
    if (d == null) return Scaffold(appBar: AppBar(), body: const SkeletonList());
    final theme = Theme.of(context);
    final b = d.balance;
    final isSettle =
        _kind == FinishingKind.reimburseFromCustody || _kind == FinishingKind.clientRepayPersonal || _kind == FinishingKind.returnCustody;
    final funding = _effectiveFunding(b);
    final (cShare, pShare) = _kind == FinishingKind.cost ? _shares(b) : (0, 0);
    final limit = switch (_kind) {
      FinishingKind.reimburseFromCustody => b.custody < b.receivable ? b.custody : b.receivable,
      FinishingKind.clientRepayPersonal => b.receivable,
      FinishingKind.returnCustody => b.custody,
      _ => null,
    };
    final trades = d.trades;
    final tradeId = _tradeId ?? (trades.isEmpty ? null : trades.first.id);
    return Scaffold(
      appBar: BrandFormAppBar(title: 'finishing.kind.${_kind.name}'.tr(), onSave: _saving ? null : () => _save(d, accounts)),
      body: StickySaveLayout(
        button: BigSaveButton(label: 'common.save'.tr(), busy: _saving, onPressed: () => _save(d, accounts)),
        children: [
          Text(
            '${d.project.name} · ${d.project.clientName}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (isSettle) ...[
            FieldLabel('finishing.settleType'.tr()),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final k in [FinishingKind.reimburseFromCustody, FinishingKind.clientRepayPersonal, FinishingKind.returnCustody])
                  ChoiceChip(
                    label: Text('finishing.kind.${k.name}'.tr()),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('finishing.explain.${_kind.name}'.tr(), style: theme.textTheme.bodySmall),
            ),
          ] else
            Text('finishing.explain.${_kind.name}'.tr(), style: theme.textTheme.bodySmall),
          FieldLabel('transactions.amount'.tr()),
          AmountField(controller: _amount, autofocus: true, onChanged: (_) => setState(() {})),
          if (limit != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'finishing.maxAllowed'.tr(namedArgs: {'amount': formatAmount(_egp(limit))}),
                      style: theme.textTheme.bodySmall?.copyWith(color: _amountP > limit ? theme.colorScheme.error : null),
                    ),
                  ),
                  if (limit > 0)
                    TextButton(
                      onPressed: () => setState(() => _amount.text = _egp(limit).toStringAsFixed(2)),
                      child: Text('finishing.useAll'.tr()),
                    ),
                ],
              ),
            ),
          if (_kind == FinishingKind.cost) ...[
            FieldLabel('finishing.trade'.tr()),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in trades)
                  ChoiceChip(label: Text(t.name), selected: tradeId == t.id, onSelected: (_) => setState(() => _tradeId = t.id)),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text('finishing.addTrade'.tr()),
                  onPressed: () async {
                    final c = TextEditingController();
                    final name = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('finishing.addTrade'.tr()),
                        content: TextField(
                          controller: c,
                          autofocus: true,
                          decoration: InputDecoration(hintText: 'finishing.tradeHint'.tr()),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
                          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text('common.save'.tr())),
                        ],
                      ),
                    );
                    if (name == null) return;
                    try {
                      final id = await ref.read(finishingRepositoryProvider).addTrade(widget.projectId, name);
                      setState(() => _tradeId = id);
                    } catch (e) {
                      if (context.mounted) _error(context, e);
                    }
                  },
                ),
              ],
            ),
            FieldLabel('finishing.costTypeLabel'.tr()),
            Wrap(
              spacing: 8,
              children: [
                for (final t in CostType.values)
                  ChoiceChip(
                    label: Text('finishing.costType.${t.name}'.tr()),
                    selected: _costType == t,
                    onSelected: (_) => setState(() => _costType = t),
                  ),
              ],
            ),
            FieldLabel('finishing.costDescription'.tr()),
            TextField(
              controller: _description,
              decoration: InputDecoration(hintText: 'finishing.costDescriptionHint'.tr()),
            ),
            FieldLabel('finishing.fundingLabel'.tr()),
            Text(
              'finishing.custodyAvailable'.tr(namedArgs: {'amount': formatAmount(_egp(b.custody))}),
              style: theme.textTheme.bodySmall?.copyWith(color: DS.teal),
            ),
            const SizedBox(height: 6),
            SegmentedButton<_Funding>(
              segments: [
                ButtonSegment(value: _Funding.custody, label: Text('finishing.fund.custody'.tr())),
                ButtonSegment(value: _Funding.pocket, label: Text('finishing.fund.pocket'.tr())),
                ButtonSegment(value: _Funding.mixed, label: Text('finishing.fund.mixed'.tr())),
              ],
              selected: {funding},
              onSelectionChanged: (s) => setState(() => _funding = s.first),
            ),
            if (funding == _Funding.mixed) ...[
              FieldLabel('finishing.custodyPart'.tr()),
              AmountField(compact: true, controller: _custodyPart, onChanged: (_) => setState(() {})),
            ],
            if (_amountP > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AppCard(
                  color: DS.goldSoft,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'finishing.splitPreview'.tr(namedArgs: {'c': formatAmount(_egp(cShare)), 'p': formatAmount(_egp(pShare))}),
                    style: theme.textTheme.bodyMedium?.copyWith(color: cShare > b.custody ? theme.colorScheme.error : DS.text),
                  ),
                ),
              ),
            if (cShare > 0) ...[
              FieldLabel('finishing.custodyAccount'.tr()),
              _accountPicker(accounts, _accountId, (id) => setState(() => _accountId = id)),
            ],
            if (pShare > 0) ...[
              FieldLabel('finishing.personalAccount'.tr()),
              _accountPicker(accounts, _personalAccountId ?? _accountId, (id) => setState(() => _personalAccountId = id)),
            ],
          ] else if (_needsAccount) ...[
            FieldLabel((_kind == FinishingKind.returnCustody ? 'finishing.accountOut' : 'finishing.accountIn').tr()),
            _accountPicker(accounts, _accountId, (id) => setState(() => _accountId = id)),
          ],
          FieldLabel('transactions.date'.tr()),
          PickerField(
            text: _d(context, _date),
            trailingIcon: Icons.calendar_month_outlined,
            onTap: () async {
              final x = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (x != null) setState(() => _date = x);
            },
          ),
          if (_kind == FinishingKind.cost) ...[
            FieldLabel('finishing.beneficiary'.tr()),
            TextField(
              controller: _beneficiary,
              decoration: InputDecoration(hintText: 'finishing.beneficiaryHint'.tr()),
            ),
          ] else ...[
            FieldLabel('transactions.notes'.tr()),
            TextField(controller: _description, minLines: 1, maxLines: 3),
          ],
        ],
      ),
    );
  }
}
