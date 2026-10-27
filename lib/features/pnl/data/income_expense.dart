enum IncomeExpenseType { income, expense }

IncomeExpenseType _typeFromString(String s) =>
    s == 'income' ? IncomeExpenseType.income : IncomeExpenseType.expense;

/// A single business income/expense record — entirely separate from the
/// client ledger. Credit/debit move a client's balance; this moves the
/// business's profit and loss, and the two are never conflated.
class IncomeExpense {
  const IncomeExpense({
    required this.id,
    required this.type,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.occurredAt,
    this.description,
    this.paymentMethod,
    this.referenceNo,
  });

  final String id;
  final IncomeExpenseType type;
  final String? categoryId;
  final String categoryName;
  final double amount;
  final DateTime occurredAt;
  final String? description;
  final String? paymentMethod;
  final String? referenceNo;

  factory IncomeExpense.fromJson(Map<String, dynamic> json) {
    final category = json['categories'] as Map<String, dynamic>?;
    return IncomeExpense(
      id: json['id'] as String,
      type: _typeFromString(json['type'] as String),
      categoryId: json['category_id'] as String?,
      categoryName: (category?['name'] as String?) ?? 'Uncategorized',
      amount: (json['amount'] as num).toDouble(),
      occurredAt: DateTime.parse(json['occurred_at'] as String).toLocal(),
      description: json['description'] as String?,
      paymentMethod: json['payment_method'] as String?,
      referenceNo: json['reference_no'] as String?,
    );
  }
}
