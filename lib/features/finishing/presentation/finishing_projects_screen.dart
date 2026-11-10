import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sync/sync_api.dart';
import '../../../core/sync/sync_controller.dart';

bool _ar(BuildContext context) => Localizations.localeOf(context).languageCode == 'ar';
String _t(BuildContext context, String ar, String en) => _ar(context) ? ar : en;
String _money(Object? raw) {
  final piasters = int.tryParse(raw?.toString() ?? '') ?? 0;
  return '${(piasters / 100).toStringAsFixed(2)} EGP';
}

SyncApi _api(SyncSession session) => SyncApi(
  session.serverUrl,
  onSessionChanged: (updated) { updated.save(); },
  // Use the current authenticated session, never a new anonymous client.
  session: session,
);

class FinishingProjectsScreen extends ConsumerStatefulWidget {
  const FinishingProjectsScreen({super.key});
  @override
  ConsumerState<FinishingProjectsScreen> createState() => _FinishingProjectsScreenState();
}

class _FinishingProjectsScreenState extends ConsumerState<FinishingProjectsScreen> {
  List<Map<String, dynamic>>? _projects;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = ref.read(syncControllerProvider).session;
    if (session == null) return;
    setState(() { _loading = true; _error = null; });
    final api = _api(session);
    try {
      final items = await api.listFinishingProjects();
      if (mounted) setState(() => _projects = items);
    } catch (_) {
      if (mounted) setState(() => _error = 'load');
    } finally {
      api.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(syncControllerProvider).session;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_t(context, 'مشروعات التشطيبات', 'Finishing projects')),
        actions: [IconButton(tooltip: _t(context, 'تحديث', 'Refresh'), onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: session == null ? null : FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push<bool>('/finishing/new');
          if (created == true && mounted) _load();
        },
        icon: const Icon(Icons.add),
        label: Text(_t(context, 'مشروع جديد', 'New project')),
      ),
      body: session == null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(_t(context, 'سجل الدخول لمزامنة المشروعات', 'Sign in to access projects')),
              TextButton(onPressed: () => context.push('/account'), child: Text(_t(context, 'تسجيل الدخول', 'Sign in'))),
            ]))
          : _loading && _projects == null
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_t(context, 'تعذر تحميل المشروعات', 'Could not load projects')),
                      TextButton(onPressed: _load, child: Text(_t(context, 'إعادة المحاولة', 'Retry'))),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        children: [
                          Card(
                            color: theme.colorScheme.primaryContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(_t(context, 'إدارة المشروعات', 'Project overview'), style: theme.textTheme.titleLarge),
                                const SizedBox(height: 8),
                                Text('${_projects?.length ?? 0} ${_t(context, 'مشروع', 'projects')}',
                                    style: theme.textTheme.headlineMedium),
                              ]),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_projects?.isEmpty ?? true)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 56),
                              child: Column(children: [
                                const Icon(Icons.home_work_outlined, size: 56),
                                const SizedBox(height: 12),
                                Text(_t(context, 'لا توجد مشروعات بعد', 'No projects yet')),
                                Text(_t(context, 'ابدأ بإضافة مشروع جديد', 'Create your first project')),
                              ]),
                            ),
                          for (final project in _projects ?? <Map<String, dynamic>>[]) ...[
                            Card(
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => context.push('/finishing/${Uri.encodeComponent(project['project_id'].toString())}'),
                                child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    const Icon(Icons.apartment_outlined),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(project['project_name']?.toString() ?? '',
                                        style: theme.textTheme.titleMedium)),
                                    Chip(label: Text(project['financial_status'] == 'closed'
                                        ? _t(context, 'مغلق', 'Closed') : _t(context, 'مفتوح', 'Open'))),
                                  ]),
                                  Text(project['client_name']?.toString() ?? '', style: theme.textTheme.bodyMedium),
                                  const Divider(height: 24),
                                  Wrap(spacing: 20, runSpacing: 12, children: [
                                    _Metric(_t(context, 'إجمالي التكاليف', 'Total cost'), _money(project['cost_piasters'])),
                                    _Metric(_t(context, 'العهدة', 'Custody'), _money(project['custody_piasters'])),
                                    _Metric(_t(context, 'مستحقات شخصية', 'Receivable'), _money(project['receivable_piasters'])),
                                  ]),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: Theme.of(context).textTheme.labelSmall),
    Text(value, style: Theme.of(context).textTheme.titleSmall),
  ]);
}

class FinishingNewProjectScreen extends ConsumerStatefulWidget {
  const FinishingNewProjectScreen({super.key});
  @override
  ConsumerState<FinishingNewProjectScreen> createState() => _FinishingNewProjectScreenState();
}

class _FinishingNewProjectScreenState extends ConsumerState<FinishingNewProjectScreen> {
  final _form = GlobalKey<FormState>();
  final _client = TextEditingController();
  final _project = TextEditingController();
  final _description = TextEditingController();
  late final String _projectId = _newId();
  bool _saving = false;
  String? _error;

  static String _newId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return 'p_${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  @override
  void dispose() {
    _client.dispose();
    _project.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final session = ref.read(syncControllerProvider).session;
    if (session == null) {
      setState(() => _error = _t(context, 'يجب تسجيل الدخول أولاً', 'Sign in first'));
      return;
    }
    setState(() { _saving = true; _error = null; });
    final api = _api(session);
    try {
      await api.createFinishingProject(
        projectId: _projectId,
        clientName: _client.text,
        projectName: _project.text,
        description: _description.text,
      );
      if (mounted) context.pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = _t(context,
          'تعذر الحفظ. يمكنك إعادة المحاولة دون تكرار المشروع.',
          'Could not save. Retry safely with the same project ID.'));
    } finally {
      api.close();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_t(context, 'مشروع تشطيبات جديد', 'New finishing project'))),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Icon(Icons.add_home_work_outlined, size: 56),
          const SizedBox(height: 16),
          Text(_t(context, 'بيانات المشروع', 'Project information'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          TextFormField(
            controller: _client, maxLength: 150,
            decoration: InputDecoration(labelText: _t(context, 'اسم العميل *', 'Client name *'), border: const OutlineInputBorder()),
            validator: (value) => value == null || value.trim().isEmpty ? _t(context, 'مطلوب', 'Required') : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _project, maxLength: 150,
            decoration: InputDecoration(labelText: _t(context, 'اسم المشروع *', 'Project name *'), border: const OutlineInputBorder()),
            validator: (value) => value == null || value.trim().isEmpty ? _t(context, 'مطلوب', 'Required') : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description, maxLength: 2000, maxLines: 3,
            decoration: InputDecoration(labelText: _t(context, 'الوصف (اختياري)', 'Description (optional)'), border: const OutlineInputBorder()),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
            label: Text(_t(context, 'حفظ المشروع', 'Save project')),
          ),
        ]),
      ),
    )),
  );
}
