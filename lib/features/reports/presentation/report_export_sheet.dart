import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/tables.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../data/report_export.dart';
import '../../../core/utils/file_share.dart';

enum _Period { month, last3, year, custom }

/// Export the report as PDF or Excel and hand it to the share sheet (WhatsApp, Gmail, ...).
Future<void> showReportExportSheet(BuildContext context, DateTime month) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ExportSheet(month: month),
);

class _ExportSheet extends ConsumerStatefulWidget {
  const _ExportSheet({required this.month});
  final DateTime month;

  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  _Period _period = _Period.month;
  DateTimeRange? _custom;
  bool _busy = false;

  (DateTime, DateTime) get _range {
    final now = DateTime.now();
    return switch (_period) {
      _Period.month => getMonthRange(widget.month),
      _Period.last3 => (DateTime(now.year, now.month - 2, 1), DateTime(now.year, now.month + 1, 0)),
      _Period.year => (DateTime(now.year, 1, 1), DateTime(now.year, 12, 31)),
      _Period.custom => _custom == null ? getMonthRange(widget.month) : (_custom!.start, _custom!.end),
    };
  }

  ReportLabels _labels(BuildContext context, (DateTime, DateTime) range) {
    final lang = context.locale.languageCode;
    final fmt = DateFormat.yMMMd(lang);
    final userName = ref.read(settingsProvider).userName;
    return ReportLabels(
      isRtl: lang == 'ar',
      locale: lang,
      title: 'export.reportTitle'.tr(),
      period: 'export.periodLine'.tr(namedArgs: {'from': fmt.format(range.$1), 'to': fmt.format(range.$2)}),
      preparedFor: 'export.preparedFor'.tr(namedArgs: {'name': userName}),
      generatedAt: 'export.generatedAt'.tr(namedArgs: {'date': DateFormat.yMMMd(lang).add_Hm().format(DateTime.now())}),
      summary: 'export.summary'.tr(),
      income: 'dashboard.income'.tr(),
      expense: 'dashboard.expenses'.tr(),
      net: 'export.net'.tr(),
      byCategory: 'reports.byCategory'.tr(),
      share: 'export.share'.tr(),
      transactions: 'export.transactions'.tr(),
      date: 'transactions.date'.tr(),
      type: 'transactions.type'.tr(),
      mainCategory: 'export.mainCategory'.tr(),
      subCategory: 'export.subCategory'.tr(),
      beneficiary: 'transactions.beneficiary'.tr(),
      account: 'transactions.account'.tr(),
      amount: 'transactions.amount'.tr(),
      note: 'transactions.notes'.tr(),
      total: 'export.total'.tr(),
      currency: 'common.egp'.tr(),
      typeNames: {
        TransactionType.expense: 'transactions.expense'.tr(),
        TransactionType.income: 'transactions.income'.tr(),
        TransactionType.transfer: 'export.transfer'.tr(),
        TransactionType.trustIn: 'transactions.trustIn'.tr(),
        TransactionType.trustOut: 'transactions.trustOut'.tr(),
      },
    );
  }

  Future<void> _export({required bool pdf}) async {
    final range = _range;
    final labels = _labels(context, range);
    setState(() => _busy = true);
    try {
      final list = await ref.read(transactionRepositoryProvider).watchList(TransactionFilters(from: range.$1, to: range.$2)).first;
      final data = ReportData(from: range.$1, to: range.$2, userName: ref.read(settingsProvider).userName, transactions: list);
      final bytes = pdf ? await buildReportPdf(data, labels) : buildReportXlsx(data, labels);
      final stamp = DateFormat('yyyyMMdd', 'en');
      final name = 'Masarefy_${stamp.format(range.$1)}-${stamp.format(range.$2)}.${pdf ? 'pdf' : 'xlsx'}';
      if (!mounted) return;
      await shareFile(
        context,
        bytes: bytes,
        name: name,
        mimeType: pdf ? pdfMime : xlsxMime,
        subject: '${labels.title} – ${labels.period}',
        text: '${labels.title} – ${labels.period}',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('export.failed'.tr())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = _range;
    final fmt = DateFormat.yMMMd(context.locale.languageCode);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('export.title'.tr(), style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final pr in _Period.values)
                  ChoiceChip(
                    label: Text('export.period.${pr.name}'.tr()),
                    selected: _period == pr,
                    onSelected: (_) async {
                      if (pr == _Period.custom) {
                        final r = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          initialDateRange: _custom,
                        );
                        if (r == null) return;
                        _custom = r;
                      }
                      setState(() => _period = pr);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${fmt.format(range.$1)} – ${fmt.format(range.$2)}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            if (_busy)
              const Center(
                child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _export(pdf: true),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: DS.gold, foregroundColor: DS.navy),
                      onPressed: () => _export(pdf: false),
                      icon: const Icon(Icons.table_chart_outlined),
                      label: const Text('Excel'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Text(
              'export.shareHint'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
