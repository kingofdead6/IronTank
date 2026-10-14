import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Near-black canvas with two soft accent glows, giving the glass cards
/// something to blur. Wrap screen bodies with it.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.intensity = 1});

  final Widget child;

  /// Scales the glow opacity (e.g. 1.6 on hero screens like onboarding).
  final double intensity;

  static const double _glowAlpha = 0.14;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final alpha = (_glowAlpha * intensity).clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(color: c.background),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.9, -1.1),
                    radius: 1.1,
                    colors: [c.accentStart.withValues(alpha: alpha), c.background.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(1.2, 0.4),
                    radius: 0.9,
                    colors: [c.accentEnd.withValues(alpha: alpha * 0.7), c.background.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          // Transparent Material so ListTiles/InkWells on the background show their ink.
          Material(type: MaterialType.transparency, child: child),
        ],
      ),
    );
  }
}
