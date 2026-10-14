import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../network/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/motion.dart';
import 'gradient_button.dart';

/// Friendly placeholder for empty lists and first-run screens.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Smaller variant for use inside cards.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final iconBox = compact ? AppSizes.iconXl + AppSpacing.lg : AppSizes.iconXl * 2;
    return Padding(
      padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconBox,
            height: iconBox,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.accentSoft,
              border: Border.all(color: c.glassBorder),
            ),
            child: ShaderMask(
              shaderCallback: (r) => c.accentGradient.createShader(r),
              child: Icon(icon, size: compact ? AppSizes.iconMd : AppSizes.iconXl, color: c.onAccent),
            ),
          )
              .animate()
              .scale(begin: const Offset(AppMotion.popScale, AppMotion.popScale), duration: AppMotion.slower, curve: AppMotion.overshoot)
              .fadeIn(duration: AppMotion.medium),
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: compact ? context.text.titleMedium : context.text.headlineSmall,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(message!, textAlign: TextAlign.center, style: context.text.bodyMedium),
          ],
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
            GradientButton(label: actionLabel!, onPressed: onAction, expand: false, compact: compact),
          ],
        ]
            .animate(interval: AppMotion.stagger)
            .fadeIn(duration: AppMotion.slow, curve: AppMotion.enter)
            .slideY(begin: AppMotion.entranceSlide, curve: AppMotion.enter),
      ),
    );
  }
}

/// Error placeholder with a retry action; offline errors get a dedicated message.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry, this.compact = false});

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final offline = error is ApiException && (error as ApiException).isNetwork;
    return EmptyState(
      icon: offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      title: offline ? "You're offline" : 'Something went wrong',
      message: describeError(error),
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
      compact: compact,
    );
  }
}
