import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/presentation/auth_providers.dart';
import 'widgets/ruled_monogram.dart';

/// The brand moment (design variant 1B, "Ruled monogram") shown for a
/// minimum display duration while the app decides where to send the
/// user — this isn't reporting real load progress (there's no multi-stage
/// local-data restore to represent, unlike the original brand mock), just
/// giving the mark room to register before the redirect fires.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _minDisplay = Duration(milliseconds: 1300);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _minDisplay)
      ..forward();
    _navigateNext();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(_minDisplay);
    if (!mounted) return;
    final loggedIn = ref.read(authRepositoryProvider).currentUser != null;
    context.go(loggedIn ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Est. ledger · offline first',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: AppColors.neutral600,
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              Container(height: AppSpacing.ruleWidth, color: AppColors.text),
              const Spacer(),
              const RuledMonogram(size: 112),
              const SizedBox(height: AppSpacing.s6),
              const Text(
                'HS TRADERS',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Khata, kept straight.',
                style: TextStyle(fontSize: 14, color: AppColors.neutral700),
              ),
              const Spacer(),
              Container(height: AppSpacing.ruleWidth, color: AppColors.text),
              const SizedBox(height: AppSpacing.s3),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Stack(
                  children: [
                    Container(height: 4, color: AppColors.neutral300),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _controller.value.clamp(0.04, 1.0),
                        child: Container(height: 4, color: AppColors.accent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LOADING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.neutral600,
                    ),
                  ),
                  Text(
                    'v1.0',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.neutral600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
