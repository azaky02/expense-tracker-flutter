import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/security/lock_provider.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../data/backup_service.dart';

/// Backup & restore (UI/UX §17, P0): an encrypted file the user keeps (Drive, WhatsApp, e-mail…)
/// and can restore on this or a new phone.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  BackupService get _service => BackupService(ref.read(databaseProvider));

  void _toast(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<String?> _askPassword({required bool confirm}) async {
    final a = TextEditingController();
    final b = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text((confirm ? 'backup.choosePassword' : 'backup.enterPassword').tr()),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (confirm) Text('backup.passwordHint'.tr(), style: Theme.of(ctx).textTheme.bodySmall),
            TextField(controller: a, obscureText: true, autofocus: true, decoration: InputDecoration(labelText: 'sync.password'.tr())),
            if (confirm) TextField(controller: b, obscureText: true, decoration: InputDecoration(labelText: 'backup.confirmPassword'.tr())),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
              onPressed: () {
                if (a.text.length < 6) return setD(() => error = 'backup.passwordTooShort'.tr());
                if (confirm && a.text != b.text) return setD(() => error = 'security.pinMismatch'.tr());
                Navigator.pop(ctx, a.text);
              },
              child: Text('common.ok'.tr()),
            ),
          ],
        ),
      ),
    );
    a.dispose();
    b.dispose();
    return result;
  }

  Future<void> _export() async {
    final password = await _askPassword(confirm: true);
    if (password == null) return;
    setState(() => _busy = true);
    try {
      final content = await _service.export(password);
      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final file = File(p.join(dir.path, 'Masarefy_backup_$stamp.masarefy'));
      await file.writeAsString(content);
      await LockNotifier.runWithoutLock(
          () => SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Masarefy backup $stamp')));
    } catch (e) {
      _toast('backup.exportFailed'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final picked = await LockNotifier.runWithoutLock(() => FilePicker.pickFile());
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final password = await _askPassword(confirm: false);
    if (password == null) return;
    setState(() => _busy = true);
    try {
      final contents = await _service.open(utf8.decode(bytes), password);
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('backup.importWarningTitle'.tr()),
          content: Text('backup.restoreSummary'.tr(namedArgs: {
            'date': contents.createdAt == null ? '—' : DateFormat.yMMMd(context.locale.languageCode).add_Hm().format(contents.createdAt!),
            'transactions': '${contents.count('transactions')}',
            'people': '${contents.count('people')}',
          })),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(96, 44), backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('backup.import'.tr()),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await _service.restore(contents);
      _toast('backup.importSuccess'.tr());
    } on BackupException catch (e) {
      _toast('backup.error.${e.code}'.tr());
    } catch (_) {
      _toast('backup.error.not_a_backup'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('settings.backup'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconBubble(icon: Icons.backup_outlined, color: theme.colorScheme.primary, size: 48),
              const SizedBox(width: 12),
              Expanded(child: Text('backup.description'.tr())),
            ]),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.upload_file),
            label: Text('backup.export'.tr()),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.restore),
            label: Text('backup.import'.tr()),
          ),
          if (_busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          const SizedBox(height: 16),
          Text('backup.notes'.tr(), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
