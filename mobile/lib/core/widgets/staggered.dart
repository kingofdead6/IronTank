import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/motion.dart';

/// Fade + rise entrance for the [index]-th item of a list, delayed so items
/// cascade in. Delays are capped so long lists don't keep the user waiting.
extension StaggeredEntrance on Widget {
  Widget staggered(int index, {bool horizontal = false}) {
    final a = animate(delay: AppMotion.staggerDelay(index)).fadeIn(duration: AppMotion.slow, curve: AppMotion.enter);
    return horizontal
        ? a.slideX(begin: AppMotion.entranceSlide, duration: AppMotion.slow, curve: AppMotion.enter)
        : a.slideY(begin: AppMotion.entranceSlide, duration: AppMotion.slow, curve: AppMotion.enter);
  }

  /// Single-element entrance (headers, hero blocks).
  Widget entrance({Duration delay = Duration.zero}) => animate(delay: delay)
      .fadeIn(duration: AppMotion.slow, curve: AppMotion.enter)
      .slideY(begin: AppMotion.entranceSlide, duration: AppMotion.slow, curve: AppMotion.enter);
}
