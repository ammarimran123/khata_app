import 'client.dart';

/// A client row combined with its balance, as computed by the
/// `client_balances` SQL view (opening_balance + credit − debit over
/// non-deleted transactions) — used for the client list, where fetching
/// one aggregate row per client is far cheaper than pulling every
/// transaction for every client just to list them.
class ClientSummary {
  const ClientSummary({
    required this.client,
    required this.balance,
    required this.lastTransactionAt,
    required this.transactionCount,
  });

  final Client client;
  final double balance;
  final DateTime? lastTransactionAt;
  final int transactionCount;

  DateTime get lastActivity => lastTransactionAt ?? client.createdAt;
}
