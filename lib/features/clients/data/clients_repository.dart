import 'package:supabase_flutter/supabase_flutter.dart';

import 'client.dart';
import 'client_summary.dart';
import 'client_transaction.dart';

/// All client data access goes through here — screens never touch
/// `supabase.from(...)` directly, so RLS-driven error mapping and the
/// balance formula stay in one place.
class ClientsRepository {
  ClientsRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('No authenticated user.');
    return id;
  }

  /// Active clients joined with their `client_balances` aggregate, for the
  /// client list. Two lightweight queries merged in memory rather than a
  /// PostgREST embed, since `client_balances` is a view with no declared FK.
  Future<List<ClientSummary>> fetchClientSummaries() async {
    try {
      final clientRows = await _client
          .from('clients')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: true);
      final balanceRows = await _client.from('client_balances').select();

      final balanceByClientId = {
        for (final row in balanceRows) row['client_id'] as String: row,
      };

      return clientRows.map((row) {
        final client = Client.fromJson(row);
        final balanceRow = balanceByClientId[client.id];
        final lastTx = balanceRow?['last_transaction_at'] as String?;
        return ClientSummary(
          client: client,
          balance:
              (balanceRow?['balance'] as num?)?.toDouble() ??
              client.openingBalance,
          lastTransactionAt: lastTx != null
              ? DateTime.parse(lastTx).toLocal()
              : null,
          transactionCount:
              (balanceRow?['transaction_count'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw ClientRepositoryException(e.message);
    }
  }

  Future<Client> fetchClient(String id) async {
    try {
      final row = await _client.from('clients').select().eq('id', id).single();
      return Client.fromJson(row);
    } on PostgrestException catch (e) {
      throw ClientRepositoryException(e.message);
    }
  }

  Future<List<ClientTransaction>> fetchTransactions(String clientId) async {
    try {
      final rows = await _client
          .from('client_transactions')
          .select()
          .eq('client_id', clientId)
          .eq('is_deleted', false)
          // Must be ascending — the running-balance calculation walks
          // forward from opening_balance chronologically. postgrest-dart's
          // order() defaults ascending to false, unlike SQL's own default,
          // so this must always be explicit.
          .order('occurred_at', ascending: true);
      return rows.map(ClientTransaction.fromJson).toList();
    } on PostgrestException catch (e) {
      throw ClientRepositoryException(e.message);
    }
  }

  Future<Client> createClient({
    required String name,
    required String phone,
    String? businessName,
    String? notes,
    required double openingBalance,
  }) async {
    try {
      final row = await _client
          .from('clients')
          .insert({
            'user_id': _userId,
            'name': name,
            'phone': phone,
            'business_name': businessName,
            'notes': notes,
            'opening_balance': openingBalance,
          })
          .select()
          .single();
      return Client.fromJson(row);
    } on PostgrestException catch (e) {
      throw ClientRepositoryException(_mapError(e));
    }
  }

  Future<Client> updateClient({
    required String id,
    required String name,
    required String phone,
    String? businessName,
    String? notes,
    required double openingBalance,
  }) async {
    try {
      final row = await _client
          .from('clients')
          .update({
            'name': name,
            'phone': phone,
            'business_name': businessName,
            'notes': notes,
            'opening_balance': openingBalance,
          })
          .eq('id', id)
          .select()
          .single();
      return Client.fromJson(row);
    } on PostgrestException catch (e) {
      throw ClientRepositoryException(_mapError(e));
    }
  }

  Future<ClientTransaction> createTransaction({
    required String clientId,
    required TransactionType type,
    required double amount,
    required DateTime occurredAt,
    String? description,
    String? paymentMethod,
    String? referenceNo,
  }) async {
    try {
      final row = await _client
          .from('client_transactions')
          .insert({
            'user_id': _userId,
            'client_id': clientId,
            'type': type == TransactionType.credit ? 'credit' : 'debit',
            'amount': amount,
            'occurred_at': occurredAt.toUtc().toIso8601String(),
            'description': description,
            'payment_method': paymentMethod,
            'reference_no': referenceNo,
          })
          .select()
          .single();
      return ClientTransaction.fromJson(row);
    } on PostgrestException catch (e) {
      throw ClientRepositoryException(e.message);
    }
  }

  Future<ClientTransaction> updateTransaction({
    required String id,
    required TransactionType type,
    required double amount,
    required DateTime occurredAt,
    String? description,
    String? paymentMethod,
    String? referenceNo,
  }) async {
    try {
      final row = await _client
          .from('client_transactions')
          .update({
            'type': type == TransactionType.credit ? 'credit' : 'debit',
            'amount': amount,
            'occurred_at': occurredAt.toUtc().toIso8601String(),
            'description': description,
            'payment_method': paymentMethod,
            'reference_no': referenceNo,
          })
          .eq('id', id)
          .select()
          .single();
      return ClientTransaction.fromJson(row);
    } on PostgrestException catch (e) {
      throw ClientRepositoryException(e.message);
    }
  }

  /// Never hard-deletes — keeps the row for the audit trail and lets the
  /// balance view simply exclude it via `is_deleted = false`.
  Future<void> softDeleteTransaction(String id) async {
    try {
      await _client
          .from('client_transactions')
          .update({
            'is_deleted': true,
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'deleted_by': _userId,
          })
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw ClientRepositoryException(e.message);
    }
  }

  String _mapError(PostgrestException e) {
    if (e.code == '23505') {
      return 'A client with this phone number already exists.';
    }
    return e.message;
  }
}

class ClientRepositoryException implements Exception {
  ClientRepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}
