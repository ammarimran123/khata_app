enum TransactionType { credit, debit }

TransactionType _typeFromString(String s) =>
    s == 'credit' ? TransactionType.credit : TransactionType.debit;

/// A single client-ledger entry. Transaction *creation* is out of scope for
/// the Client Management module — this model backs the read-only ledger
/// shown on a client's profile so balances stay database-driven the moment
/// the Transactions module starts writing rows here.
class ClientTransaction {
  const ClientTransaction({
    required this.id,
    required this.clientId,
    required this.type,
    required this.amount,
    required this.occurredAt,
    this.description,
    this.paymentMethod,
    this.referenceNo,
  });

  final String id;
  final String clientId;
  final TransactionType type;
  final double amount;
  final DateTime occurredAt;
  final String? description;
  final String? paymentMethod;
  final String? referenceNo;

  factory ClientTransaction.fromJson(Map<String, dynamic> json) =>
      ClientTransaction(
        id: json['id'] as String,
        clientId: json['client_id'] as String,
        type: _typeFromString(json['type'] as String),
        amount: (json['amount'] as num).toDouble(),
        // Postgres returns this in UTC; convert once here so every
        // consumer (display, edit pre-fill, date filters) works in the
        // same local wall-clock time the user actually entered.
        occurredAt: DateTime.parse(json['occurred_at'] as String).toLocal(),
        description: json['description'] as String?,
        paymentMethod: json['payment_method'] as String?,
        referenceNo: json['reference_no'] as String?,
      );
}
