import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/khata_chip.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import '../data/client_detail.dart';
import '../data/client_transaction.dart';
import '../data/clients_repository.dart';
import '../domain/transaction_sheet_mode.dart';
import 'clients_providers.dart';
import 'widgets/transaction_sheet.dart';

enum _LedgerFilter { all, today, thisWeek, credit, debit }

class ClientDetailScreen extends ConsumerStatefulWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<ClientDetailScreen> createState() =>
      _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen> {
  _LedgerFilter _filter = _LedgerFilter.all;

  String _filterLabel(_LedgerFilter f) => switch (f) {
    _LedgerFilter.all => 'All',
    _LedgerFilter.today => 'Today',
    _LedgerFilter.thisWeek => 'This Week',
    _LedgerFilter.credit => 'Credit',
    _LedgerFilter.debit => 'Debit',
  };

  bool _matchesFilter(ClientTransaction t) {
    switch (_filter) {
      case _LedgerFilter.all:
        return true;
      case _LedgerFilter.today:
        final now = DateTime.now();
        return t.occurredAt.year == now.year &&
            t.occurredAt.month == now.month &&
            t.occurredAt.day == now.day;
      case _LedgerFilter.thisWeek:
        return t.occurredAt.isAfter(
          DateTime.now().subtract(const Duration(days: 7)),
        );
      case _LedgerFilter.credit:
        return t.type == TransactionType.credit;
      case _LedgerFilter.debit:
        return t.type == TransactionType.debit;
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(clientDetailProvider(widget.clientId));

    return Scaffold(
      body: SafeArea(
        child: detailAsync.when(
          data: (detail) => _buildBody(context, detail),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not load this client.\n$e',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        ref.invalidate(clientDetailProvider(widget.clientId)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ClientDetail detail) {
    final client = detail.client;
    final balance = detail.balance;
    final color = AppColors.ledgerAmountColor(balance);
    final status = balance > 0
        ? 'Receivable'
        : balance < 0
        ? 'Payable'
        : 'Settled';
    final sentence = balance > 0
        ? 'Client owes you ${Formatters.currency(balance)}'
        : balance < 0
        ? 'You owe this client ${Formatters.currency(balance)}'
        : 'Account settled';

    final rows = detail.ledgerWithRunningBalance
        .where((e) => _matchesFilter(e.key))
        .toList();
    final creditSum = rows
        .where((e) => e.key.type == TransactionType.credit)
        .fold(0.0, (sum, e) => sum + e.key.amount);
    final debitSum = rows
        .where((e) => e.key.type == TransactionType.debit)
        .fold(0.0, (sum, e) => sum + e.key.amount);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => context.pop(),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'CLIENTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: AppColors.neutral700,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => context.push('/clients/${client.id}/edit'),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'EDIT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            client.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 3),
          Text(
            [
              if (client.businessName != null) client.businessName!,
              client.phone,
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: AppColors.neutral700),
          ),
          const SizedBox(height: AppSpacing.s4),
          Container(height: AppSpacing.ruleWidth, color: AppColors.text),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: AppColors.neutral600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.signedCurrency(balance),
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sentence,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.neutral800,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => showTransactionSheet(
                    context,
                    clientId: client.id,
                    mode: TransactionSheetMode.credit,
                    currentBalance: balance,
                  ),
                  child: const Text('+ Add Credit'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showTransactionSheet(
                    context,
                    clientId: client.id,
                    mode: TransactionSheetMode.debit,
                    currentBalance: balance,
                  ),
                  child: const Text('− Add Debit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => showTransactionSheet(
                context,
                clientId: client.id,
                mode: balance < 0
                    ? TransactionSheetMode.pay
                    : TransactionSheetMode.receive,
                currentBalance: balance,
              ),
              child: Text(balance < 0 ? 'Make Payment' : 'Receive Payment'),
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          Text(
            'Account summary',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 10),
          Container(height: AppSpacing.ruleWidth, color: AppColors.text),
          _summaryRow('Opening balance', Formatters.currency(client.openingBalance)),
          _summaryRow('Total credit', Formatters.currency(detail.totalCredit)),
          _summaryRow('Total debit', Formatters.currency(detail.totalDebit)),
          _summaryRow('Transactions', '${detail.transactions.length}'),
          _summaryRow('Client since', Formatters.date(client.createdAt)),
          _summaryRow('Outstanding', Formatters.currency(balance)),
          const SizedBox(height: AppSpacing.s6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'LEDGER',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: AppColors.neutral600,
                ),
              ),
              Text(
                '${rows.length} entries · ${_filterLabel(_filter)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.neutral600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _LedgerFilter.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final f = _LedgerFilter.values[i];
                return KhataChip(
                  label: _filterLabel(f),
                  selected: _filter == f,
                  onTap: () => setState(() => _filter = f),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: AppColors.text, width: AppSpacing.ruleWidth),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _statCell('Credit', Formatters.currency(creditSum)),
                ),
                Expanded(
                  child: _statCell('Debit', Formatters.currency(debitSum)),
                ),
                Expanded(
                  child: _statCell(
                    'Net',
                    Formatters.signedCurrency(creditSum - debitSum),
                    last: true,
                  ),
                ),
              ],
            ),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No transactions yet.',
                  style: TextStyle(fontSize: 13, color: AppColors.neutral600),
                ),
              ),
            )
          else
            for (final entry in rows)
              _ledgerRow(context, entry.key, entry.value, balance),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              'Opening balance ${Formatters.currency(client.openingBalance)} · Balance is derived from the ledger, never edited directly.',
              style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: AppColors.neutral800),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _statCell(String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(right: BorderSide(color: AppColors.divider)),
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
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _ledgerRow(
    BuildContext context,
    ClientTransaction t,
    double runningBalance,
    double currentBalance,
  ) {
    final color = t.type == TransactionType.credit
        ? AppColors.text
        : AppColors.accent700;
    final sign = t.type == TransactionType.credit ? '+ ' : '− ';
    final meta = [
      Formatters.date(t.occurredAt),
      Formatters.time(t.occurredAt),
      if (t.paymentMethod != null) t.paymentMethod!,
      if (t.referenceNo != null && t.referenceNo!.isNotEmpty) t.referenceNo!,
    ].join(' · ');

    return InkWell(
      onTap: () => _openTransactionMenu(context, t, currentBalance),
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
                  t.type == TransactionType.credit ? 'CREDIT' : 'DEBIT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: color,
                  ),
                ),
                Text(
                  '$sign${Formatters.currency(t.amount)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    t.description ?? '—',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
                Text(
                  'Bal. ${Formatters.currency(runningBalance)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.neutral600,
                  ),
                ),
              ],
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

  Future<void> _openTransactionMenu(
    BuildContext context,
    ClientTransaction t,
    double currentBalance,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(),
      builder: (sheetContext) {
        final color = t.type == TransactionType.credit
            ? AppColors.text
            : AppColors.accent700;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${Formatters.date(t.occurredAt)} · ${Formatters.time(t.occurredAt)}'
                  '${t.paymentMethod != null ? ' · ${t.paymentMethod}' : ''}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: AppColors.neutral600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${t.type == TransactionType.credit ? 'Credit + ' : 'Debit − '}${Formatters.currency(t.amount)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: color,
                  ),
                ),
                if (t.description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      t.description!,
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
                    child: const Text('Edit transaction'),
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
                    child: const Text('Delete transaction'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted) return;
    if (action == 'edit') {
      await showTransactionSheet(
        context,
        clientId: t.clientId,
        mode: t.type == TransactionType.credit
            ? TransactionSheetMode.credit
            : TransactionSheetMode.debit,
        currentBalance: currentBalance,
        editing: t,
      );
    } else if (action == 'delete') {
      await _confirmDeleteTransaction(context, t, currentBalance);
    }
  }

  Future<void> _confirmDeleteTransaction(
    BuildContext context,
    ClientTransaction t,
    double currentBalance,
  ) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: 'Are you sure you want to delete this transaction?',
      message:
          "This will change the client's outstanding balance. "
          'The record is kept in the audit trail, not erased.',
    );

    if (!confirmed) return;
    try {
      await ref.read(clientsRepositoryProvider).softDeleteTransaction(t.id);
      final effect = t.type == TransactionType.credit ? -t.amount : t.amount;
      ref.invalidate(clientDetailProvider(t.clientId));
      ref.invalidate(clientSummariesProvider);
      ref.invalidate(periodTotalsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Transaction deleted · balance now '
              '${Formatters.currency(currentBalance + effect)}',
            ),
          ),
        );
      }
    } on ClientRepositoryException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
