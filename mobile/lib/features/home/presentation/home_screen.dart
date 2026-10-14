import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/animated_counter.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/rank_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/staggered.dart';
import '../../../core/widgets/timer_ring.dart';
import '../../auth/application/auth_controller.dart';
import '../../calories/application/calorie_providers.dart';
import '../../programs/application/program_providers.dart';
import '../../progress/application/progress_providers.dart';
import '../../workout/application/active_workout_controller.dart';
import '../../workout/presentation/widgets/today_cards.dart';

/// Weeks of volume shown on the dashboard chart.
const _dashboardWeeks = 8;

/// Home dashboard: streak, rank, today's workout, volume, calories, latest PRs.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final next = ref.read(activeProgramProvider).value;
    await ref.read(activeWorkoutProvider.notifier).start(day: next?.nextDay, programId: next?.program?.id);
    if (context.mounted) await context.push(Routes.activeWorkout);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final active = ref.watch(activeWorkoutProvider);
    final program = ref.watch(activeProgramProvider);
    final c = context.colors;

    final items = <Widget>[
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Fmt.greeting(), style: context.text.bodyLarge?.copyWith(color: c.textSecondary)),
                Text(user?.username ?? '', style: context.text.displaySmall, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          PressableScale(
            onTap: () => context.go(Routes.profile),
            semanticLabel: 'Open profile',
            child: CircleAvatar(
              radius: AppSizes.avatar / 2,
              backgroundColor: c.accentSoft,
              child: Text(user?.initials ?? '', style: context.text.titleLarge),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xl),
      const IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _StreakCard()),
            SizedBox(width: AppSpacing.md),
            Expanded(child: _RankCard()),
          ],
        ),
      ),
      const SectionHeader(title: 'Today'),
      if (active != null)
        ResumeWorkoutCard(workout: active)
      else
        program.when(
          loading: () => const Shimmer(
            child: SkeletonBox(height: AppSizes.chartHeight, radius: AppRadii.lgAll),
          ),
          error: (_, _) => _QuickStartCard(onStart: () => _start(context, ref)),
          data: (p) => p.program == null || p.nextDay == null
              ? _QuickStartCard(onStart: () => _start(context, ref))
              : NextDayCard(program: p.program!, day: p.nextDay!, onStart: () => _start(context, ref)),
        ),
      const _VolumeSection(),
      const _CaloriesCard(),
      const _LatestRecords(),
    ];

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              ref
                ..invalidate(ranksProvider)
                ..invalidate(latestRecordsProvider)
                ..invalidate(activeProgramProvider)
                ..invalidate(calorieDayProvider)
                ..invalidate(statsOverviewProvider);
              await ref.read(authControllerProvider.notifier).refreshUser();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.xl,
                AppSpacing.screen,
                AppSpacing.bottomNavClearance,
              ),
              children: [for (var i = 0; i < items.length; i++) items[i].staggered(i)],
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends ConsumerWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final o = ref.watch(statsOverviewProvider(_dashboardWeeks)).value;
    final weeks = o?.streakWeeks ?? 0;
    return GlassCard(
      onTap: () => context.go(Routes.progress),
      semanticLabel: '$weeks week streak',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
                Icons.local_fire_department_rounded,
                color: weeks > 0 ? c.accentStart : c.textMuted,
                size: AppSizes.iconLg,
              )
              .animate(onPlay: (ctl) => weeks > 0 ? ctl.repeat(reverse: true) : null)
              .scaleXY(
                begin: 1,
                end: 1 + AppMotion.breatheScale * 3,
                duration: AppMotion.breatheCycle,
                curve: AppMotion.breathe,
              ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedCounter(value: weeks, style: context.numbers.large),
              const SizedBox(width: AppSpacing.xs),
              Text(weeks == 1 ? 'week' : 'weeks', style: context.numbers.unit),
            ],
          ),
          Text(
            weeks == 0 ? 'Train this week to start a streak' : '${Fmt.count(o?.streakDays ?? 0, 'day')} in a row',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RankCard extends ConsumerWidget {
  const _RankCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overall = ref.watch(ranksProvider).value?.overall;
    final ranked = overall?.ranked ?? false;
    return GlassCard(
      onTap: () => context.push(Routes.ranks),
      semanticLabel: 'Overall rank ${overall?.tier ?? 'unranked'}',
      child: Column(
        children: [
          RankBadge(
            tierIndex: ranked ? overall!.tierIndex : null,
            tierName: overall?.tier,
            progress: overall?.progress ?? 0,
            size: AppSizes.rankBadgeSm * 1.3,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ranked ? overall!.tier! : 'Unranked',
            style: context.text.titleMedium?.copyWith(color: ranked ? TierColors.of(overall!.tierIndex).primary : null),
          ),
          Text('Overall rank', style: context.text.bodySmall),
        ],
      ),
    );
  }
}

class _QuickStartCard extends StatelessWidget {
  const _QuickStartCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ready to train?', style: context.text.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text('Start an empty workout, or follow a program for a plan every day.', style: context.text.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          GradientButton(label: 'Start workout', icon: Icons.bolt_rounded, onPressed: onStart),
          const SizedBox(height: AppSpacing.sm),
          GradientButton(
            label: 'Browse programs',
            variant: GradientButtonVariant.ghost,
            onPressed: () => context.push(Routes.programs),
          ),
        ],
      ),
    );
  }
}

class _VolumeSection extends ConsumerWidget {
  const _VolumeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(currentUserProvider)?.unit ?? WeightUnit.kg;
    final overview = ref.watch(statsOverviewProvider(_dashboardWeeks));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Weekly volume', actionLabel: 'Progress', onAction: () => context.go(Routes.progress)),
        overview.when(
          loading: () => const Shimmer(
            child: SkeletonBox(height: AppSizes.chartHeight, radius: AppRadii.lgAll),
          ),
          error: (e, _) => ErrorState(
            error: e,
            compact: true,
            onRetry: () => ref.invalidate(statsOverviewProvider(_dashboardWeeks)),
          ),
          data: (o) {
            final thisWeek = o.weekly.isEmpty ? 0.0 : o.weekly.last.volume;
            return GlassCard(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.md, bottom: AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        AnimatedCounter(
                          value: Units.fromKg(thisWeek, unit),
                          style: context.numbers.large,
                          formatter: (v) => Fmt.integer(v),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text('${unit.label} this week', style: context.numbers.unit),
                      ],
                    ),
                  ),
                  AnimatedBarChart(
                    height: AppSizes.chartHeightSm,
                    values: [for (final w in o.weekly) Units.fromKg(w.volume, unit)],
                    // Every third week, counted back from the current one, so labels never collide.
                    bottomLabel: (i) {
                      final fromEnd = o.weekly.length - 1 - i;
                      if (fromEnd == 0) return 'Now';
                      return fromEnd % 3 == 0 ? Fmt.dayMonth(o.weekly[i].weekStart) : '';
                    },
                    valueLabel: (v) => '${Units.volume(Units.toKg(v, unit), unit)} ${unit.label}',
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CaloriesCard extends ConsumerWidget {
  const _CaloriesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(calorieDayProvider(todayKey())).value;
    final c = context.colors;
    final target = day?.targetKcal;
    final budget = (target ?? 0) + (day?.burnedKcal ?? 0);
    final eaten = day?.consumed.kcal ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Calories'),
        GlassCard(
          onTap: () => context.push(Routes.calories),
          semanticLabel: 'Calories today',
          child: Row(
            children: [
              TimerRing(
                progress: budget <= 0 ? 0 : eaten / budget,
                size: AppSizes.rankBadgeMd,
                strokeWidth: AppSizes.ringStrokeSm * 1.5,
                animationDuration: AppMotion.ring,
                curve: AppMotion.emphasized,
                showTip: false,
                child: Icon(Icons.restaurant_rounded, color: c.textSecondary),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        AnimatedCounter(value: eaten, style: context.numbers.large, formatter: (v) => Fmt.integer(v)),
                        const SizedBox(width: AppSpacing.xs),
                        Text(target == null ? 'kcal' : '/ ${Fmt.integer(budget)}', style: context.numbers.unit),
                      ],
                    ),
                    Text(
                      day == null
                          ? 'Track what you eat'
                          : '${Fmt.integer(day.burnedKcal)} kcal burned in workouts (est.)',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textMuted),
            ],
          ),
        ),
      ],
    );
  }
}

class _LatestRecords extends ConsumerWidget {
  const _LatestRecords();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(latestRecordsProvider);
    final unit = ref.watch(currentUserProvider)?.unit ?? WeightUnit.kg;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Latest PRs'),
        records.when(
          loading: () => const Shimmer(
            child: SkeletonBox(height: AppSizes.chartHeightSm, radius: AppRadii.lgAll),
          ),
          error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(latestRecordsProvider)),
          data: (list) => list.isEmpty
              ? const GlassCard(
                  child: EmptyState(
                    compact: true,
                    icon: Icons.emoji_events_outlined,
                    title: 'No records yet',
                    message: 'Beat a previous best and it shows up here.',
                  ),
                )
              : SizedBox(
                  height: AppSizes.chartHeightSm,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
                    itemBuilder: (_, i) {
                      final r = list[i];
                      return SizedBox(
                        width: AppSizes.chartHeight * 0.8,
                        child: GlassCard(
                          blur: false,
                          onTap: r.exerciseId == null ? null : () => context.push(Routes.exercise(r.exerciseId!)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.emoji_events_rounded, color: TierColors.gold.primary),
                              const Spacer(),
                              Text(
                                r.type == 'maxRepsAtWeight' ? '${r.value.round()} reps' : Units.weight(r.value, unit),
                                style: context.numbers.medium,
                              ),
                              Text(
                                r.exerciseName ?? 'Exercise',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.titleSmall,
                              ),
                              Text(
                                '${_recordLabel(r.type)} · ${Fmt.relativeDay(r.achievedAt)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodySmall,
                              ),
                            ],
                          ),
                        ).staggered(i, horizontal: true),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  static String _recordLabel(String type) => switch (type) {
    'maxWeight' => 'Heaviest',
    'e1rm' => 'Est. 1RM',
    'maxVolumeSet' => 'Best set',
    _ => 'Rep PR',
  };
}
