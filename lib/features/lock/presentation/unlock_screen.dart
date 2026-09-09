import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/security/lock_provider.dart';
import '../../../core/security/secure_storage.dart';
import '../../../core/settings/settings_provider.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  static const _pinLength = 4;
  String _pin = '';
  bool _wrongPin = false;
  final _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeTryBiometrics());
  }

  Future<void> _maybeTryBiometrics() async {
    if (!ref.read(settingsProvider).biometricEnabled) return;
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'security.unlockPrompt'.tr(),
      );
      if (ok) ref.read(lockProvider.notifier).unlock();
    } catch (_) {
      // Ignore — user can still fall back to the PIN pad.
    }
  }

  void _onDigit(String digit) {
    if (_pin.length >= _pinLength) return;
    setState(() {
      _pin += digit;
      _wrongPin = false;
    });
    if (_pin.length == _pinLength) _verify();
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verify() async {
    final ok = await SecureStorageService.instance.verifyPin(_pin);
    if (ok) {
      ref.read(lockProvider.notifier).unlock();
    } else {
      setState(() {
        _wrongPin = true;
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final biometricEnabled = ref.watch(settingsProvider).biometricEnabled;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 40),
              const SizedBox(height: 16),
              Text('security.enterPin'.tr(), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              if (_wrongPin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('security.wrongPin'.tr(),
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_pinLength, (i) {
                  final filled = i < _pin.length;
                  return Container(
                    margin: const EdgeInsets.all(6),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 240,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                      _PadKey(label: d, onTap: () => _onDigit(d)),
                    const SizedBox(width: 80, height: 64),
                    _PadKey(label: '0', onTap: () => _onDigit('0')),
                    SizedBox(
                      width: 80,
                      height: 64,
                      child: IconButton(
                        icon: const Icon(Icons.backspace_outlined),
                        onPressed: _backspace,
                      ),
                    ),
                  ],
                ),
              ),
              if (biometricEnabled)
                TextButton(
                  onPressed: _maybeTryBiometrics,
                  child: Text('security.useBiometrics'.tr()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 64,
      child: TextButton(
        onPressed: onTap,
        child: Text(label, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
