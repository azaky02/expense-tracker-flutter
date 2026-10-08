import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// isUnlocked. Starts locked: the router only sends the user to /unlock when app lock is enabled,
/// so with the lock off this has no effect. Re-locks whenever the app goes to the background.
class LockNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Set while the app itself opens the camera, gallery, file picker or share sheet, so coming
  /// back from them does not throw the user out to the lock screen mid-task.
  static bool suspended = false;

  static Future<T> runWithoutLock<T>(Future<T> Function() action) async {
    suspended = true;
    try {
      return await action();
    } finally {
      // The resume event arrives right after the external activity closes.
      Future<void>.delayed(const Duration(seconds: 1), () => suspended = false);
    }
  }

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
    // `paused` only: `inactive` also fires for the notification shade and the biometric dialog.
    if (state == AppLifecycleState.paused && isAppLockEnabled() && !LockNotifier.suspended) {
      onLock();
    }
  }
}
