import 'package:supabase_flutter/supabase_flutter.dart';

import 'period_totals.dart';

class DashboardRepository {
  DashboardRepository(this._client);

  final SupabaseClient _client;

  /// Sums client-ledger credit/debit and income_expenses income/expense for
  /// [start, end) — fetched as raw rows and summed in Dart, matching how
  /// the client profile computes its own totals, rather than a bespoke SQL
  /// aggregate for what's a modest row count in practice.
  Future<PeriodTotals> fetchPeriodTotals({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final startUtc = start.toUtc().toIso8601String();
      final endUtc = end.toUtc().toIso8601String();

      final txRows = await _client
          .from('client_transactions')
          .select('type, amount')
          .eq('is_deleted', false)
          .gte('occurred_at', startUtc)
          .lt('occurred_at', endUtc);

      final ieRows = await _client
          .from('income_expenses')
          .select('type, amount')
          .eq('is_deleted', false)
          .gte('occurred_at', startUtc)
          .lt('occurred_at', endUtc);

      double sumWhere(List<Map<String, dynamic>> rows, String type) => rows
          .where((r) => r['type'] == type)
          .fold(0.0, (sum, r) => sum + (r['amount'] as num).toDouble());

      return PeriodTotals(
        credit: sumWhere(txRows, 'credit'),
        debit: sumWhere(txRows, 'debit'),
        income: sumWhere(ieRows, 'income'),
        expense: sumWhere(ieRows, 'expense'),
      );
    } on PostgrestException catch (e) {
      throw DashboardRepositoryException(e.message);
    }
  }
}

class DashboardRepositoryException implements Exception {
  DashboardRepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}
