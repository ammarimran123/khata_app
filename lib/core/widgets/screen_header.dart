import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The large title + 2px black rule that opens every top-level screen in
/// the design (Clients, Reports, More, ...).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            ?trailing,
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        Container(height: AppSpacing.ruleWidth, color: AppColors.text),
      ],
    );
  }
}
