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
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/rank_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/staggered.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../auth/application/auth_controller.dart';
import '../data/workout_models.dart';

/// Shown after finishing: duration, volume, sets, calories, PRs and rank-ups.
class WorkoutSummaryScreen extends ConsumerWidget {
  const WorkoutSummaryScreen({super.key, required this.result});

  final WorkoutResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final unit = ref.watch(currentUserProvider)?.unit ?? WeightUnit.kg;
    final rankUps = result.rankChanges.where((r) => r.up).toList();

    final tiles = <Widget>[
      StatTile(
        label: 'Duration',
        value: result.duration.inMinutes,
        unit: 'min',
        icon: Icons.timer_rounded,
      ),
      StatTile(
        label: 'Volume',
        value: Units.fromKg(result.volumeKg, unit),
        unit: unit.label,
        icon: Icons.stacked_bar_chart_rounded,
        formatter: (v) => Fmt.integer(v),
      ),
      StatTile(label: 'Sets', value: result.completedSets, icon: Icons.check_circle_rounded, caption: Fmt.count(result.exerciseCount, 'exercise')),
      StatTile(
        label: 'Calories',
        value: result.caloriesKcal ?? 0,
        unit: 'kcal',
        icon: Icons.local_fire_department_rounded,
        caption: result.caloriesKcal == null ? 'Calculated when synced' : 'Estimate',
      ),
    ];

    final sections = <Widget>[
      Center(
        child: Container(
          width: AppSizes.rankBadgeSm * 1.3,
          height: AppSizes.rankBadgeSm * 1.3,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: c.accentGradient,
            boxShadow: [BoxShadow(color: c.accentGlow, blurRadius: AppSizes.shadowBlur * 2)],
          ),
          child: Icon(Icons.check_rounded, size: AppSizes.iconXl, color: c.onAccent),
        ).animate().scaleXY(begin: 0, end: 1, duration: AppMotion.slower, curve: AppMotion.elastic),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text('Workout complete', textAlign: TextAlign.center, style: context.text.displaySmall),
      Text(result.name, textAlign: TextAlign.center, style: context.text.bodyLarge?.copyWith(color: c.textSecondary)),
      if (!result.synced) ...[
        const SizedBox(height: AppSpacing.lg),
        GlassCard(
          child: Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: c.warning),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  "Saved on your phone. It'll upload automatically when you're back online — PRs and ranks update then.",
                  style: context.text.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
      StatGrid(children: [for (var i = 0; i < tiles.length; i++) tiles[i].staggered(i)]),
      if (result.newRecords.isNotEmpty) ...[
        SectionHeader(title: 'New personal records', actionLabel: 'Replay', onAction: () => context.push(Routes.prCelebration, extra: result)),
        for (final r in result.newRecords)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: GlassCard(
              child: Row(
                children: [
                  Icon(Icons.emoji_events_rounded, color: TierColors.gold.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.exerciseName, style: context.text.titleSmall),
                        Text(r.title, style: context.text.bodySmall),
                      ],
                    ),
                  ),
                  Text(
                    r.type == 'maxRepsAtWeight' ? '${r.value.round()} reps' : Units.weight(r.value, unit),
                    style: context.numbers.small.copyWith(color: c.accent),
                  ),
                ],
              ),
            ),
          ),
      ],
      if (rankUps.isNotEmpty) ...[
        const SectionHeader(title: 'Rank up!'),
        for (final r in rankUps)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: GlassCard(
              highlighted: true,
              child: Row(
                children: [
                  RankBadge(tierIndex: r.toIndex, tierName: r.to, size: AppSizes.rankBadgeSm, showProgress: false),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name, style: context.text.titleMedium),
                        Text(
                          r.from == null ? 'Ranked ${r.to}' : '${r.from} → ${r.to}',
                          style: context.text.bodyMedium?.copyWith(color: TierColors.of(r.toIndex).primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
      const SizedBox(height: AppSpacing.xl),
      GradientButton(label: 'Done', icon: Icons.home_rounded, onPressed: () => context.go(Routes.home)),
      if (result.sessionId != null) ...[
        const SizedBox(height: AppSpacing.sm),
        GradientButton(
          label: 'View workout',
          variant: GradientButtonVariant.ghost,
          onPressed: () => context.push(Routes.workoutDetail(result.sessionId!)),
        ),
      ],
    ];

    return PopScope(
      // Back from the summary goes home rather than to the finished workout.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.home);
      },
      child: Scaffold(
        body: AppBackground(
          intensity: 1.5,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xxl, AppSpacing.screen, AppSpacing.xl),
              children: sections,
            ),
          ),
        ),
      ),
    );
  }
}
