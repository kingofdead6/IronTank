import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/exercise.dart';
import 'exercise_image.dart';

/// Grid tile: photo (hero source), name, primary muscle and equipment.
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({super.key, required this.exercise, required this.onTap});

  final Exercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassCard(
      onTap: onTap,
      blur: false,
      padding: EdgeInsets.zero,
      semanticLabel: exercise.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: exercise.heroTag,
                  child: ExerciseImage(url: exercise.thumbnail),
                ),
                if (exercise.isCustom || exercise.liftKey != null)
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: _Badge(
                      label: exercise.isCustom ? 'CUSTOM' : 'RANKED',
                      icon: exercise.isCustom ? Icons.edit_rounded : Icons.military_tech_rounded,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  [
                    if (exercise.primaryMuscles.isNotEmpty) labelize(exercise.primaryMuscles.first),
                    labelize(exercise.equipment),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(gradient: c.accentGradient, borderRadius: AppRadii.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconSm * 0.75, color: c.onAccent),
          const SizedBox(width: AppSpacing.xxs),
          Text(label, style: context.text.labelSmall?.copyWith(color: c.onAccent)),
        ],
      ),
    );
  }
}

/// Compact list row (pickers, program builder).
class ExerciseListTile extends StatelessWidget {
  const ExerciseListTile({super.key, required this.exercise, this.onTap, this.trailing, this.selected = false});

  final Exercise exercise;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      blur: false,
      highlighted: selected,
      padding: const EdgeInsets.all(AppSpacing.sm),
      semanticLabel: exercise.name,
      child: Row(
        children: [
          ExerciseThumb(url: exercise.thumbnail),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  [...exercise.primaryMuscles.take(2).map(labelize), labelize(exercise.equipment)].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
