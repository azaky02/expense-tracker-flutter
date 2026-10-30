import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_flutter/core/security/lock_provider.dart';

void main() {
  group('App lock timeout', () {
    final leftAt = DateTime(2026, 10, 30, 12);

    test('locks immediately when timeout is zero', () {
      expect(
        AppLifecycleLockObserver.shouldLock(
          leftAt,
          leftAt,
          Duration.zero,
        ),
        isTrue,
      );
    });

    test('does not lock before configured timeout', () {
      expect(
        AppLifecycleLockObserver.shouldLock(
          leftAt,
          leftAt.add(const Duration(minutes: 4)),
          const Duration(minutes: 5),
        ),
        isFalse,
      );
    });

    test('locks at configured timeout', () {
      expect(
        AppLifecycleLockObserver.shouldLock(
          leftAt,
          leftAt.add(const Duration(minutes: 5)),
          const Duration(minutes: 5),
        ),
        isTrue,
      );
    });
  });
}
