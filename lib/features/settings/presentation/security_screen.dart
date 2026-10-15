import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/security/lock_provider.dart';
import '../../../core/security/secure_storage.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../auth/presentation/setup_screen.dart' show recoveryQuestions;
import '../../lock/presentation/pin_entry_screen.dart';

final _biometricsAvailableProvider = FutureProvider<bool>((ref) async {
  final auth = LocalAuthentication();
  try {
    return await auth.isDeviceSupported() && await auth.canCheckBiometrics;
  } catch (_) {
    return false;
  }
});

/// App lock (UI/UX AUTH-05, §17 "Security"): 4-digit PIN (stored as a PBKDF2 hash in the OS
/// keystore), optional fingerprint / Face ID, change PIN, turn off. The app locks every time it
/// goes to the background.
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  final _store = SecureStorageService.instance;

  Future<String?> _ask(String title, {String? error}) => askPin(context, title: title, error: error);

  /// Asks for a new PIN twice. Returns it, or null if cancelled.
  Future<String?> _newPin() async {
    String? error;
    while (true) {
      final first = await askPin(context, title: 'security.setupPin'.tr(), subtitle: 'security.setupPinHint'.tr(), error: error);
      if (first == null || !mounted) return null;
      final second = await _ask('security.confirmPin'.tr());
      if (second == null || !mounted) return null;
      if (first == second) return first;
      error = 'security.pinMismatch'.tr();
    }
  }

  /// Verifies the current PIN (three tries), or Face ID / fingerprint when no PIN was set.
  Future<bool> _checkPin() async {
    if (!await _store.hasPinSet()) {
      try {
        return await LockNotifier.runWithoutLock(() => LocalAuthentication().authenticate(localizedReason: 'security.unlockPrompt'.tr()));
      } catch (_) {
        return false;
      }
    }
    String? error;
    for (var i = 0; i < 3; i++) {
      final pin = await _ask('security.enterCurrentPin'.tr(), error: error);
      if (pin == null || !mounted) return false;
      if (await _store.verifyPin(pin)) return true;
      error = 'security.wrongPin'.tr();
    }
    return false;
  }

  void _toast(String key) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(key.tr())));
  }

  Future<void> _enable() async {
    final pin = await _newPin();
    if (pin == null) return;
    await _store.setPin(pin);
    ref.read(lockProvider.notifier).unlock(); // don't lock the user out right after setting it
    await ref.read(settingsProvider.notifier).setAppLockEnabled(true);
    _toast('security.pinSetSuccess');
  }

  Future<void> _disable() async {
    if (!await _checkPin()) return;
    await ref.read(settingsProvider.notifier).setAppLockEnabled(false);
    await ref.read(settingsProvider.notifier).setBiometricEnabled(false);
    await _store.clearPin();
    _toast('security.lockDisabled');
  }

  String? _question;
  bool _questionLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadQuestion();
  }

  Future<void> _loadQuestion() async {
    String? q;
    try {
      q = await _store.recoveryQuestion();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _question = q;
        _questionLoaded = true;
      });
    }
  }

  /// Set or change the security question used to recover a forgotten PIN.
  Future<void> _editQuestion() async {
    if (_question != null && !await _checkPin()) return;
    if (!mounted) return;
    var key = recoveryQuestions.first;
    final custom = TextEditingController();
    final answer = TextEditingController();
    String? error;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('wizard.recoveryTitle'.tr(), style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('wizard.recoveryHint'.tr(), style: Theme.of(ctx).textTheme.bodySmall),
              FieldLabel('wizard.question'.tr()),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: key,
                items: [for (final q in recoveryQuestions) DropdownMenuItem(value: q, child: Text(q.tr(), overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setSheet(() => key = v ?? key),
              ),
              if (key == 'wizard.q.custom') ...[
                FieldLabel('wizard.customQuestion'.tr()),
                TextField(controller: custom),
              ],
              FieldLabel('wizard.answer'.tr()),
              TextField(controller: answer, decoration: InputDecoration(hintText: 'recover.answerHint'.tr())),
              if (error != null)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final q = key == 'wizard.q.custom' ? custom.text.trim() : key.tr();
                  if (q.isEmpty || answer.text.trim().length < 2) {
                    setSheet(() => error = 'wizard.needAnswer'.tr());
                    return;
                  }
                  await _store.setRecovery(q, answer.text);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                child: Text('common.save'.tr()),
              ),
            ]),
          ),
        ),
      ),
    );
    custom.dispose();
    answer.dispose();
    if (saved == true) {
      await _loadQuestion();
      _toast('security.questionSaved');
    }
  }

  Future<void> _change() async {
    if (!await _checkPin()) return;
    final pin = await _newPin();
    if (pin == null) return;
    await _store.setPin(pin);
    _toast('security.pinChanged');
  }

  Future<void> _toggleBiometrics(bool on) async {
    if (!on) {
      // Biometrics-only lock: a PIN has to replace it before it can be turned off.
      if (!await _store.hasPinSet()) {
        final pin = await _newPin();
        if (pin == null) return;
        await _store.setPin(pin);
      }
      await ref.read(settingsProvider.notifier).setBiometricEnabled(false);
      return;
    }
    try {
      final ok = await LockNotifier.runWithoutLock(
        () => LocalAuthentication().authenticate(localizedReason: 'security.enableBiometrics'.tr()),
      );
      if (ok) await ref.read(settingsProvider.notifier).setBiometricEnabled(true);
    } catch (_) {
      _toast('security.biometricsFailed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final biometrics = ref.watch(_biometricsAvailableProvider).value ?? false;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('settings.appLock'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(
              children: [
                IconBubble(icon: Icons.verified_user_outlined, color: theme.colorScheme.primary, size: 48),
                const SizedBox(width: 12),
                Expanded(child: Text('security.intro'.tr(), style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  value: settings.appLockEnabled,
                  onChanged: (v) => v ? _enable() : _disable(),
                  title: Text('security.enableAppLock'.tr()),
                  subtitle: Text('security.lockOnLeave'.tr()),
                ),
                if (settings.appLockEnabled) ...[
                  const Divider(height: 1),
                  ListTile(leading: const Icon(Icons.password), title: Text('security.changePin'.tr()), onTap: _change),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: Text('security.lockAfter'.tr()),
                    subtitle: Text('security.lockAfterHint'.tr()),
                    trailing: DropdownButton<int>(
                      value: settings.lockAfterMinutes,
                      underline: const SizedBox(),
                      items: [
                        for (final m in const [0, 1, 5, 15, 30])
                          DropdownMenuItem(
                            value: m,
                            child: Text(m == 0 ? 'security.lockNow'.tr() : 'security.lockMinutes'.tr(namedArgs: {'n': '$m'})),
                          ),
                      ],
                      onChanged: (v) => ref.read(settingsProvider.notifier).setLockAfterMinutes(v ?? 5),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: Text('wizard.recoveryTitle'.tr()),
                    subtitle: Text(
                      !_questionLoaded ? '' : (_question ?? 'security.noQuestion'.tr()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text((_question == null ? 'security.setQuestion' : 'security.changeQuestion').tr(),
                        style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    onTap: _editQuestion,
                  ),
                  if (biometrics) ...[
                    const Divider(height: 1),
                    SwitchListTile(
                      value: settings.biometricEnabled,
                      onChanged: _toggleBiometrics,
                      secondary: const Icon(Icons.fingerprint),
                      title: Text('security.enableBiometrics'.tr()),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (settings.appLockEnabled)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'security.forgotPinNote'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}
