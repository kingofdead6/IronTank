import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/motion.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/brand_mark.dart';

/// Shown while the stored session is restored; the router moves on automatically.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        intensity: 1.6,
        child: Center(
          child: const BrandMark()
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(
                begin: 1 - AppMotion.breatheScale,
                end: 1 + AppMotion.breatheScale,
                duration: AppMotion.breatheCycle,
                curve: AppMotion.breathe,
              )
              .animate()
              .fadeIn(duration: AppMotion.slow),
        ),
      ),
    );
  }
}
