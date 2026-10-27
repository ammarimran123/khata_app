import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/date_period.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/khata_chip.dart';
import '../../clients/data/client_summary.dart';
import '../../clients/presentation/clients_providers.dart';
import '../../dashboard/data/period_totals.dart';
import '../../dashboard/presentation/dashboard_providers.dart';

enum _ClientSort { recent, name, highest }

/// Daily/weekly/monthly/custom-range reporting: receivable/payable are
/// point-in-time client-balance totals (never period-filtered); income,
/// expenses and profit/loss are period-filtered, reusing the same
/// `periodTotalsProvider` the Dashboard and P&L screens already use.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DatePeriod _period = DatePeriod.month;
  DateTime? _customStart;
  DateTime? _customEnd;
  _ClientSort _sort = _ClientSort.highest;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange:
          _customStart != null && _customEnd != null
              ? DateTimeRange(start: _customStart!, end: _customEnd!)
              : DateTimeRange(start: now, end: now),
    );
    if (picked != null) {
      setState(() {
        _period = DatePeriod.custom;
        _customStart = picked.start;
        _customEnd = picked.end;
      });
    }
  }

  void _cycleSort() {
    setState(() {
      _sort = _ClientSort.values[(_sort.index + 1) % _ClientSort.values.length];
    });
  }

  String _sortLabel(_ClientSort s) => switch (s) {
    _ClientSort.recent => 'Recent',
    _ClientSort.name => 'Name',
    _ClientSort.highest => 'Highest',
  };

  List<ClientSummary> _sorted(List<ClientSummary> list) {
    final sorted = [...list];
    switch (_sort) {
      case _ClientSort.recent:
        sorted.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
      case _ClientSort.name:
        sorted.sort((a, b) => a.client.name.compareTo(b.client.name));
      case _ClientSort.highest:
        sorted.sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final summariesAsync = ref.watch(clientSummariesProvider);
    final range = datePeriodRange(
      _period,
      customStart: _customStart,
      customEnd: _customEnd,
    );
    final totalsAsync = ref.watch(periodTotalsProvider(range));

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(clientSummariesProvider);
          ref.invalidate(periodTotalsProvider(range));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            Text('Reports', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.s4),
            Container(height: AppSpacing.ruleWidth, color: AppColors.text),
            const SizedBox(height: AppSpacing.s4),
            _buildPeriodChips(),
            const SizedBox(height: AppSpacing.s4),
            Container(height: AppSpacing.ruleWidth, color: AppColors.text),
            const SizedBox(height: AppSpacing.s4),
            _buildSummary(summariesAsync, totalsAsync),
            const SizedBox(height: AppSpacing.s6),
            _buildClientWise(summariesAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChips() {
    final customLabel =
        _period == DatePeriod.custom && _customStart != null && _customEnd != null
            ? '${Formatters.date(_customStart!)} – ${Formatters.date(_customEnd!)}'
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: DatePeriod.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final p = DatePeriod.values[i];
              return KhataChip(
                label: datePeriodLabel(p),
                selected: _period == p,
                onTap: () {
                  if (p == DatePeriod.custom) {
                    _pickCustomRange();
                  } else {
                    setState(() => _period = p);
                  }
                },
              );
            },
          ),
        ),
        if (customLabel != null) ...[
          const SizedBox(height: 6),
          Text(
            customLabel,
            style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
          ),
        ],
      ],
    );
  }

  Widget _buildSummary(
    AsyncValue<List<ClientSummary>> summariesAsync,
    AsyncValue<PeriodTotals> totalsAsync,
  ) {
    if (summariesAsync.isLoading || totalsAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (summariesAsync.hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Could not load client balances.\n${summariesAsync.error}',
          style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
        ),
      );
    }
    if (totalsAsync.hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Could not load totals.\n${totalsAsync.error}',
          style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
        ),
      );
    }

    final clients = summariesAsync.requireValue;
    final totals = totalsAsync.requireValue;
    final receivable = clients
        .where((s) => s.balance > 0)
        .fold(0.0, (sum, s) => sum + s.balance);
    final payable = -clients
        .where((s) => s.balance < 0)
        .fold(0.0, (sum, s) => sum + s.balance);
    final settledCount = clients.where((s) => s.balance == 0).length;
    final isProfit = totals.profitLoss >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SUMMARY',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.neutral600,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _summaryCell('Clients', '${clients.length}'),
                  ),
                  Expanded(child: _summaryCell('Settled', '$settledCount')),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _summaryCell(
                      'Receivable',
                      Formatters.currency(receivable),
                    ),
                  ),
                  Expanded(
                    child: _summaryCell(
                      'Payable',
                      Formatters.currency(payable),
                      color: AppColors.accent700,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _summaryCell(
                      'Income · ${datePeriodLabel(_period)}',
                      Formatters.currency(totals.income),
                    ),
                  ),
                  Expanded(
                    child: _summaryCell(
                      'Expenses · ${datePeriodLabel(_period)}',
                      Formatters.currency(totals.expense),
                      color: AppColors.accent700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.text, width: AppSpacing.ruleWidth),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${datePeriodLabel(_period)} · ${isProfit ? 'Net profit' : 'Net loss'}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.neutral600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.currency(totals.profitLoss),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: isProfit ? AppColors.text : AppColors.accent700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryCell(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: color ?? AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientWise(AsyncValue<List<ClientSummary>> summariesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text(
              'CLIENT-WISE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: AppColors.neutral600,
              ),
            ),
            TextButton.icon(
              onPressed: _cycleSort,
              icon: const Icon(Icons.sort, size: 14),
              label: Text('Sort · ${_sortLabel(_sort)}'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(height: AppSpacing.ruleWidth, color: AppColors.text),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'CLIENT',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.neutral600,
                ),
              ),
              Text(
                'BALANCE / STATUS',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.neutral600,
                ),
              ),
            ],
          ),
        ),
        summariesAsync.when(
          data: (list) {
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: EmptyState(message: 'No clients yet.'),
              );
            }
            final sorted = _sorted(list);
            return Column(
              children: [for (final s in sorted) _clientRow(s)],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Could not load clients.\n$e',
              style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _clientRow(ClientSummary s) {
    final color = AppColors.ledgerAmountColor(s.balance);
    final status = s.balance > 0
        ? 'Receivable'
        : s.balance < 0
        ? 'Payable'
        : 'Settled';

    return InkWell(
      onTap: () => context.push('/clients/${s.client.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                s.client.name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  Formatters.currency(s.balance),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 74,
                  child: Text(
                    status.toUpperCase(),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.neutral600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
