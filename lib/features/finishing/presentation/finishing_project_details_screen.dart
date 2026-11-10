import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sync/sync_api.dart';
import '../../../core/sync/sync_controller.dart';

class FinishingProjectDetailsScreen extends ConsumerStatefulWidget {
  const FinishingProjectDetailsScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<FinishingProjectDetailsScreen> createState() => _FinishingProjectDetailsScreenState();
}

class _FinishingProjectDetailsScreenState extends ConsumerState<FinishingProjectDetailsScreen> {
  Map<String, dynamic>? _project;
  bool _loading = true;
  bool _notFound = false;
  String? _error;

  bool get _arabic => Localizations.localeOf(context).languageCode == 'ar';
  String label(String ar, String en) => _arabic ? ar : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = ref.read(syncControllerProvider).session;
    if (session == null) {
      if (mounted) setState(() { _loading = false; _error = 'signin'; });
      return;
    }
    setState(() { _loading = true; _error = null; _notFound = false; });
    final api = SyncApi(
      session.serverUrl,
      session: session,
      onSessionChanged: (updated) { updated.save(); },
    );
    try {
      final project = await api.getFinishingProject(widget.projectId);
      if (mounted) setState(() { _project = project; _notFound = project == null; });
    } catch (_) {
      if (mounted) setState(() => _error = 'load');
    } finally {
      api.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  String _amount(Object? value) {
    final piasters = int.tryParse(value?.toString() ?? '');
    return piasters == null ? '—' : '${(piasters / 100).toStringAsFixed(2)} EGP';
  }

  Widget _balanceCard(String title, Object? amount, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Icon(icon, size: 28),
        const SizedBox(width: 12),
        Expanded(child: Text(title)),
        Text(_amount(amount), style: Theme.of(context).textTheme.titleMedium),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final project = _project;
    return Scaffold(
      appBar: AppBar(
        title: Text(label('تفاصيل المشروع', 'Project details')),
        actions: [IconButton(
          onPressed: _loading ? null : _load,
          tooltip: label('تحديث', 'Refresh'),
          icon: const Icon(Icons.refresh),
        )],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || _notFound
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_notFound ? Icons.search_off : Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  Text(_notFound
                      ? label('المشروع غير موجود', 'Project not found')
                      : _error == 'signin'
                          ? label('سجل الدخول أولاً', 'Sign in first')
                          : label('تعذر تحميل المشروع', 'Unable to load project')),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _error == 'signin' ? () => context.push('/account') : _load,
                    child: Text(_error == 'signin' ? label('تسجيل الدخول', 'Sign in') : label('إعادة المحاولة', 'Retry')),
                  ),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(project?['project_name']?.toString() ?? '', style: Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 8),
                            Text('${label('العميل', 'Client')}: ${project?['client_name'] ?? ''}'),
                            const SizedBox(height: 8),
                            Chip(label: Text(project?['financial_status'] == 'closed'
                                ? label('مغلق ماليًا', 'Financially closed')
                                : label('مفتوح', 'Open'))),
                            if ((project?['description']?.toString() ?? '').isNotEmpty) ...[
                              const Divider(),
                              Text(project!['description'].toString()),
                            ],
                          ]),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(label('الملخص المالي', 'Financial summary'), style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      _balanceCard(label('إجمالي التكاليف', 'Total costs'), project?['cost_piasters'], Icons.receipt_long_outlined),
                      _balanceCard(label('رصيد عهدة العميل', 'Client custody'), project?['custody_piasters'], Icons.account_balance_wallet_outlined),
                      _balanceCard(label('مستحقات شخصية', 'Personal receivable'), project?['receivable_piasters'], Icons.payments_outlined),
                      const SizedBox(height: 20),
                      Text(label('بنود وأعمال التشطيب', 'Trades and work items'), style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Card(child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(children: [
                          const Icon(Icons.construction_outlined, size: 36),
                          const SizedBox(height: 8),
                          Text(label('إدارة البنود والمقايسات في المرحلة التالية', 'Trades and estimates will be added next')),
                        ]),
                      )),
                    ],
                  ),
                ),
    );
  }
}
