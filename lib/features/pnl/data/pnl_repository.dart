import 'package:supabase_flutter/supabase_flutter.dart';

import 'category.dart';
import 'income_expense.dart';

/// All income/expense data access — screens never touch
/// `supabase.from('income_expenses')` directly.
class PnlRepository {
  PnlRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('No authenticated user.');
    return id;
  }

  Future<List<Category>> fetchCategories() async {
    try {
      final rows = await _client
          .from('categories')
          .select()
          .order('name', ascending: true);
      return rows.map(Category.fromJson).toList();
    } on PostgrestException catch (e) {
      throw PnlRepositoryException(e.message);
    }
  }

  /// Non-deleted entries in [start, end), most recent first, with each
  /// row's category name embedded via the FK so summaries and the
  /// itemized list both come from one query.
  Future<List<IncomeExpense>> fetchEntries({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final rows = await _client
          .from('income_expenses')
          .select('*, categories(name)')
          .eq('is_deleted', false)
          .gte('occurred_at', start.toUtc().toIso8601String())
          .lt('occurred_at', end.toUtc().toIso8601String())
          .order('occurred_at', ascending: false);
      return rows.map(IncomeExpense.fromJson).toList();
    } on PostgrestException catch (e) {
      throw PnlRepositoryException(e.message);
    }
  }

  Future<IncomeExpense> createEntry({
    required IncomeExpenseType type,
    required double amount,
    required DateTime occurredAt,
    String? categoryId,
    String? description,
    String? paymentMethod,
    String? referenceNo,
  }) async {
    try {
      final row = await _client
          .from('income_expenses')
          .insert({
            'user_id': _userId,
            'type': type == IncomeExpenseType.income ? 'income' : 'expense',
            'category_id': categoryId,
            'amount': amount,
            'occurred_at': occurredAt.toUtc().toIso8601String(),
            'description': description,
            'payment_method': paymentMethod,
            'reference_no': referenceNo,
          })
          .select('*, categories(name)')
          .single();
      return IncomeExpense.fromJson(row);
    } on PostgrestException catch (e) {
      throw PnlRepositoryException(e.message);
    }
  }

  Future<IncomeExpense> updateEntry({
    required String id,
    required IncomeExpenseType type,
    required double amount,
    required DateTime occurredAt,
    String? categoryId,
    String? description,
    String? paymentMethod,
    String? referenceNo,
  }) async {
    try {
      final row = await _client
          .from('income_expenses')
          .update({
            'type': type == IncomeExpenseType.income ? 'income' : 'expense',
            'category_id': categoryId,
            'amount': amount,
            'occurred_at': occurredAt.toUtc().toIso8601String(),
            'description': description,
            'payment_method': paymentMethod,
            'reference_no': referenceNo,
          })
          .eq('id', id)
          .select('*, categories(name)')
          .single();
      return IncomeExpense.fromJson(row);
    } on PostgrestException catch (e) {
      throw PnlRepositoryException(e.message);
    }
  }

  /// Never hard-deletes — keeps the row for the audit trail.
  Future<void> softDeleteEntry(String id) async {
    try {
      await _client
          .from('income_expenses')
          .update({
            'is_deleted': true,
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'deleted_by': _userId,
          })
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw PnlRepositoryException(e.message);
    }
  }
}

class PnlRepositoryException implements Exception {
  PnlRepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}
