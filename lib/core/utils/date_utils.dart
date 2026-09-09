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
