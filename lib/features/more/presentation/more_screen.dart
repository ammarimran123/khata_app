import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/presentation/auth_action_controller.dart';
import '../../auth/presentation/auth_providers.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  static const _comingSoon = [
    (label: 'Income & Expense', note: 'Records that drive profit and loss'),
    (label: 'Reminders', note: 'Follow up with clients on time'),
    (label: 'Audit trail', note: 'Every edit and deletion, with who and when'),
    (label: 'Backup & restore', note: 'Automatic nightly backups'),
    (label: 'Currency', note: 'PKR (Rs.)'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final actionState = ref.watch(authActionControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenHeader(title: 'More'),
            if (user?.email != null) ...[
              const SizedBox(height: AppSpacing.s4),
              Text(
                'Signed in as ${user!.email}',
                style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
              ),
            ],
            Expanded(
              child: ListView(
                children: [
                  for (final row in _comingSoon)
                    _MoreRow(
                      label: row.label,
                      note: row.note,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${row.label} is coming soon.')),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: actionState.isLoading
                      ? null
                      : () => ref
                          .read(authActionControllerProvider.notifier)
                          .signOut(),
                  child: actionState.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign Out'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.label, required this.note, required this.onTap});

  final String label;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.neutral600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.neutral600, size: 20),
          ],
        ),
      ),
    );
  }
}
