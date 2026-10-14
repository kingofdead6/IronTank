import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/motion.dart';

/// Animates a diagonal highlight across every [SkeletonBox] below it.
/// Use one [Shimmer] per loading region so all boxes sweep in sync.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.shimmer)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            colors: [c.shimmerBase, c.shimmerHighlight, c.shimmerBase],
            stops: const [0.35, 0.5, 0.65],
            begin: const Alignment(-1, -0.3),
            end: const Alignment(1, 0.3),
            transform: _SlideGradient(_c.value),
          ).createShader(bounds),
          child: child,
        ),
        child: ExcludeSemantics(child: widget.child),
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.t);

  final double t;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (2 * t - 1) * 1.5, 0, 0);
}

/// Placeholder block shown inside a [Shimmer].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = AppSpacing.lg, this.radius = AppRadii.smAll, this.circle = false});

  final double? width;
  final double height;
  final BorderRadius radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: circle ? height : width,
      height: height,
      decoration: BoxDecoration(
        color: context.colors.shimmerBase,
        borderRadius: circle ? null : radius,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
      ),
    );
  }
}

/// A list of card-shaped skeletons for list screens.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6, this.itemHeight = 76, this.padding = AppSpacing.screenPadding});

  final int count;
  final double itemHeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        padding: padding,
        // Never scrolls itself, so it can sit inside other scroll views.
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, _) => SkeletonBox(height: itemHeight, radius: AppRadii.lgAll),
      ),
    );
  }
}
