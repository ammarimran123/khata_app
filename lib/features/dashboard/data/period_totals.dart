/// Aggregated figures for a date range. Credit/debit come from the client
/// ledger; income/expense are entirely separate business records. Profit
/// and loss is computed strictly as income − expense — never derived from
/// client credit/debit, which would conflate the ledger with the P&L.
class PeriodTotals {
  const PeriodTotals({
    required this.credit,
    required this.debit,
    required this.income,
    required this.expense,
  });

  final double credit;
  final double debit;
  final double income;
  final double expense;

  double get netMovement => credit - debit;
  double get profitLoss => income - expense;
}
