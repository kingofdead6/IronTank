import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../exercises/data/exercise.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/program.dart';

/// Program summary card: name, description, day pills and focus muscles.
class ProgramCard extends StatelessWidget {
  const ProgramCard({super.key, required this.program, required this.onTap});

  final Program program;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final focus = program.focusMuscles.take(3).map(labelize).join(' · ');
    return GlassCard(
      onTap: onTap,
      highlighted: program.isActive,
      semanticLabel: '${program.name}${program.isActive ? ', active' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(program.name, style: context.text.titleLarge)),
              if (program.isActive) const _Pill(label: 'ACTIVE', filled: true),
              if (program.isTemplate) const _Pill(label: 'TEMPLATE', filled: false),
            ],
          ),
          if (program.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(program.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [for (final d in program.days) _DayPill(label: d.name)],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.calendar_view_week_rounded, size: AppSizes.iconSm, color: c.textMuted),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${Fmt.count(program.days.length, 'day')} · ${Fmt.count(program.exerciseCount, 'exercise')} · ${program.weeks} wk',
                style: context.text.bodySmall,
              ),
              const Spacer(),
              if (focus.isNotEmpty)
                Flexible(
                  child: Text(focus, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(color: c.accent)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.filled});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(left: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        gradient: filled ? c.accentGradient : null,
        border: filled ? null : Border.all(color: c.glassBorder),
        borderRadius: AppRadii.pillAll,
      ),
      child: Text(label, style: context.text.labelSmall?.copyWith(color: filled ? c.onAccent : c.textSecondary)),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(color: c.glassFill, borderRadius: AppRadii.smAll),
      child: Text(label, style: context.text.labelMedium),
    );
  }
}
