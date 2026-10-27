import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/client_summary.dart';
import '../../domain/transaction_sheet_mode.dart';
import 'transaction_sheet.dart';

class ClientListTile extends StatelessWidget {
  const ClientListTile({super.key, required this.summary});

  final ClientSummary summary;

  @override
  Widget build(BuildContext context) {
    final balance = summary.balance;
    final color = AppColors.ledgerAmountColor(balance);
    final status = balance > 0
        ? 'Receivable'
        : balance < 0
        ? 'Payable'
        : 'Settled';
    final sentence = balance > 0
        ? 'You will receive ${Formatters.currency(balance)}'
        : balance < 0
        ? 'You owe ${Formatters.currency(balance)}'
        : 'Account settled';

    return InkWell(
      onTap: () => context.push('/clients/${summary.client.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    summary.client.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  Formatters.signedCurrency(balance),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  summary.client.phone,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.neutral600,
                  ),
                ),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              sentence,
              style: const TextStyle(fontSize: 12, color: AppColors.neutral700),
            ),
            const SizedBox(height: 2),
            Text(
              'Last transaction: ${Formatters.date(summary.lastActivity)}',
              style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    label: '+ Credit',
                    borderColor: AppColors.accent,
                    background: AppColors.accent100,
                    foreground: AppColors.accent700,
                    onTap: () => showTransactionSheet(
                      context,
                      clientId: summary.client.id,
                      mode: TransactionSheetMode.credit,
                      currentBalance: balance,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _QuickActionButton(
                    label: '− Debit',
                    borderColor: AppColors.text,
                    background: Colors.transparent,
                    foreground: AppColors.text,
                    onTap: () => showTransactionSheet(
                      context,
                      clientId: summary.client.id,
                      mode: TransactionSheetMode.debit,
                      currentBalance: balance,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _QuickActionButton(
                    label: balance < 0 ? 'Pay' : 'Receive',
                    borderColor: AppColors.neutral400,
                    background: Colors.transparent,
                    foreground: AppColors.neutral800,
                    onTap: () => showTransactionSheet(
                      context,
                      clientId: summary.client.id,
                      mode: balance < 0
                          ? TransactionSheetMode.pay
                          : TransactionSheetMode.receive,
                      currentBalance: balance,
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

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.borderColor,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color borderColor;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(border: Border.all(color: borderColor, width: 2)),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
