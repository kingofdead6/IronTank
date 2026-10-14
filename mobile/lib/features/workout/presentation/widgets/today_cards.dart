import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../exercises/presentation/widgets/exercise_image.dart';
import '../../../programs/data/program.dart';
import '../../data/workout_models.dart';

/// Live "in progress" card with the running session clock.
class ResumeWorkoutCard extends ConsumerWidget {
  const ResumeWorkoutCard({super.key, required this.workout});

  final ActiveWorkout workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = nowFrom(ref.watch(clockProvider));
    final c = context.colors;
    return GlassCard(
      highlighted: true,
      onTap: () => context.push(Routes.activeWorkout),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSpacing.sm,
                height: AppSpacing.sm,
                decoration: BoxDecoration(shape: BoxShape.circle, color: c.success),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('IN PROGRESS', style: context.text.labelSmall?.copyWith(color: c.success)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(workout.name, style: context.text.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(Fmt.clock(workout.activeDuration(now)), style: context.numbers.large),
              const SizedBox(width: AppSpacing.md),
              Text('${workout.completedSets}/${workout.totalSets} sets', style: context.text.bodyMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          GradientButton(label: 'Resume workout', icon: Icons.play_arrow_rounded, onPressed: () => context.push(Routes.activeWorkout)),
        ],
      ),
    );
  }
}

/// The active program's next day with a Start button.
class NextDayCard extends StatelessWidget {
  const NextDayCard({super.key, required this.program, required this.day, required this.onStart});

  final Program program;
  final ProgramDay day;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassCard(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('UP NEXT · ${program.name.toUpperCase()}', style: context.text.labelSmall?.copyWith(color: c.accent)),
          const SizedBox(height: AppSpacing.sm),
          Text(day.name, style: context.text.headlineMedium),
          Text('${Fmt.count(day.exercises.length, 'exercise')} · ${Fmt.count(day.totalSets, 'set')}', style: context.text.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          for (final e in day.exercises.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  ExerciseThumb(url: e.exercise.image, size: AppSizes.iconXl),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(e.exercise.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodyLarge)),
                  Text(e.prescription, style: context.numbers.small.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
          if (day.exercises.length > 4)
            Text('+${day.exercises.length - 4} more', style: context.text.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          GradientButton(label: 'Start ${day.name}', icon: Icons.bolt_rounded, onPressed: onStart),
        ],
      ),
    );
  }
}

/// Prompt to pick a program when none is active.
class NoProgramCard extends StatelessWidget {
  const NoProgramCard({super.key, required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: EmptyState(
      compact: true,
      icon: Icons.auto_awesome_rounded,
      title: 'Follow a program',
      message: "Pick a template and we'll line up each day's workout for you.",
      actionLabel: 'Browse programs',
      onAction: onBrowse,
    ),
  );
}
