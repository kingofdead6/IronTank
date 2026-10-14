import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/motion.dart';
import 'pressable_scale.dart';

enum GradientButtonVariant { filled, outlined, ghost }

/// Primary call-to-action: accent gradient fill, spring press, inline loading.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.compact = false,
    this.variant = GradientButtonVariant.filled,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final bool compact;
  final GradientButtonVariant variant;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final filled = variant == GradientButtonVariant.filled;
    final fg = filled ? c.onAccent : c.textPrimary;
    final height = compact ? AppSizes.buttonHeightSm : AppSizes.buttonHeight;

    final content = AnimatedSwitcher(
      duration: AppMotion.fast,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: AppMotion.switchScale, end: 1.0).animate(anim), child: child),
      ),
      child: loading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: AppSizes.iconMd,
              height: AppSizes.iconMd,
              child: CircularProgressIndicator(strokeWidth: AppSizes.spinnerStroke, color: fg),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: fg, size: compact ? AppSizes.iconSm : AppSizes.iconMd),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelLarge?.copyWith(color: fg),
                  ),
                ),
              ],
            ),
    );

    final decoration = switch (variant) {
      GradientButtonVariant.filled => BoxDecoration(
        gradient: c.accentGradient,
        borderRadius: AppRadii.pillAll,
        boxShadow: [BoxShadow(color: c.accentGlow, blurRadius: AppSizes.shadowBlur, offset: const Offset(0, AppSizes.shadowOffset))],
      ),
      GradientButtonVariant.outlined => BoxDecoration(
        color: c.glassFill,
        borderRadius: AppRadii.pillAll,
        border: Border.all(color: c.glassBorder),
      ),
      GradientButtonVariant.ghost => const BoxDecoration(borderRadius: AppRadii.pillAll),
    };

    final button = AnimatedOpacity(
      duration: AppMotion.fast,
      opacity: onPressed == null ? AppOpacity.disabled : 1,
      child: Container(
        height: height,
        constraints: const BoxConstraints(minWidth: AppSizes.minTapTarget * 2),
        padding: EdgeInsets.symmetric(horizontal: compact ? AppSpacing.lg : AppSpacing.xl),
        decoration: decoration,
        alignment: Alignment.center,
        child: content,
      ),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        onTap: _enabled ? onPressed : null,
        child: expand ? SizedBox(width: double.infinity, child: button) : button,
      ),
    );
  }
}
