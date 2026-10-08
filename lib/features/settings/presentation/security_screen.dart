import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/security/lock_provider.dart';
import '../../../core/security/secure_storage.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../core/widgets/ds_widgets.dart';
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

  /// Verifies the current PIN (three tries).
  Future<bool> _checkPin() async {
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

  Future<void> _change() async {
    if (!await _checkPin()) return;
    final pin = await _newPin();
    if (pin == null) return;
    await _store.setPin(pin);
    _toast('security.pinChanged');
  }

  Future<void> _toggleBiometrics(bool on) async {
    if (!on) {
      await ref.read(settingsProvider.notifier).setBiometricEnabled(false);
      return;
    }
    try {
      final ok = await LockNotifier.runWithoutLock(
          () => LocalAuthentication().authenticate(localizedReason: 'security.enableBiometrics'.tr()));
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
            child: Row(children: [
              IconBubble(icon: Icons.verified_user_outlined, color: theme.colorScheme.primary, size: 48),
              const SizedBox(width: 12),
              Expanded(child: Text('security.intro'.tr(), style: theme.textTheme.bodyMedium)),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              SwitchListTile(
                value: settings.appLockEnabled,
                onChanged: (v) => v ? _enable() : _disable(),
                title: Text('security.enableAppLock'.tr()),
                subtitle: Text('security.lockOnLeave'.tr()),
              ),
              if (settings.appLockEnabled) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.password),
                  title: Text('security.changePin'.tr()),
                  onTap: _change,
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
            ]),
          ),
          if (settings.appLockEnabled)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('security.forgotPinNote'.tr(), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}
