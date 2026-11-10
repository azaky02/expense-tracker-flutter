import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../../core/db/database.dart';
import '../../../core/security/lock_provider.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/utils/attachments.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/file_share.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../data/finishing_export.dart';
import '../data/finishing_repository.dart';
import '../domain/finishing_rules.dart';
import 'finishing_screens.dart';

double _egp(int p) => fromPiasters(p);
String _d(BuildContext context, DateTime d) => DateFormat.yMMMd(context.locale.languageCode).format(d);
String _tr(String key, {Map<String, String>? args}) => key.tr(namedArgs: args);
String _safe(String s) => s.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');

Future<void> exportProject(BuildContext context, ProjectDetails d, {required bool pdf}) async {
  final lang = context.locale.languageCode;
  try {
    final bytes = pdf ? await buildProjectPdf(d, _tr, lang) : buildProjectXlsx(d, _tr, lang);
    if (!context.mounted) return;
    final stamp = DateFormat('yyyyMMdd', 'en').format(DateTime.now());
    await shareFile(
      context,
      bytes: bytes,
      name: 'Masarefy_${_safe(d.project.name)}_$stamp.${pdf ? 'pdf' : 'xlsx'}',
      mimeType: pdf ? pdfMime : xlsxMime,
      subject: '${'finishing.report.title'.tr()} – ${d.project.name}',
    );
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('export.failed'.tr())));
  }
}

// ============================================================ UI-11 Project report

class FinishingReportScreen extends ConsumerWidget {
  const FinishingReportScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(finishingProjectProvider(id)).value;
    final theme = Theme.of(context);
    if (d == null) return Scaffold(appBar: AppBar(), body: const SkeletonList());
    final b = d.balance;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    Widget row(String label, Widget value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: bold ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)),
          value,
        ],
      ),
    );
    Widget signed(int v) => v == 0
        ? Text('—', style: muted)
        : Text(
            '${v > 0 ? '+' : '−'}${formatAmount(_egp(v.abs()))}',
            textDirection: ui.TextDirection.ltr,
            style: theme.textTheme.bodySmall?.copyWith(color: v > 0 ? DS.success : theme.colorScheme.error, fontWeight: FontWeight.w600),
          );
    final spent = d.statement.where((l) => l.kind == FinishingKind.cost).fold(0, (s, l) => s + l.event.custodyShare);
    final reimb = d.statement.where((l) => l.kind == FinishingKind.reimburseFromCustody).fold(0, (s, l) => s + l.event.amount);
    final repaid = d.statement.where((l) => l.kind == FinishingKind.clientRepayPersonal).fold(0, (s, l) => s + l.event.amount);
    return Scaffold(
      appBar: AppBar(title: Text('finishing.report.title'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('${d.project.name} · ${d.project.clientName}', style: muted),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => exportProject(context, d, pdf: true),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: DS.gold, foregroundColor: DS.navy),
                  onPressed: () => exportProject(context, d, pdf: false),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Excel'),
                ),
              ),
            ],
          ),
          SectionHeader('finishing.report.closure'.tr()),
          AppCard(
            child: Column(
              children: [
                row('finishing.custodyIn'.tr(), AmountText(_egp(d.custodyIn), size: 13)),
                row('finishing.report.custodySpent'.tr(), AmountText(_egp(spent), size: 13)),
                row('finishing.kind.reimburseFromCustody'.tr(), AmountText(_egp(reimb), size: 13)),
                row('finishing.custodyReturned'.tr(), AmountText(_egp(d.custodyOut), size: 13)),
                row('finishing.report.custodyLeft'.tr(), AmountText(_egp(b.custody), size: 14, color: DS.teal), bold: true),
                const Divider(),
                row('finishing.report.personalPaid'.tr(), AmountText(_egp(d.personalPaid), size: 13)),
                row('finishing.kind.reimburseFromCustody'.tr(), AmountText(_egp(reimb), size: 13)),
                row('finishing.kind.clientRepayPersonal'.tr(), AmountText(_egp(repaid), size: 13)),
                row('finishing.report.receivableLeft'.tr(), AmountText(_egp(b.receivable), size: 14, color: DS.gold), bold: true),
                const SizedBox(height: 6),
                Text(
                  (b.canClose ? 'finishing.report.closureOk' : 'finishing.report.closureOpen').tr(),
                  style: theme.textTheme.bodySmall?.copyWith(color: b.canClose ? DS.success : DS.warning, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          SectionHeader('finishing.report.statement'.tr()),
          if (d.statement.every((l) => l.custodyDelta == 0 && l.receivableDelta == 0))
            AppCard(child: Text('finishing.noMoves'.tr(), style: muted))
          else
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final l in d.statement)
                    if (l.custodyDelta != 0 || l.receivableDelta != 0)
                      ListTile(
                        dense: true,
                        title: Text(
                          [
                            'finishing.kind.${l.event.kind}'.tr(),
                            if ((l.event.description ?? '').isNotEmpty) l.event.description!,
                          ].join(' · '),
                        ),
                        subtitle: Text(_d(context, l.event.date)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${'finishing.custody'.tr()} ', style: muted),
                                signed(l.custodyDelta),
                                Text('  = ${formatAmount(_egp(l.custodyAfter))}', textDirection: ui.TextDirection.ltr, style: muted),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${'finishing.receivable'.tr()} ', style: muted),
                                signed(l.receivableDelta),
                                Text('  = ${formatAmount(_egp(l.receivableAfter))}', textDirection: ui.TextDirection.ltr, style: muted),
                              ],
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          SectionHeader('finishing.report.accounts'.tr()),
          AppCard(
            child: d.accounts.isEmpty
                ? Text('finishing.report.noAccounts'.tr(), style: muted)
                : Column(
                    children: [
                      for (final a in d.accounts)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(child: Text(a.accountName, style: theme.textTheme.titleSmall)),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${'finishing.report.in'.tr()}: ${formatAmount(_egp(a.moneyIn))}', style: muted),
                                  Text('${'finishing.report.out'.tr()}: ${formatAmount(_egp(a.moneyOut))}', style: muted),
                                  signed(a.net),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          SectionHeader('finishing.costByType'.tr()),
          AppCard(
            child: Column(
              children: [
                for (final c in CostType.values)
                  row(
                    'finishing.costType.${c.name}'.tr(),
                    Text(
                      b.cost == 0 ? '—' : '${formatAmount(_egp(d.byType[c] ?? 0))}  (${((d.byType[c] ?? 0) * 100 / b.cost).round()}%)',
                      textDirection: ui.TextDirection.ltr,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================ Project comparison

class FinishingCompareScreen extends ConsumerStatefulWidget {
  const FinishingCompareScreen({super.key});

  @override
  ConsumerState<FinishingCompareScreen> createState() => _FinishingCompareScreenState();
}

class _FinishingCompareScreenState extends ConsumerState<FinishingCompareScreen> {
  Map<int, ProjectDetails> _details = {};

  Future<void> _load(List<ProjectSummary> list) async {
    final repo = ref.read(finishingRepositoryProvider);
    final out = <int, ProjectDetails>{};
    for (final s in list) {
      final d = await repo.loadProject(s.project.id);
      if (d != null) out[s.project.id] = d;
    }
    if (mounted) setState(() => _details = out);
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(finishingProjectsProvider).value ?? const <ProjectSummary>[];
    if (list.isNotEmpty && _details.length != list.length) _load(list);
    final theme = Theme.of(context);
    final maxCost = list.fold<int>(0, (m, s) => s.balance.cost > m ? s.balance.cost : m);
    return Scaffold(
      appBar: AppBar(
        title: Text('finishing.compare.title'.tr()),
        actions: [
          if (list.isNotEmpty)
            IconButton(
              tooltip: 'Excel',
              icon: const Icon(Icons.table_chart_outlined),
              onPressed: () async {
                final lang = context.locale.languageCode;
                final bytes = buildComparisonXlsx(list, _details, _tr, lang);
                await shareFile(
                  context,
                  bytes: bytes,
                  name: 'Masarefy_projects_${DateFormat('yyyyMMdd', 'en').format(DateTime.now())}.xlsx',
                  mimeType: xlsxMime,
                );
              },
            ),
        ],
      ),
      body: list.isEmpty
          ? EmptyState(icon: Icons.compare_arrows_rounded, title: 'finishing.emptyTitle'.tr(), message: 'finishing.emptyMessage'.tr())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                for (final s in list)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(s.project.name, style: theme.textTheme.titleSmall)),
                            AmountText(_egp(s.balance.cost), size: 14),
                          ],
                        ),
                        Text(s.project.clientName, style: theme.textTheme.bodySmall),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Row(
                            children: [
                              for (final (c, color) in [
                                (CostType.materials, DS.primary),
                                (CostType.labor, DS.gold),
                                (CostType.other, DS.textMuted),
                              ])
                                Expanded(
                                  flex: maxCost == 0 ? 1 : ((_details[s.project.id]?.byType[c] ?? 0) * 1000 ~/ maxCost),
                                  child: Container(height: 8, color: color),
                                ),
                              Expanded(
                                flex: maxCost == 0 ? 0 : ((maxCost - s.balance.cost) * 1000 ~/ maxCost),
                                child: Container(height: 8, color: theme.colorScheme.surfaceContainerHighest),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          children: [
                            for (final c in CostType.values)
                              Text(
                                '${'finishing.costType.${c.name}'.tr()}: ${formatAmount(_egp(_details[s.project.id]?.byType[c] ?? 0))}',
                                style: theme.textTheme.labelSmall,
                              ),
                            if (s.project.plannedBudget > 0)
                              Text(
                                '${'finishing.plannedBudget'.tr()}: ${formatAmount(_egp(s.project.plannedBudget))}',
                                style: theme.textTheme.labelSmall,
                              ),
                            Text(
                              '${'finishing.custody'.tr()}: ${formatAmount(_egp(s.balance.custody))}',
                              style: theme.textTheme.labelSmall,
                            ),
                            Text(
                              '${'finishing.receivable'.tr()}: ${formatAmount(_egp(s.balance.receivable))}',
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ============================================================ UI-10 Attachments

class FinishingAttachmentsTab extends ConsumerWidget {
  const FinishingAttachmentsTab(this.d, {super.key});
  final ProjectDetails d;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text('finishing.att.camera'.tr()),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('finishing.att.gallery'.tr()),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: Text('finishing.att.file'.tr()),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    String? path;
    String? name;
    if (source == 'file') {
      final r = await LockNotifier.runWithoutLock(
        () => FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'xlsx', 'docx']),
      );
      path = r?.path;
      name = r?.name;
    } else {
      final x = await LockNotifier.runWithoutLock(
        () => ImagePicker().pickImage(source: source == 'camera' ? ImageSource.camera : ImageSource.gallery, imageQuality: 75),
      );
      path = x?.path;
      name = x?.name;
    }
    if (path == null || !context.mounted) return;

    // Optional: tie it to a movement, plus a short note.
    final note = TextEditingController();
    int? eventId;
    final movements = [
      for (final e in d.events)
        if (!e.reversed && e.kind != FinishingKind.reversal) e,
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('finishing.att.add'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: eventId,
                decoration: InputDecoration(labelText: 'finishing.att.linkTo'.tr()),
                items: [
                  DropdownMenuItem(value: null, child: Text('finishing.att.wholeProject'.tr())),
                  for (final e in movements)
                    DropdownMenuItem(
                      value: e.event.id,
                      child: Text(
                        '${'finishing.kind.${e.event.kind}'.tr()} · ${formatAmount(_egp(e.event.amount))}${(e.event.description ?? '').isEmpty ? '' : ' · ${e.event.description}'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => set(() => eventId = v),
              ),
              TextField(
                controller: note,
                decoration: InputDecoration(labelText: 'finishing.att.note'.tr()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('common.save'.tr())),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final stored = await persistAttachment(path);
    final ext = p.extension(stored).toLowerCase();
    final type = ['.jpg', '.jpeg', '.png', '.heic', '.webp'].contains(ext) ? 'image' : (ext == '.pdf' ? 'pdf' : 'file');
    await ref
        .read(finishingRepositoryProvider)
        .addAttachment(
          projectId: d.project.id,
          eventId: eventId,
          path: stored,
          name: name ?? p.basename(stored),
          type: type,
          note: note.text,
        );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, FinishingAttachment a) async {
    final file = File(a.path);
    if (!await file.exists()) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('finishing.att.missing'.tr())));
      return;
    }
    if (!context.mounted) return;
    if (a.type == 'image') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(a.note ?? a.name)),
            backgroundColor: Colors.black,
            body: Center(child: InteractiveViewer(maxScale: 5, child: Image.file(file))),
          ),
        ),
      );
    } else {
      final bytes = await file.readAsBytes();
      if (!context.mounted) return;
      await shareFile(context, bytes: bytes, name: a.name, mimeType: a.type == 'pdf' ? pdfMime : 'application/octet-stream');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (kIsWeb) {
      return EmptyState(icon: Icons.attach_file_rounded, title: 'finishing.att.title'.tr(), message: 'finishing.att.webHint'.tr());
    }
    final byEvent = {for (final e in d.events) e.event.id: e};
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (d.attachments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('finishing.att.empty'.tr(), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          ),
        for (final a in d.attachments)
          AppCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            onTap: () => _open(context, ref, a),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: a.type == 'image'
                      ? Image.file(
                          File(a.path),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(width: 56, height: 56, child: Icon(Icons.broken_image_outlined)),
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: DS.primary.withValues(alpha: 0.1),
                          child: Icon(
                            a.type == 'pdf' ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined,
                            color: DS.primary,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.note ?? a.name, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        [
                          _d(context, a.createdAt),
                          if (a.eventId != null && byEvent[a.eventId] != null) 'finishing.kind.${byEvent[a.eventId]!.event.kind}'.tr(),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('finishing.att.delete'.tr()),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('common.delete'.tr())),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    await ref.read(finishingRepositoryProvider).removeAttachment(a.id);
                    await deleteAttachment(a.path);
                  },
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _add(context, ref),
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text('finishing.att.add'.tr()),
        ),
      ],
    );
  }
}
