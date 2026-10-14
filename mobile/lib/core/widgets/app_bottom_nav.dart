import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/motion.dart';
import 'pressable_scale.dart';

class AppNavItem {
  const AppNavItem({required this.icon, required this.activeIcon, required this.label});

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Floating glass bottom navigation with a gradient pill indicator that glides
/// between tabs. The centre item can be emphasised (the workout button).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    this.emphasizedIndex,
  });

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  /// Index rendered as a raised gradient action button.
  final int? emphasizedIndex;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, bottomInset + AppSpacing.md),
      child: ClipRRect(
        borderRadius: AppRadii.xlAll,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: AppSizes.glassBlur, sigmaY: AppSizes.glassBlur),
          child: Container(
            height: AppSizes.bottomNavHeight,
            decoration: BoxDecoration(
              color: c.backgroundElevated.withValues(alpha: AppOpacity.navGlass),
              borderRadius: AppRadii.xlAll,
              border: Border.all(color: c.glassBorder),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slot = constraints.maxWidth / items.length;
                final showPill = currentIndex != emphasizedIndex;
                return Stack(
                  children: [
                    // Sliding indicator.
                    AnimatedPositioned(
                      duration: AppMotion.slow,
                      curve: AppMotion.emphasized,
                      left: slot * currentIndex + AppSpacing.sm,
                      top: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      width: slot - AppSpacing.lg,
                      child: AnimatedOpacity(
                        duration: AppMotion.fast,
                        opacity: showPill ? 1 : 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadii.lgAll),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: i == emphasizedIndex
                                ? _CenterAction(item: items[i], selected: i == currentIndex, onTap: () => onSelect(i))
                                : _NavButton(item: items[i], selected: i == currentIndex, onTap: () => onSelect(i)),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.textPrimary : c.textMuted;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: PressableScale(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: AppMotion.fast,
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: selected
                  ? ShaderMask(
                      key: const ValueKey('on'),
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (r) => c.accentGradient.createShader(r),
                      child: Icon(item.activeIcon, size: AppSizes.iconMd),
                    )
                  : Icon(item.icon, key: const ValueKey('off'), size: AppSizes.iconMd, color: color),
            ),
            const SizedBox(height: AppSpacing.xxs),
            AnimatedDefaultTextStyle(
              duration: AppMotion.fast,
              style: (context.text.labelSmall ?? const TextStyle()).copyWith(color: color),
              child: Text(item.label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterAction extends StatelessWidget {
  const _CenterAction({required this.item, required this.selected, required this.onTap});

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: PressableScale(
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: AppMotion.medium,
            curve: AppMotion.emphasized,
            width: AppSizes.buttonHeight,
            height: AppSizes.buttonHeight,
            decoration: BoxDecoration(
              gradient: c.accentGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: c.accentGlow,
                  blurRadius: selected ? AppSizes.shadowBlur : AppSizes.shadowBlur / 2,
                  offset: const Offset(0, AppSizes.shadowOffset / 2),
                ),
              ],
            ),
            child: Icon(selected ? item.activeIcon : item.icon, color: c.onAccent, size: AppSizes.iconLg),
          ),
        ),
      ),
    );
  }
}
