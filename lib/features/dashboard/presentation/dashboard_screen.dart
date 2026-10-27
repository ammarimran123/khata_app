import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/date_period.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/khata_chip.dart';
import '../../clients/data/client_summary.dart';
import '../../clients/presentation/clients_providers.dart';
import '../../pnl/data/income_expense.dart';
import '../../pnl/presentation/widgets/income_expense_sheet.dart';
import '../data/period_totals.dart';
import 'dashboard_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DatePeriod _period = DatePeriod.today;
  DateTime? _customStart;
  DateTime? _customEnd;

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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'Hussnain Traders',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 2),
            Text('Khata', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.s4),
            Container(height: AppSpacing.ruleWidth, color: AppColors.text),
            const SizedBox(height: AppSpacing.s4),
            _buildNetBalance(summariesAsync),
            const SizedBox(height: AppSpacing.s6),
            _buildQuickActions(context),
            const SizedBox(height: AppSpacing.s6),
            _buildPeriodChips(),
            const SizedBox(height: AppSpacing.s4),
            Container(height: AppSpacing.ruleWidth, color: AppColors.text),
            const SizedBox(height: AppSpacing.s4),
            _buildTotals(totalsAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildNetBalance(AsyncValue<List<ClientSummary>> summariesAsync) {
    return summariesAsync.when(
      data: (list) {
        final receivable = list
            .where((s) => s.balance > 0)
            .fold(0.0, (sum, s) => sum + s.balance);
        final payable = -list
            .where((s) => s.balance < 0)
            .fold(0.0, (sum, s) => sum + s.balance);
        final receivableCount = list.where((s) => s.balance > 0).length;
        final payableCount = list.where((s) => s.balance < 0).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NET BALANCE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: AppColors.neutral600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              Formatters.currency(receivable - payable),
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Receivable minus payable across ${list.length} clients',
              style: const TextStyle(fontSize: 13, color: AppColors.neutral700),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: const BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(
                    color: AppColors.text,
                    width: AppSpacing.ruleWidth,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: AppColors.divider),
                        ),
                      ),
                      child: _balanceCell(
                        'Receivable',
                        Formatters.currency(receivable),
                        '$receivableCount clients owe you',
                        AppColors.text,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: _balanceCell(
                        'Payable',
                        Formatters.currency(payable),
                        '$payableCount clients you owe',
                        AppColors.accent700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Could not load client balances.\n$e',
          style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
        ),
      ),
    );
  }

  Widget _balanceCell(String label, String value, String note, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.neutral600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(note, style: const TextStyle(fontSize: 11, color: AppColors.neutral600)),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.neutral600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => context.go('/clients'),
                child: const Text('+ Add Credit'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.go('/clients'),
                child: const Text('− Add Debit'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.push('/clients/new'),
                child: const Text('+ Add Client'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => showIncomeExpenseSheet(
                  context,
                  type: IncomeExpenseType.income,
                ),
                child: const Text('+ Income'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => showIncomeExpenseSheet(
              context,
              type: IncomeExpenseType.expense,
            ),
            child: const Text('+ Expense'),
          ),
        ),
      ],
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

  Widget _buildTotals(AsyncValue<PeriodTotals> totalsAsync) {
    return totalsAsync.when(
      data: (totals) {
        final maxValue = [
          totals.income,
          totals.expense,
        ].reduce((a, b) => a > b ? a : b);
        final isProfit = totals.profitLoss >= 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              datePeriodLabel(_period),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: AppColors.neutral600,
              ),
            ),
            const SizedBox(height: 10),
            _metricRow('Credit given', Formatters.currency(totals.credit)),
            _metricRow('Debit / received', Formatters.currency(totals.debit)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Net movement',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    Formatters.signedCurrency(totals.netMovement),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Container(height: AppSpacing.ruleWidth, color: AppColors.text),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Income vs Expense',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: AppColors.neutral600,
              ),
            ),
            const SizedBox(height: 12),
            _bar('Income', totals.income, maxValue, AppColors.text),
            const SizedBox(height: 12),
            _bar('Expense', totals.expense, maxValue, AppColors.accent),
            const SizedBox(height: AppSpacing.s4),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.text, width: AppSpacing.ruleWidth),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isProfit ? 'Net profit' : 'Net loss',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    Formatters.currency(totals.profitLoss),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: isProfit ? AppColors.text : AppColors.accent700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Could not load totals.\n$e',
          style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.neutral800)),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _bar(String label, double value, double maxValue, Color barColor) {
    final widthFactor = maxValue == 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(
              Formatters.currency(value),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          height: 14,
          color: AppColors.neutral300,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: widthFactor,
              child: Container(height: 14, color: barColor),
            ),
          ),
        ),
      ],
    );
  }
}
