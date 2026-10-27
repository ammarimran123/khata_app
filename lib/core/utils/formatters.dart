import 'package:intl/intl.dart';

/// Formatting helpers matching the design's presentation exactly
/// ("Rs. 20,000", "+ Rs. 20,000", "28 Aug 2026"). These are display-only —
/// all amounts are computed upstream from database-driven sums, never here.
class Formatters {
  const Formatters._();

  static final NumberFormat _amount = NumberFormat.decimalPattern('en_US');
  static final DateFormat _date = DateFormat('dd MMM yyyy');
  static final DateFormat _time = DateFormat('HH:mm');

  static String currency(num amount) =>
      'Rs. ${_amount.format(amount.abs().round())}';

  /// Grouped digits without the "Rs." prefix — for amount-entry displays
  /// where the currency symbol is already rendered separately.
  static String groupedNumber(num amount) => _amount.format(amount.round());

  /// Prefixes a sign for balances/net movements: `+ Rs. X`, `− Rs. X`, or
  /// bare `Rs. 0` when settled.
  static String signedCurrency(num amount) {
    if (amount > 0) return '+ ${currency(amount)}';
    if (amount < 0) return '− ${currency(amount)}';
    return currency(0);
  }

  static String date(DateTime dt) => _date.format(dt);

  static String time(DateTime dt) => _time.format(dt);
}
