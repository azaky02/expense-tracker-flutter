/// All dates are stored/compared as Gregorian DateTime (date-only, time truncated) — see
/// tables.dart's note on Transactions.date. Hijri conversion happens only at the UI boundary.
DateTime todayDateOnly() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

(DateTime start, DateTime end) getMonthRange([DateTime? reference]) {
  final ref = reference ?? DateTime.now();
  final start = DateTime(ref.year, ref.month, 1);
  final end = DateTime(ref.year, ref.month + 1, 0);
  return (start, end);
}

/// Clamps a day-of-month (e.g. a card's due date) to that month's actual last valid day.
int clampDayToMonth(int year, int month1Based, int day) {
  final lastDay = DateTime(year, month1Based + 1, 0).day;
  return day < lastDay ? day : lastDay;
}

/// Days from today until the next occurrence of a day-of-month due date (this month if it
/// hasn't passed yet, else next month), clamped to each month's real last day.
int daysUntilNextDueDate(int dueDateDay, [DateTime? reference]) {
  final today = dateOnly(reference ?? DateTime.now());
  final thisMonthDay = clampDayToMonth(today.year, today.month, dueDateDay);
  var candidate = DateTime(today.year, today.month, thisMonthDay);
  if (candidate.isBefore(today)) {
    final nextMonthDay = clampDayToMonth(today.year, today.month + 1, dueDateDay);
    candidate = DateTime(today.year, today.month + 1, nextMonthDay);
  }
  return candidate.difference(today).inDays;
}

/// The salary date in a month, clamped to the month's last day.
DateTime salaryDateIn(int year, int month, int salaryDay) => DateTime(year, month, clampDayToMonth(year, month, salaryDay));

/// The budget cycle named by [month]: the calendar month, or with a salary day set, from the
/// salary day of [month] to the day before the next one (29/10 → 28/11).
(DateTime start, DateTime end) budgetCycleRange(DateTime month, int salaryDay) {
  if (salaryDay <= 1) return getMonthRange(month);
  final start = salaryDateIn(month.year, month.month, salaryDay);
  final next = salaryDateIn(month.year, month.month + 1, salaryDay);
  return (start, next.subtract(const Duration(days: 1)));
}

/// The month whose budget cycle contains [day].
DateTime budgetCycleMonthOf(DateTime day, int salaryDay) {
  final d = dateOnly(day);
  if (salaryDay <= 1 || !d.isBefore(salaryDateIn(d.year, d.month, salaryDay))) return DateTime(d.year, d.month);
  return DateTime(d.year, d.month - 1);
}

/// Splits a cycle into 4 near-equal weeks, longer ones first (31 days → 8, 8, 8, 7).
List<(DateTime start, DateTime end)> splitIntoWeeks(DateTime start, DateTime end) {
  final days = end.difference(start).inDays + 1;
  final out = <(DateTime, DateTime)>[];
  var cursor = start;
  for (var i = 0; i < 4; i++) {
    final len = days ~/ 4 + (i < days % 4 ? 1 : 0);
    final last = DateTime(cursor.year, cursor.month, cursor.day + len - 1);
    out.add((cursor, last));
    cursor = DateTime(last.year, last.month, last.day + 1);
  }
  return out;
}
