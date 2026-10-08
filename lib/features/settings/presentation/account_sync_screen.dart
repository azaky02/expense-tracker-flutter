import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_api.dart';
import '../../../core/sync/sync_controller.dart';

class AccountSyncScreen extends ConsumerStatefulWidget {
  const AccountSyncScreen({super.key});

  @override
  ConsumerState<AccountSyncScreen> createState() => _AccountSyncScreenState();
}

class _AccountSyncScreenState extends ConsumerState<AccountSyncScreen> {
  final _server = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_server, _email, _password, _name, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  String _message(BuildContext context, String code) {
    final key = 'sync.errors.$code';
    return key.trExists(context: context) ? key.tr(context: context) : 'sync.errors.unexpected'.tr(context: context);
  }

  Future<void> _submit() async {
    final ctx = context;
    if (_server.text.trim().isEmpty) {
      setState(() => _error = _message(ctx, 'invalid_url'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(syncControllerProvider.notifier).signIn(
            serverUrl: _server.text,
            email: _email.text,
            password: _password.text,
            register: _register,
            name: _name.text,
            signupCode: _code.text,
          );
      _password.clear();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _message(context, e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('sync.signOutTitle'.tr(context: ctx)),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text('sync.signOutBody'.tr(context: ctx)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'keep'),
            child: Text('sync.signOutKeep'.tr(context: ctx)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'wipe'),
            child: Text('sync.signOutWipe'.tr(context: ctx), style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr(context: ctx)),
          ),
        ],
      ),
    );
    if (choice == null) return;
    await ref.read(syncControllerProvider.notifier).signOut(wipe: choice == 'wipe');
  }

  Future<void> _confirmDelete() async {
    final pw = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('sync.deleteTitle'.tr(context: ctx)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('sync.deleteBody'.tr(context: ctx)),
          const SizedBox(height: 12),
          TextField(
            controller: pw,
            obscureText: true,
            decoration: InputDecoration(labelText: 'sync.password'.tr(context: ctx)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr(context: ctx))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('common.delete'.tr(context: ctx))),
        ],
      ),
    );
    final password = pw.text;
    pw.dispose();
    if (ok != true) return;
    try {
      await ref.read(syncControllerProvider.notifier).deleteAccount(password);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _message(context, e.code == 'http_403' ? 'invalid_credentials' : e.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('sync.title'.tr(context: context))),
      body: !sync.loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: sync.signedIn ? _signedIn(context, sync, theme) : _signedOut(context, sync, theme),
            ),
    );
  }

  List<Widget> _signedOut(BuildContext context, SyncState sync, ThemeData theme) {
    final expired = sync.errorCode == 'session_expired';
    final insecure = _server.text.trim().toLowerCase().startsWith('http://');
    return [
      Text('sync.intro'.tr(context: context), style: theme.textTheme.bodyMedium),
      const SizedBox(height: 16),
      TextField(
        controller: _server,
        keyboardType: TextInputType.url,
        textDirection: ui.TextDirection.ltr,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: 'sync.serverUrl'.tr(context: context), hintText: 'sync.serverHint'.tr(context: context)),
      ),
      if (insecure)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('sync.insecure'.tr(context: context), style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
        ),
      const SizedBox(height: 12),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        textDirection: ui.TextDirection.ltr,
        autofillHints: const [AutofillHints.email],
        decoration: InputDecoration(labelText: 'sync.email'.tr(context: context)),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _password,
        obscureText: true,
        autofillHints: const [AutofillHints.password],
        decoration: InputDecoration(labelText: 'sync.password'.tr(context: context)),
      ),
      if (_register) ...[
        const SizedBox(height: 12),
        TextField(controller: _name, decoration: InputDecoration(labelText: 'sync.name'.tr(context: context))),
        const SizedBox(height: 12),
        TextField(controller: _code, decoration: InputDecoration(labelText: 'sync.signupCode'.tr(context: context))),
      ],
      if (_error != null || expired)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_error ?? _message(context, 'session_expired'), style: TextStyle(color: theme.colorScheme.error)),
        ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text((_register ? 'sync.register' : 'sync.signIn').tr(context: context)),
      ),
      TextButton(
        onPressed: _busy ? null : () => setState(() => _register = !_register),
        child: Text((_register ? 'sync.haveAccount' : 'sync.noAccount').tr(context: context)),
      ),
    ];
  }

  List<Widget> _signedIn(BuildContext context, SyncState sync, ThemeData theme) {
    final session = sync.session!;
    final syncing = sync.status == SyncStatus.syncing;
    final last = sync.lastSyncAt;
    final skipped = sync.lastReport?.skipped ?? 0;
    return [
      Card(
        child: ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text('sync.signedInAs'.tr(namedArgs: {'email': session.email}, context: context)),
          subtitle: Text(session.serverUrl, textDirection: ui.TextDirection.ltr),
        ),
      ),
      const SizedBox(height: 8),
      ListTile(
        leading: syncing
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(sync.status == SyncStatus.error ? Icons.cloud_off : Icons.cloud_done_outlined,
                color: sync.status == SyncStatus.error ? theme.colorScheme.error : null),
        title: Text(syncing
            ? 'sync.syncing'.tr(context: context)
            : sync.status == SyncStatus.error
                ? _message(context, sync.errorCode ?? 'unexpected')
                : 'sync.synced'.tr(context: context)),
        subtitle: Text(last == null
            ? 'sync.neverSynced'.tr(context: context)
            : 'sync.lastSync'.tr(namedArgs: {'time': DateFormat.yMd().add_Hm().format(last)}, context: context)),
      ),
      if (skipped > 0)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('sync.skipped'.tr(namedArgs: {'count': '$skipped'}, context: context), style: theme.textTheme.bodySmall),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: syncing ? null : () => ref.read(syncControllerProvider.notifier).syncNow(),
        icon: const Icon(Icons.sync),
        label: Text('sync.syncNow'.tr(context: context)),
      ),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: _confirmSignOut, child: Text('sync.signOut'.tr(context: context))),
      TextButton(
        onPressed: _confirmDelete,
        child: Text('sync.deleteAccount'.tr(context: context), style: TextStyle(color: theme.colorScheme.error)),
      ),
    ];
  }
}
