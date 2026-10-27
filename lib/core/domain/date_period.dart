/// A shared date filter used by both the Dashboard and P&L screens.
/// Receivable/payable are point-in-time balances and are never
/// period-filtered — only credit/debit/income/expense/profit-loss depend
/// on the selected period.
enum DatePeriod { today, yesterday, week, month, custom }

String datePeriodLabel(DatePeriod period) => switch (period) {
  DatePeriod.today => 'Today',
  DatePeriod.yesterday => 'Yesterday',
  DatePeriod.week => 'This Week',
  DatePeriod.month => 'This Month',
  DatePeriod.custom => 'Custom Range',
};

/// Half-open [start, end) local-time window for a period. `custom` falls
/// back to just today when no range has been picked yet.
({DateTime start, DateTime end}) datePeriodRange(
  DatePeriod period, {
  DateTime? customStart,
  DateTime? customEnd,
}) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);

  switch (period) {
    case DatePeriod.today:
      return (start: todayStart, end: todayStart.add(const Duration(days: 1)));
    case DatePeriod.yesterday:
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));
      return (start: yesterdayStart, end: todayStart);
    case DatePeriod.week:
      final weekStart = todayStart.subtract(
        Duration(days: todayStart.weekday - 1),
      );
      return (start: weekStart, end: weekStart.add(const Duration(days: 7)));
    case DatePeriod.month:
      final monthStart = DateTime(now.year, now.month, 1);
      final nextMonthStart = DateTime(now.year, now.month + 1, 1);
      return (start: monthStart, end: nextMonthStart);
    case DatePeriod.custom:
      final startDay = customStart ?? todayStart;
      final endDay = customEnd ?? startDay;
      final start = DateTime(startDay.year, startDay.month, startDay.day);
      final end = DateTime(
        endDay.year,
        endDay.month,
        endDay.day,
      ).add(const Duration(days: 1));
      return (start: start, end: end);
  }
}
