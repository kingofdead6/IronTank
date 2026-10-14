import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/staggered.dart';
import '../../auth/application/auth_controller.dart';
import '../../programs/application/program_providers.dart';
import '../../programs/data/program.dart';
import '../application/active_workout_controller.dart';
import '../application/workout_providers.dart';
import '../data/workout_history.dart';
import '../data/workout_repository.dart';
import 'widgets/today_cards.dart';

/// Workout tab: resume / start today's program day / empty workout, plus history.
class WorkoutHubScreen extends ConsumerStatefulWidget {
  const WorkoutHubScreen({super.key});

  @override
  ConsumerState<WorkoutHubScreen> createState() => _WorkoutHubScreenState();
}

class _WorkoutHubScreenState extends ConsumerState<WorkoutHubScreen> {
  @override
  void initState() {
    super.initState();
    // Opportunistically upload workouts saved offline.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync(silent: true));
  }

  Future<void> _sync({bool silent = false}) async {
    final synced = await ref.read(activeWorkoutProvider.notifier).syncPending();
    if (!mounted) return;
    setState(() {});
    if (synced > 0) {
      showAppSnack(context, '${Fmt.count(synced, 'workout')} synced');
    } else if (!silent && ref.read(workoutRepositoryProvider).pendingCount > 0) {
      showAppSnack(context, 'Still offline — will retry later', error: true);
    }
  }

  Future<void> _start({ProgramDay? day, String? programId}) async {
    await ref.read(activeWorkoutProvider.notifier).start(day: day, programId: programId);
    if (mounted) await context.push(Routes.activeWorkout);
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeWorkoutProvider);
    final program = ref.watch(activeProgramProvider);
    final recent = ref.watch(recentWorkoutsProvider);
    final pending = ref.read(workoutRepositoryProvider).pendingCount;
    final unit = ref.watch(currentUserProvider)?.unit ?? WeightUnit.kg;

    final top = <Widget>[
      Text('Workout', style: context.text.displaySmall),
      const SizedBox(height: AppSpacing.xl),
      if (pending > 0) ...[
        _PendingBanner(count: pending, onRetry: _sync),
        const SizedBox(height: AppSpacing.md),
      ],
      if (active != null)
        ResumeWorkoutCard(workout: active)
      else
        program.when(
          loading: () => const Shimmer(child: SkeletonBox(height: AppSizes.chartHeight, radius: AppRadii.lgAll)),
          error: (_, _) => NoProgramCard(onBrowse: () => context.push(Routes.programs)),
          data: (p) => p.program == null || p.nextDay == null
              ? NoProgramCard(onBrowse: () => context.push(Routes.programs))
              : NextDayCard(program: p.program!, day: p.nextDay!, onStart: () => _start(day: p.nextDay, programId: p.program!.id)),
        ),
      const SizedBox(height: AppSpacing.md),
      if (active == null)
        GradientButton(
          label: 'Start empty workout',
          icon: Icons.add_rounded,
          variant: GradientButtonVariant.outlined,
          onPressed: _start,
        ),
      const SizedBox(height: AppSpacing.md),
      GlassCard(
        onTap: () => context.push(Routes.programs),
        child: Row(
          children: [
            Icon(Icons.view_agenda_rounded, color: context.colors.accent),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text('Programs & templates', style: context.text.titleSmall)),
            Icon(Icons.chevron_right_rounded, color: context.colors.textMuted),
          ],
        ),
      ),
      const SectionHeader(title: 'History'),
    ];

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(activeProgramProvider);
              ref.invalidate(recentWorkoutsProvider);
              await _sync(silent: true);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xl, AppSpacing.screen, AppSpacing.bottomNavClearance),
              children: [
                for (var i = 0; i < top.length; i++) top[i].staggered(i),
                ...recent.when(
                  loading: () => [const SkeletonList(count: 3, padding: EdgeInsets.zero)],
                  error: (e, _) => [ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(recentWorkoutsProvider))],
                  data: (list) => list.isEmpty
                      ? [
                          const EmptyState(
                            compact: true,
                            icon: Icons.history_rounded,
                            title: 'No workouts yet',
                            message: 'Finished workouts show up here.',
                          ),
                        ]
                      : [
                          for (var i = 0; i < list.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: WorkoutHistoryTile(workout: list[i], unit: unit).staggered(i),
                            ),
                        ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count, required this.onRetry});

  final int count;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.cloud_upload_outlined, color: c.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text('${Fmt.count(count, 'workout')} waiting to sync', style: context.text.bodyMedium)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// A finished workout in the history list.
class WorkoutHistoryTile extends StatelessWidget {
  const WorkoutHistoryTile({super.key, required this.workout, required this.unit});

  final WorkoutSummary workout;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassCard(
      blur: false,
      onTap: () => context.push(Routes.workoutDetail(workout.id)),
      child: Row(
        children: [
          Container(
            width: AppSizes.avatar,
            height: AppSizes.avatar,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadii.mdAll),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${workout.startedAt.toLocal().day}', style: context.numbers.small),
                Text(Fmt.dayMonth(workout.startedAt).split(' ').first.toUpperCase(), style: context.text.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(workout.name, style: context.text.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${Fmt.duration(Duration(seconds: workout.durationSec))} · ${Units.volume(workout.totalVolume, unit)} ${unit.label} · ${Fmt.count(workout.setCount, 'set')}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          if (workout.prCount > 0)
            AnimatedContainer(
              duration: AppMotion.medium,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
              decoration: BoxDecoration(color: TierColors.gold.primary.withValues(alpha: AppOpacity.subtle), borderRadius: AppRadii.pillAll),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_rounded, size: AppSizes.iconSm, color: TierColors.gold.primary),
                  const SizedBox(width: AppSpacing.xxs),
                  Text('${workout.prCount}', style: context.text.labelMedium?.copyWith(color: TierColors.gold.primary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
