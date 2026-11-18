import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../data/email_backup.dart';

/// Daily backup to e-mail: where to send it, the Brevo key, the backup password.
class EmailBackupScreen extends ConsumerStatefulWidget {
  const EmailBackupScreen({super.key});

  @override
  ConsumerState<EmailBackupScreen> createState() => _EmailBackupScreenState();
}

class _EmailBackupScreenState extends ConsumerState<EmailBackupScreen> {
  final _to = TextEditingController();
  final _from = TextEditingController();
  final _key = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  EmailBackupConfig _cfg = const EmailBackupConfig();
  bool _enabled = false;
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final c = await EmailBackupStore.load();
    if (!mounted) return;
    setState(() {
      _cfg = c;
      if (!_loaded) {
        _enabled = c.enabled;
        _to.text = c.to;
        _from.text = c.from;
        _loaded = true;
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_to, _from, _key, _password, _password2]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String key, [Map<String, String>? args]) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('emailBackup.$key'.tr(namedArgs: args))));

  bool _validate() {
    if (!_to.text.contains('@') || !_from.text.contains('@')) {
      _snack('errEmail');
      return false;
    }
    if (_key.text.trim().isEmpty && !_cfg.hasKey) {
      _snack('errKey');
      return false;
    }
    if (_password.text.isNotEmpty || !_cfg.hasPassword) {
      if (_password.text.length < 6) {
        _snack('errPassword');
        return false;
      }
      if (_password.text != _password2.text) {
        _snack('errPasswordMatch');
        return false;
      }
    }
    return true;
  }

  Future<void> _save() async {
    if (_enabled && !_validate()) return;
    await EmailBackupStore.save(enabled: _enabled, to: _to.text, from: _from.text, apiKey: _key.text, password: _password.text);
    _key.clear();
    _password.clear();
    _password2.clear();
    await _reload();
    if (mounted) _snack('saved');
  }

  Future<void> _sendNow() async {
    if (!_validate()) return;
    setState(() => _busy = true);
    await EmailBackupStore.save(enabled: _enabled, to: _to.text, from: _from.text, apiKey: _key.text, password: _password.text);
    _key.clear();
    _password.clear();
    _password2.clear();
    final err = await sendEmailBackup(ref.read(databaseProvider), force: true);
    await _reload();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      _snack('sent', {'to': _to.text});
    } else {
      _snack('failed', {'reason': _reason(err)});
    }
  }

  String _reason(String err) => switch (err) {
    'http_401' => 'emailBackup.reason401'.tr(),
    'http_400' => 'emailBackup.reason400'.tr(),
    'network' => 'emailBackup.reasonNetwork'.tr(),
    'notReady' => 'emailBackup.reasonNotReady'.tr(),
    _ => err,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final last = _cfg.lastSent;
    return Scaffold(
      appBar: BrandFormAppBar(title: 'emailBackup.title'.tr(), onSave: _busy ? null : _save),
      body: StickySaveLayout(
        button: BigSaveButton(label: 'common.save'.tr(), busy: false, onPressed: _save),
        children: [
          AppCard(
            color: DS.goldSoft,
            padding: const EdgeInsets.all(12),
            child: Text('emailBackup.how'.tr(), style: theme.textTheme.bodySmall?.copyWith(color: DS.text)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            title: Text('emailBackup.enable'.tr()),
          ),
          FieldLabel('emailBackup.to'.tr()),
          TextField(controller: _to, keyboardType: TextInputType.emailAddress, textDirection: ui.TextDirection.ltr),
          FieldLabel('emailBackup.from'.tr()),
          TextField(
            controller: _from,
            keyboardType: TextInputType.emailAddress,
            textDirection: ui.TextDirection.ltr,
            decoration: InputDecoration(helperText: 'emailBackup.fromHint'.tr(), helperMaxLines: 3),
          ),
          FieldLabel('emailBackup.key'.tr()),
          TextField(
            controller: _key,
            obscureText: true,
            textDirection: ui.TextDirection.ltr,
            decoration: InputDecoration(hintText: _cfg.hasKey ? 'emailBackup.keySaved'.tr() : 'xkeysib-…'),
          ),
          FieldLabel('emailBackup.password'.tr()),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(hintText: _cfg.hasPassword ? 'emailBackup.passwordSaved'.tr() : null),
          ),
          FieldLabel('emailBackup.password2'.tr()),
          TextField(controller: _password2, obscureText: true),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('emailBackup.passwordHint'.tr(), style: muted),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _busy ? null : _sendNow,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_outlined),
            label: Text('emailBackup.sendNow'.tr()),
          ),
          const SizedBox(height: 10),
          Text(
            last == null
                ? 'emailBackup.never'.tr()
                : 'emailBackup.last'.tr(namedArgs: {'date': DateFormat.yMMMd(context.locale.languageCode).add_Hm().format(last)}),
            style: muted,
          ),
          if (_cfg.lastError != null)
            Text(
              'emailBackup.lastFailed'.tr(namedArgs: {'reason': _reason(_cfg.lastError!)}),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          if (_cfg.hasKey || _cfg.hasPassword)
            TextButton(
              onPressed: () async {
                await EmailBackupStore.clearSecrets();
                setState(() => _enabled = false);
                await _reload();
              },
              child: Text('emailBackup.clear'.tr()),
            ),
        ],
      ),
    );
  }
}
