import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/security/lock_provider.dart';
import '../../../core/security/secure_storage.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/widgets/ds_widgets.dart';
import 'pin_entry_screen.dart';

/// Forgot the PIN: prove it is you with the phone's own lock (fingerprint / face / phone passcode)
/// or, if that is not available, with the security question; then choose a new PIN.
class RecoverPinScreen extends ConsumerStatefulWidget {
  const RecoverPinScreen({super.key});

  @override
  ConsumerState<RecoverPinScreen> createState() => _RecoverPinScreenState();
}

class _RecoverPinScreenState extends ConsumerState<RecoverPinScreen> {
  final _answer = TextEditingController();
  final _store = SecureStorageService.instance;
  String? _question;
  bool _showQuestion = false;
  String? _error;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _store
        .recoveryQuestion()
        .then((q) {
          if (mounted) setState(() => _question = q);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _deviceLock() async {
    setState(() => _error = null);
    var ok = false;
    try {
      final auth = LocalAuthentication();
      if (await auth.isDeviceSupported()) {
        ok = await LockNotifier.runWithoutLock(() => auth.authenticate(localizedReason: 'recover.deviceReason'.tr()));
      }
    } catch (_) {
      ok = false;
    }
    if (ok) {
      await _newPin();
    } else if (mounted) {
      setState(() {
        _showQuestion = true;
        _error = 'recover.deviceFailed'.tr();
      });
    }
  }

  Future<void> _checkAnswer() async {
    if (_attempts >= 5) return;
    if (await _store.verifyRecoveryAnswer(_answer.text)) {
      await _newPin();
    } else if (mounted) {
      setState(() {
        _attempts++;
        _error = _attempts >= 5 ? 'recover.tooMany'.tr() : 'recover.wrongAnswer'.tr();
      });
    }
  }

  Future<void> _newPin() async {
    String? error;
    while (mounted) {
      final first = await askPin(context, title: 'security.setupPin'.tr(), subtitle: 'security.setupPinHint'.tr(), error: error);
      if (first == null || !mounted) return;
      final second = await askPin(context, title: 'security.confirmPin'.tr());
      if (second == null || !mounted) return;
      if (first == second) {
        await _store.setPin(first);
        ref.read(lockProvider.notifier).unlock();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('security.pinChanged'.tr())));
        }
        return;
      }
      error = 'security.pinMismatch'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = ref.watch(settingsProvider).userEmail;
    return Scaffold(
      appBar: BrandFormAppBar(title: 'recover.title'.tr(), actions: const [SizedBox(width: 40)]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const IconBubble(icon: Icons.phonelink_lock, color: DS.primary, size: 44),
                    const SizedBox(width: 12),
                    Expanded(child: Text('recover.deviceHint'.tr(), style: theme.textTheme.bodyMedium)),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: _deviceLock, icon: const Icon(Icons.fingerprint), label: Text('recover.useDevice'.tr())),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_question != null)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () => setState(() => _showQuestion = !_showQuestion),
                    child: Row(
                      children: [
                        const IconBubble(icon: Icons.help_outline, color: DS.gold, size: 44),
                        const SizedBox(width: 12),
                        Expanded(child: Text('recover.useQuestion'.tr(), style: theme.textTheme.titleSmall)),
                        Icon(_showQuestion ? Icons.expand_less : Icons.expand_more),
                      ],
                    ),
                  ),
                  if (_showQuestion) ...[
                    const SizedBox(height: 12),
                    Text(_question!, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _answer,
                      enabled: _attempts < 5,
                      decoration: InputDecoration(hintText: 'recover.answerHint'.tr()),
                      onSubmitted: (_) => _checkAnswer(),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(onPressed: _attempts >= 5 ? null : _checkAnswer, child: Text('recover.check'.tr())),
                  ],
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          const SizedBox(height: 10),
          AppCard(
            child: Row(
              children: [
                const IconBubble(icon: Icons.mail_outline, color: Colors.grey, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    email.isEmpty ? 'recover.emailNone'.tr() : 'recover.emailSoon'.tr(namedArgs: {'email': _mask(email)}),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _mask(String email) {
    final at = email.indexOf('@');
    if (at < 2) return email;
    return '${email.substring(0, 2)}***${email.substring(at)}';
  }
}
