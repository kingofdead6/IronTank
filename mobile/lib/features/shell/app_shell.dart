import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/glass_card.dart';
import '../workout/application/active_workout_controller.dart';

/// Hosts the bottom-nav tabs. Each tab keeps its own navigation stack.
/// While a workout is running, a mini bar above the nav returns to it.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const workoutTabIndex = 2;

  static const _items = [
    AppNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    AppNavItem(icon: Icons.fitness_center_outlined, activeIcon: Icons.fitness_center_rounded, label: 'Exercises'),
    AppNavItem(icon: Icons.play_arrow_rounded, activeIcon: Icons.bolt_rounded, label: 'Workout'),
    AppNavItem(icon: Icons.insights_outlined, activeIcon: Icons.insights_rounded, label: 'Progress'),
    AppNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeWorkoutProvider.select((w) => w != null));
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: AppMotion.slow,
            switchInCurve: AppMotion.emphasized,
            transitionBuilder: (child, a) => SizeTransition(sizeFactor: a, child: FadeTransition(opacity: a, child: child)),
            child: active ? const _ActiveWorkoutBar() : const SizedBox(width: double.infinity),
          ),
          AppBottomNav(
            items: _items,
            currentIndex: shell.currentIndex,
            emphasizedIndex: workoutTabIndex,
            // Re-tapping the current tab pops it back to its root.
            onSelect: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          ),
        ],
      ),
    );
  }
}

class _ActiveWorkoutBar extends ConsumerWidget {
  const _ActiveWorkoutBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(activeWorkoutProvider);
    if (workout == null) return const SizedBox.shrink();
    final now = nowFrom(ref.watch(clockProvider));
    final c = context.colors;
    final rest = workout.rest;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      child: GlassCard(
        onTap: () => context.push(Routes.activeWorkout),
        borderRadius: AppRadii.xlAll,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        semanticLabel: 'Workout in progress. Open workout.',
        child: Row(
          children: [
            Icon(rest == null ? Icons.bolt_rounded : Icons.timer_rounded, color: c.accent),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                rest == null ? workout.name : 'Rest · ${Fmt.clock(rest.remaining(now))}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall,
              ),
            ),
            Text(Fmt.clock(workout.activeDuration(now)), style: context.numbers.small),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.keyboard_arrow_up_rounded, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}
