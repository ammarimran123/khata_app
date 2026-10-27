import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_bootstrap.dart';
import '../data/dashboard_repository.dart';
import '../data/period_totals.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(supabase);
});

/// Keyed by a (start, end) record — Dart records have structural equality,
/// so re-selecting the same period reuses the cached result instead of
/// re-fetching.
final periodTotalsProvider = FutureProvider.autoDispose
    .family<PeriodTotals, ({DateTime start, DateTime end})>((ref, range) {
      return ref
          .read(dashboardRepositoryProvider)
          .fetchPeriodTotals(start: range.start, end: range.end);
    });
