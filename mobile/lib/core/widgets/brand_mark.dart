import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// IronRank logo: gradient rounded square with a bolt, plus optional wordmark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = AppSizes.iconXl * 1.6, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: c.accentGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [BoxShadow(color: c.accentGlow, blurRadius: size * 0.5, offset: Offset(0, size * 0.12))],
      ),
      child: Icon(Icons.bolt_rounded, color: c.onAccent, size: size * 0.62),
    );
    if (!showWordmark) return mark;
    return Semantics(
      label: 'IronRank',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          const SizedBox(height: AppSpacing.lg),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'IRON', style: context.text.headlineMedium?.copyWith(letterSpacing: 4)),
                TextSpan(
                  text: 'RANK',
                  style: context.text.headlineMedium?.copyWith(
                    letterSpacing: 4,
                    foreground: Paint()..shader = c.accentGradient.createShader(const Rect.fromLTWH(0, 0, 120, 30)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
