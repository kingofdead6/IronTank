import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'pressable_scale.dart';

/// Frosted-glass surface: background blur, translucent fill, hairline border
/// and a soft top highlight. Becomes pressable when [onTap] is set.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.borderRadius = AppRadii.lgAll,
    this.onTap,
    this.onLongPress,
    this.highlighted = false,
    this.blur = true,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Draws the border with the accent gradient (e.g. selected / current item).
  final bool highlighted;

  /// Background blur is costly; disable it for cards inside long scrolling lists.
  final bool blur;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: c.glassFill,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.glassHighlight, c.glassFill],
        ),
        border: highlighted ? null : Border.all(color: c.glassBorder, width: AppSizes.borderWidth),
      ),
      // Transparent Material so ListTiles/InkWells inside show their ink.
      child: Material(type: MaterialType.transparency, child: Padding(padding: padding, child: child)),
    );

    if (highlighted) {
      // Gradient border: an accent-filled shell with the card inset by the border width.
      body = DecoratedBox(
        decoration: BoxDecoration(borderRadius: borderRadius, gradient: c.accentGradient),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.borderWidth * 1.5),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: ColoredBox(color: c.backgroundElevated, child: body),
          ),
        ),
      );
    }

    Widget card = ClipRRect(
      borderRadius: borderRadius,
      child: blur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: AppSizes.glassBlur, sigmaY: AppSizes.glassBlur),
              child: body,
            )
          : body,
    );

    if (onTap != null || onLongPress != null) {
      card = PressableScale(onTap: onTap, onLongPress: onLongPress, semanticLabel: semanticLabel, child: card);
    }
    return card;
  }
}
