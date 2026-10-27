import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/date_period.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/khata_chip.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import '../data/income_expense.dart';
import '../data/pnl_repository.dart';
import '../data/pnl_summary.dart';
import 'pnl_providers.dart';
import 'widgets/income_expense_sheet.dart';

class PnlScreen extends ConsumerStatefulWidget {
  const PnlScreen({super.key});

  @override
  ConsumerState<PnlScreen> createState() => _PnlScreenState();
}

class _PnlScreenState extends ConsumerState<PnlScreen> {
  DatePeriod _period = DatePeriod.month;
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

  Future<void> _openEntryMenu(IncomeExpense entry) async {
    final isIncome = entry.type == IncomeExpenseType.income;
    final color = isIncome ? AppColors.text : AppColors.accent700;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${Formatters.date(entry.occurredAt)} · ${Formatters.time(entry.occurredAt)}'
                '${entry.paymentMethod != null ? ' · ${entry.paymentMethod}' : ''}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: AppColors.neutral600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${entry.categoryName} · ${Formatters.currency(entry.amount)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: color,
                ),
              ),
              if (entry.description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    entry.description!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.neutral700,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Container(height: AppSpacing.ruleWidth, color: AppColors.text),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext, 'edit'),
                  child: const Text('Edit entry'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.accent100,
                    foregroundColor: AppColors.accent700,
                    side: const BorderSide(color: AppColors.accent, width: 2),
                  ),
                  onPressed: () => Navigator.pop(sheetContext, 'delete'),
                  child: const Text('Delete entry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'edit') {
      await showIncomeExpenseSheet(context, type: entry.type, editing: entry);
    } else if (action == 'delete') {
      final confirmed = await showConfirmDeleteDialog(
        context,
        title: 'Are you sure you want to delete this entry?',
        message:
            'This will change your profit & loss for the period. '
            'The record is kept in the audit trail, not erased.',
      );
      if (!confirmed) return;
      try {
        await ref.read(pnlRepositoryProvider).softDeleteEntry(entry.id);
        ref.invalidate(pnlEntriesProvider);
        ref.invalidate(periodTotalsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entry deleted.')),
          );
        }
      } on PnlRepositoryException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = datePeriodRange(
      _period,
      customStart: _customStart,
      customEnd: _customEnd,
    );
    final entriesAsync = ref.watch(pnlEntriesProvider(range));

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pnlEntriesProvider(range));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            Text('Profit & Loss', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            const Text(
              'From income and expense records only. Client credit and '
              'debit move the khata, not the profit.',
              style: TextStyle(fontSize: 12, color: AppColors.neutral700),
            ),
            const SizedBox(height: AppSpacing.s4),
            Container(height: AppSpacing.ruleWidth, color: AppColors.text),
            const SizedBox(height: AppSpacing.s4),
            _buildPeriodChips(),
            const SizedBox(height: AppSpacing.s4),
            Container(height: AppSpacing.ruleWidth, color: AppColors.text),
            const SizedBox(height: AppSpacing.s4),
            entriesAsync.when(
              data: (entries) => _buildBody(entries),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Could not load entries.\n$e',
                  style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
                ),
              ),
            ),
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

  Widget _buildBody(List<IncomeExpense> entries) {
    final summary = PnlSummary.fromEntries(entries);
    final isProfit = summary.profitLoss >= 0;
    final maxValue = summary.income > summary.expense
        ? summary.income
        : summary.expense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${datePeriodLabel(_period)} · ${isProfit ? 'Net profit' : 'Net loss'}',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.neutral600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          Formatters.currency(summary.profitLoss),
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: isProfit ? AppColors.text : AppColors.accent700,
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        _bar('Income', summary.income, maxValue, AppColors.text),
        const SizedBox(height: 12),
        _bar('Expense', summary.expense, maxValue, AppColors.accent),
        const SizedBox(height: AppSpacing.s6),
        _buildCategorySection('Income', summary.incomeByCategory),
        const SizedBox(height: AppSpacing.s6),
        _buildCategorySection('Expenses', summary.expenseByCategory),
        const SizedBox(height: AppSpacing.s6),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => showIncomeExpenseSheet(
                  context,
                  type: IncomeExpenseType.income,
                ),
                child: const Text('+ Income'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => showIncomeExpenseSheet(
                  context,
                  type: IncomeExpenseType.expense,
                ),
                child: const Text('+ Expense'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s6),
        Text(
          'ENTRIES',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.neutral600,
          ),
        ),
        const SizedBox(height: 10),
        Container(height: AppSpacing.ruleWidth, color: AppColors.text),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'No income or expense entries for this period.',
                style: TextStyle(fontSize: 13, color: AppColors.neutral600),
              ),
            ),
          )
        else
          for (final entry in entries) _entryRow(entry),
      ],
    );
  }

  Widget _buildCategorySection(String title, List<CategoryTotal> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.neutral600,
          ),
        ),
        const SizedBox(height: 10),
        Container(height: AppSpacing.ruleWidth, color: AppColors.text),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'No entries yet.',
              style: TextStyle(fontSize: 12.5, color: AppColors.neutral600),
            ),
          )
        else
          for (final row in rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(row.label, style: const TextStyle(fontSize: 12.5)),
                  Text(
                    Formatters.currency(row.amount),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
      ],
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
          height: 16,
          color: AppColors.neutral300,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: widthFactor,
              child: Container(height: 16, color: barColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _entryRow(IncomeExpense entry) {
    final isIncome = entry.type == IncomeExpenseType.income;
    final color = isIncome ? AppColors.text : AppColors.accent700;
    final sign = isIncome ? '+ ' : '− ';
    final meta = [
      Formatters.date(entry.occurredAt),
      Formatters.time(entry.occurredAt),
      if (entry.paymentMethod != null) entry.paymentMethod!,
      if (entry.referenceNo != null && entry.referenceNo!.isNotEmpty)
        entry.referenceNo!,
    ].join(' · ');

    return InkWell(
      onTap: () => _openEntryMenu(entry),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry.categoryName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: color,
                  ),
                ),
                Text(
                  '$sign${Formatters.currency(entry.amount)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              entry.description ?? '—',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 3),
            Text(
              meta,
              style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
            ),
          ],
        ),
      ),
    );
  }
}
