import 'package:expense_tracker_flutter/core/security/lock_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('locks only after the app was away for the chosen time', () {
    final left = DateTime(2026, 10, 15, 10, 0);
    const five = Duration(minutes: 5);
    expect(AppLifecycleLockObserver.shouldLock(left, left.add(const Duration(minutes: 2)), five), isFalse);
    expect(AppLifecycleLockObserver.shouldLock(left, left.add(const Duration(minutes: 5)), five), isTrue);
    expect(AppLifecycleLockObserver.shouldLock(left, left.add(const Duration(seconds: 1)), Duration.zero), isTrue);
  });
}
