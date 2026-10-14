import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/skeleton.dart';

/// Cached exercise photo with a shimmer placeholder and a graceful fallback.
class ExerciseImage extends StatelessWidget {
  const ExerciseImage({super.key, required this.url, this.fit = BoxFit.cover, this.borderRadius, this.size});

  final String? url;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Square size; null fills the parent.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fallback = ColoredBox(
      color: c.surfaceHigh,
      child: Center(child: Icon(Icons.fitness_center_rounded, color: c.textMuted, size: AppSizes.iconLg)),
    );

    final image = url == null
        ? fallback
        : CachedNetworkImage(
            imageUrl: url!,
            fit: fit,
            fadeInDuration: AppMotion.medium,
            fadeInCurve: AppMotion.standard,
            placeholder: (_, _) => const Shimmer(child: SkeletonBox(height: double.infinity, radius: BorderRadius.zero)),
            errorWidget: (_, _, _) => fallback,
            // Photos are on white backgrounds; a slight dim keeps them comfortable in dark mode.
            color: Theme.of(context).brightness == Brightness.dark ? c.background.withValues(alpha: AppOpacity.faint) : null,
            colorBlendMode: BlendMode.darken,
          );

    final sized = size == null ? image : SizedBox.square(dimension: size, child: image);
    return borderRadius == null ? sized : ClipRRect(borderRadius: borderRadius!, child: sized);
  }
}

/// Small rounded thumbnail used in lists.
class ExerciseThumb extends StatelessWidget {
  const ExerciseThumb({super.key, required this.url, this.size = AppSizes.exerciseThumb});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) => ExerciseImage(url: url, size: size, borderRadius: AppRadii.mdAll);
}
