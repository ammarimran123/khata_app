import 'client.dart';
import 'client_transaction.dart';

/// A client plus its full (non-deleted) transaction history. Every total
/// here is derived from `transactions`, never stored — the same
/// opening + credit − debit formula the `client_balances` view uses, kept
/// in Dart because the ledger screen already needs the raw rows to render
/// running balances.
class ClientDetail {
  ClientDetail({required this.client, required this.transactions});

  final Client client;
  final List<ClientTransaction> transactions;

  double get totalCredit => transactions
      .where((t) => t.type == TransactionType.credit)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalDebit => transactions
      .where((t) => t.type == TransactionType.debit)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get balance => client.openingBalance + totalCredit - totalDebit;

  DateTime get lastActivity =>
      transactions.isEmpty ? client.createdAt : transactions.last.occurredAt;

  /// Ledger rows paired with their running balance, most recent first.
  /// `transactions` must already be ordered ascending by occurred_at.
  List<MapEntry<ClientTransaction, double>> get ledgerWithRunningBalance {
    var running = client.openingBalance;
    final rows = <MapEntry<ClientTransaction, double>>[];
    for (final t in transactions) {
      running += t.type == TransactionType.credit ? t.amount : -t.amount;
      rows.add(MapEntry(t, running));
    }
    return rows.reversed.toList();
  }
}
