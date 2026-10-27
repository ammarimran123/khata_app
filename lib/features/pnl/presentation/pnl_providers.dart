import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_bootstrap.dart';
import '../data/category.dart';
import '../data/income_expense.dart';
import '../data/pnl_repository.dart';

final pnlRepositoryProvider = Provider<PnlRepository>((ref) {
  return PnlRepository(supabase);
});

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.read(pnlRepositoryProvider).fetchCategories();
});

/// Keyed by a (start, end) record — same caching approach as the
/// dashboard's `periodTotalsProvider`. Summaries and the itemized list are
/// both derived from this one fetch.
final pnlEntriesProvider = FutureProvider.autoDispose
    .family<List<IncomeExpense>, ({DateTime start, DateTime end})>((
      ref,
      range,
    ) {
      return ref
          .read(pnlRepositoryProvider)
          .fetchEntries(start: range.start, end: range.end);
    });
