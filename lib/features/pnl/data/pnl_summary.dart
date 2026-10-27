import 'income_expense.dart';

class CategoryTotal {
  const CategoryTotal({required this.label, required this.amount});
  final String label;
  final double amount;
}

/// Profit/loss and per-category breakdowns for a date range — computed
/// strictly from income_expenses (income − expense), never from client
/// credit/debit, so the client ledger and business P&L stay independent.
class PnlSummary {
  const PnlSummary({
    required this.income,
    required this.expense,
    required this.incomeByCategory,
    required this.expenseByCategory,
  });

  final double income;
  final double expense;
  final List<CategoryTotal> incomeByCategory;
  final List<CategoryTotal> expenseByCategory;

  double get profitLoss => income - expense;

  factory PnlSummary.fromEntries(List<IncomeExpense> entries) {
    var income = 0.0;
    var expense = 0.0;
    final incomeByCat = <String, double>{};
    final expenseByCat = <String, double>{};

    for (final e in entries) {
      if (e.type == IncomeExpenseType.income) {
        income += e.amount;
        incomeByCat[e.categoryName] = (incomeByCat[e.categoryName] ?? 0) + e.amount;
      } else {
        expense += e.amount;
        expenseByCat[e.categoryName] =
            (expenseByCat[e.categoryName] ?? 0) + e.amount;
      }
    }

    List<CategoryTotal> sortedTotals(Map<String, double> byCategory) {
      final list = byCategory.entries
          .map((e) => CategoryTotal(label: e.key, amount: e.value))
          .toList();
      list.sort((a, b) => b.amount.compareTo(a.amount));
      return list;
    }

    return PnlSummary(
      income: income,
      expense: expense,
      incomeByCategory: sortedTotals(incomeByCat),
      expenseByCategory: sortedTotals(expenseByCat),
    );
  }
}
