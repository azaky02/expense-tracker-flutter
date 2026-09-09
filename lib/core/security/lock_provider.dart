import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True until the security gate (PIN/biometric) is built out — app starts unlocked.
/// Re-locks on every AppLifecycleState.paused/inactive transition when app-lock is enabled
/// (see AppLifecycleObserver below), no grace period.
class LockNotifier extends Notifier<bool> {
  @override
  bool build() => true; // isUnlocked

  void unlock() => state = true;
  void lock() => state = false;
}

final lockProvider = NotifierProvider<LockNotifier, bool>(LockNotifier.new);

/// Wire this into a root widget via WidgetsBindingObserver to re-lock on backgrounding.
/// Takes plain callbacks rather than a Ref/WidgetRef so it works from either ConsumerState
/// (WidgetRef, in Riverpod 3.x no longer a subtype of Ref) or a plain Ref context.
class AppLifecycleLockObserver extends WidgetsBindingObserver {
  AppLifecycleLockObserver({required this.isAppLockEnabled, required this.onLock});

  final bool Function() isAppLockEnabled;
  final VoidCallback onLock;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused || state == AppLifecycleState.inactive) &&
        isAppLockEnabled()) {
      onLock();
    }
  }
}
