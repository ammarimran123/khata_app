import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The filter/period toggle pill used throughout the design (client
/// status filters, ledger range filters, P&L period chips, ...) — solid
/// black when selected, outlined neutral otherwise.
class KhataChip extends StatelessWidget {
  const KhataChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.text : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.text : AppColors.neutral400,
              width: 2,
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: selected ? Colors.white : AppColors.neutral800,
            ),
          ),
        ),
      ),
    );
  }
}
