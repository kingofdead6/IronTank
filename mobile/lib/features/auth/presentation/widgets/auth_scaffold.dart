import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/brand_mark.dart';

/// Shared layout for login/register: glowing background, logo, centred
/// scrollable form constrained to a comfortable width.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child, this.onBack});

  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        intensity: 1.3,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: AppSpacing.xl),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (onBack != null)
                          IconButton(
                            tooltip: 'Back',
                            onPressed: onBack,
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        const Spacer(),
                        const BrandMark(size: AppSizes.iconXl, showWordmark: false),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated inline error message for auth forms.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedSize(
      duration: AppMotion.medium,
      curve: AppMotion.standard,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: c.danger.withValues(alpha: AppOpacity.faint * 2),
                borderRadius: AppRadii.mdAll,
                border: Border.all(color: c.danger.withValues(alpha: AppOpacity.subtle)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: c.danger, size: AppSizes.iconMd),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(message!, style: context.text.bodyMedium?.copyWith(color: c.textPrimary)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
