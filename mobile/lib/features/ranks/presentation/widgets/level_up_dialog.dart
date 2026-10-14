import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/rank_badge.dart';
import '../../../workout/presentation/pr_celebration_screen.dart';
import '../../application/rank_seen_store.dart';

/// Full-screen level-up: the old badge flips over into the new tier, then
/// pops with a burst and a glow.
Future<void> showLevelUp(BuildContext context, LevelUp levelUp, {int more = 0}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierColor: context.colors.background.withValues(alpha: AppOpacity.overlay),
  transitionDuration: AppMotion.slow,
  pageBuilder: (_, _, _) => _LevelUpView(levelUp: levelUp, more: more),
  transitionBuilder: (_, anim, _, child) =>
      FadeTransition(opacity: CurvedAnimation(parent: anim, curve: AppMotion.standard), child: child),
);

class _LevelUpView extends StatefulWidget {
  const _LevelUpView({required this.levelUp, required this.more});

  final LevelUp levelUp;
  final int more;

  @override
  State<_LevelUpView> createState() => _LevelUpViewState();
}

class _LevelUpViewState extends State<_LevelUpView> with TickerProviderStateMixin {
  /// 0→0.5: old badge turns edge-on; 0.5→1: new badge turns face-on.
  late final AnimationController _flip = AnimationController(vsync: this, duration: AppMotion.slower * 2);
  late final AnimationController _burst = AnimationController(vsync: this);
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _flip.addListener(() {
      if (!_revealed && _flip.value >= 0.5) {
        setState(() => _revealed = true);
        Haptics.celebrate();
        if (_burst.duration != null) _burst.forward(from: 0);
      }
    });
    Future<void>.delayed(AppMotion.slow, () {
      if (mounted) _flip.forward();
    });
  }

  @override
  void dispose() {
    _flip.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.levelUp;
    final tierIndex = _revealed ? l.toIndex : l.fromIndex;
    final tier = TierColors.of(l.toIndex);

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            children: [
              const Spacer(),
              Text('LEVEL UP', style: context.text.labelSmall?.copyWith(letterSpacing: 6, color: tier.primary))
                  .animate()
                  .fadeIn(duration: AppMotion.slow)
                  .slideY(begin: -AppMotion.entranceSlide),
              const SizedBox(height: AppSpacing.xl),
              SizedBox.square(
                dimension: AppSizes.rankBadgeLg * 1.8,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IgnorePointer(
                      child: Lottie.asset(
                        PrCelebrationScreen.lottieAsset,
                        controller: _burst,
                        onLoaded: (c) => _burst.duration = c.duration,
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _flip,
                      builder: (context, child) {
                        // Rotate around Y: 0 → 90° (old), then -90° → 0 (new).
                        final t = _flip.value;
                        final angle = t < 0.5 ? t * math.pi : (t - 1) * math.pi;
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0015)
                            ..rotateY(angle),
                          child: child,
                        );
                      },
                      child: AnimatedScale(
                        scale: _revealed ? 1.08 : 1,
                        duration: AppMotion.slower,
                        curve: AppMotion.elastic,
                        child: RankBadge(
                          key: ValueKey(tierIndex),
                          tierIndex: tierIndex,
                          tierName: l.tiers[tierIndex],
                          size: AppSizes.rankBadgeLg,
                          showProgress: false,
                          animate: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AnimatedSwitcher(
                duration: AppMotion.medium,
                child: Text(
                  l.tiers[tierIndex].toUpperCase(),
                  key: ValueKey(tierIndex),
                  style: context.text.displaySmall?.copyWith(color: TierColors.of(tierIndex).primary, letterSpacing: 4),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${l.label}: ${l.tiers[l.fromIndex]} → ${l.tiers[l.toIndex]}',
                textAlign: TextAlign.center,
                style: context.text.bodyLarge?.copyWith(color: context.colors.textSecondary),
              ),
              if (widget.more > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                Text('+${widget.more} more rank-up${widget.more == 1 ? '' : 's'}', style: context.text.bodySmall),
              ],
              const Spacer(),
              GradientButton(label: 'Awesome', icon: Icons.bolt_rounded, onPressed: () => Navigator.pop(context)),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
