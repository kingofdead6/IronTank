import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/motion.dart';
import 'glass_card.dart';

/// Large selectable option card (onboarding choices, goals, units).
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: GlassCard(
        onTap: onTap,
        highlighted: selected,
        semanticLabel: title,
        child: Row(
          children: [
            if (icon != null) ...[
              AnimatedContainer(
                duration: AppMotion.medium,
                curve: AppMotion.standard,
                width: AppSizes.avatar,
                height: AppSizes.avatar,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected ? c.accentGradient : null,
                  color: selected ? null : c.glassFill,
                ),
                child: Icon(icon, color: selected ? c.onAccent : c.textSecondary, size: AppSizes.iconMd),
              ),
              const SizedBox(width: AppSpacing.lg),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(subtitle!, style: context.text.bodySmall),
                  ],
                ],
              ),
            ),
            AnimatedScale(
              duration: AppMotion.medium,
              curve: AppMotion.overshoot,
              scale: selected ? 1 : 0,
              child: Icon(Icons.check_circle_rounded, color: c.accent, size: AppSizes.iconMd),
            ),
          ],
        ),
      ),
    );
  }
}
