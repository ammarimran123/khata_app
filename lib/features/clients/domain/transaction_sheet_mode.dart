import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/client_transaction.dart';

/// The four entry points that create a client-ledger transaction. All four
/// end up as a plain credit/debit row — 'receive' and 'pay' are just
/// friendlier framing for "a debit that settles what they owe you" and "a
/// credit that settles what you owe them", matching the design exactly.
enum TransactionSheetMode { credit, debit, receive, pay }

class TransactionSheetSpec {
  const TransactionSheetSpec({
    required this.kicker,
    required this.title,
    required this.color,
    required this.type,
    required this.descriptionPlaceholder,
  });

  final String kicker;
  final String title;
  final Color color;
  final TransactionType type;
  final String descriptionPlaceholder;
}

TransactionSheetSpec transactionSheetSpec(TransactionSheetMode mode) {
  return switch (mode) {
    TransactionSheetMode.credit => const TransactionSheetSpec(
      kicker: 'Client ledger',
      title: 'Add Credit',
      color: AppColors.text,
      type: TransactionType.credit,
      descriptionPlaceholder: 'Goods supplied on credit',
    ),
    TransactionSheetMode.debit => const TransactionSheetSpec(
      kicker: 'Client ledger',
      title: 'Add Debit',
      color: AppColors.accent700,
      type: TransactionType.debit,
      descriptionPlaceholder: 'Goods purchased',
    ),
    TransactionSheetMode.receive => const TransactionSheetSpec(
      kicker: 'Settlement',
      title: 'Receive Payment',
      color: AppColors.text,
      type: TransactionType.debit,
      descriptionPlaceholder: 'Payment received',
    ),
    TransactionSheetMode.pay => const TransactionSheetSpec(
      kicker: 'Settlement',
      title: 'Make Payment',
      color: AppColors.accent700,
      type: TransactionType.credit,
      descriptionPlaceholder: 'Payment made',
    ),
  };
}
