import 'package:expense_tracker_flutter/core/utils/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('salary day 29: cycle 29/10 → 28/11 split into 4 weeks', () {
    final (start, end) = budgetCycleRange(DateTime(2026, 10), 29);
    expect(start, DateTime(2026, 10, 29));
    expect(end, DateTime(2026, 11, 28));
    final weeks = splitIntoWeeks(start, end);
    expect(weeks[0], (DateTime(2026, 10, 29), DateTime(2026, 11, 5)));
    expect(weeks[1], (DateTime(2026, 11, 6), DateTime(2026, 11, 13)));
    expect(weeks[3].$2, end);
    // 5 Nov still belongs to the October cycle; 29 Nov opens the next one.
    expect(budgetCycleMonthOf(DateTime(2026, 11, 5), 29), DateTime(2026, 10));
    expect(budgetCycleMonthOf(DateTime(2026, 11, 29), 29), DateTime(2026, 11));
    // February has no 29th in 2027: the cycle starts on the 28th.
    expect(budgetCycleRange(DateTime(2027, 1), 29).$2, DateTime(2027, 2, 27));
  });

  test('no salary day: calendar month', () {
    expect(budgetCycleRange(DateTime(2026, 10), 0), (DateTime(2026, 10, 1), DateTime(2026, 10, 31)));
  });
}
