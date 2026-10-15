import 'package:expense_tracker_flutter/features/budgets/data/budget_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pace for the current, a past and a future month', () {
    final now = DateTime(2026, 10, 10);
    final p = MonthPace(DateTime(2026, 10), now: now);
    expect(p.totalDays, 31);
    expect(p.elapsedDays, 10);
    expect(p.daysLeft, 21);
    expect(p.isCurrent, isTrue);
    expect(p.dailyRate(1000), 100);
    expect(p.projected(1000), 3100);
    expect(p.dailyAllowance(2100), 100);
    expect(p.dailyAllowance(-5), isNull);

    final past = MonthPace(DateTime(2026, 9), now: now);
    expect((past.elapsedDays, past.daysLeft, past.isCurrent), (30, 0, false));
    expect(past.projected(900), 900);

    final future = MonthPace(DateTime(2026, 11), now: now);
    expect((future.elapsedDays, future.isCurrent), (0, false));
    expect(future.dailyRate(0), 0);
  });
}
