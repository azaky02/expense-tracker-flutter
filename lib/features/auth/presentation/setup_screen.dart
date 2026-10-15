import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/db/database.dart' show unreadableDbRecoveredKey;

import '../../../core/security/lock_provider.dart';
import '../../../core/security/secure_storage.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../lock/presentation/pin_entry_screen.dart';
import 'auth_screens.dart';
import '../../../core/utils/currency.dart';

enum SetupLock { pin, biometrics }

final biometricsAvailableProvider = FutureProvider<bool>((ref) async {
  final auth = LocalAuthentication();
  try {
    return await auth.isDeviceSupported() && await auth.canCheckBiometrics;
  } catch (_) {
    return false;
  }
});

/// Egyptian mobile (01xxxxxxxxx) or an international number (+ and 8-15 digits).
bool isValidPhone(String raw) {
  final s = raw.replaceAll(RegExp(r'[\s\-()]'), '');
  return RegExp(r'^01[0125]\d{8}$').hasMatch(s) || RegExp(r'^\+?\d{8,15}$').hasMatch(s);
}

/// On-device sign-up: name + mobile number, then protect the app with a PIN or Face ID /
/// fingerprint. Everything stays on this phone; no server account is created.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  SetupLock _lock = SetupLock.pin;
  bool _busy = false;
  String? _error;
  bool _recovered = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted && (p.getBool(unreadableDbRecoveredKey) ?? false)) setState(() => _recovered = true);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().length >= 2 && isValidPhone(asciiDigits(_phone.text));

  Future<String?> _newPin() async {
    String? error;
    while (true) {
      final first = await askPin(context, title: 'security.setupPin'.tr(), subtitle: 'security.setupPinHint'.tr(), error: error);
      if (first == null || !mounted) return null;
      final second = await askPin(context, title: 'security.confirmPin'.tr());
      if (second == null || !mounted) return null;
      if (first == second) return first;
      error = 'security.pinMismatch'.tr();
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final store = SecureStorageService.instance;
      if (_lock == SetupLock.pin) {
        final pin = await _newPin();
        if (pin == null) return;
        await store.setPin(pin);
      } else {
        final ok = await LockNotifier.runWithoutLock(
          () => LocalAuthentication().authenticate(localizedReason: 'setup.biometricsReason'.tr()),
        );
        if (!ok) {
          setState(() => _error = 'security.biometricsFailed'.tr());
          return;
        }
        await store.clearPin();
      }
      final settings = ref.read(settingsProvider.notifier);
      await settings.setUserName(_name.text.trim());
      await settings.setUserPhone(_phone.text.replaceAll(RegExp(r'[\s\-()]'), ''));
      await settings.setBiometricEnabled(_lock == SetupLock.biometrics);
      await settings.setAppLockEnabled(true);
      ref.read(lockProvider.notifier).unlock();
      (await SharedPreferences.getInstance()).remove(unreadableDbRecoveredKey);
      // Router redirect takes the user to Home once onboarding is complete.
      await settings.completeOnboarding();
    } catch (_) {
      if (mounted) setState(() => _error = 'security.biometricsFailed'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _option(SetupLock value, IconData icon, String title, String subtitle, {bool enabled = true}) {
    final theme = Theme.of(context);
    final selected = _lock == value;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 10),
        color: selected ? theme.colorScheme.primaryContainer : null,
        onTap: enabled ? () => setState(() => _lock = value) : null,
        child: Row(
          children: [
            IconBubble(icon: icon, color: DS.primary, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? DS.primary : theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final biometrics = ref.watch(biometricsAvailableProvider).value ?? false;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          const Center(child: AppLogo()),
          const SizedBox(height: 12),
          Text('setup.title'.tr(), textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          Text(
            'setup.subtitle'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (_recovered)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AppCard(
                color: DS.warningSoft,
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: DS.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('setup.recoveredNotice'.tr(), style: theme.textTheme.bodySmall?.copyWith(color: DS.text)),
                    ),
                  ],
                ),
              ),
            ),
          FieldLabel('setup.name'.tr()),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            decoration: InputDecoration(hintText: 'setup.nameHint'.tr(), prefixIcon: const Icon(Icons.person_outline)),
            onChanged: (_) => setState(() {}),
          ),
          FieldLabel('setup.phone'.tr()),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [
              const AsciiDigitsFormatter(),
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]')),
              LengthLimitingTextInputFormatter(16),
            ],
            textDirection: ui.TextDirection.ltr,
            decoration: const InputDecoration(hintText: '01xxxxxxxxx', prefixIcon: Icon(Icons.phone_iphone)),
            onChanged: (_) => setState(() {}),
          ),
          if (_phone.text.isNotEmpty && !isValidPhone(_phone.text))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('setup.phoneInvalid'.tr(), style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
            ),
          FieldLabel('setup.protect'.tr()),
          _option(SetupLock.pin, Icons.pin_outlined, 'setup.pinTitle'.tr(), 'setup.pinSubtitle'.tr()),
          _option(
            SetupLock.biometrics,
            Icons.face_retouching_natural,
            'setup.bioTitle'.tr(),
            biometrics ? 'setup.bioSubtitle'.tr() : 'setup.bioUnavailable'.tr(),
            enabled: biometrics,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || !_valid ? null : _submit,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('setup.create'.tr()),
          ),
          const SizedBox(height: 10),
          Text(
            'setup.localNote'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
