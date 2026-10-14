import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/motion.dart';
import '../../../core/widgets/animated_counter.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/rank_badge.dart';
import '../../../core/widgets/timer_ring.dart';
import '../../profile/application/settings_controller.dart';

class _Slide {
  const _Slide(this.title, this.body, this.art);

  final String title;
  final String body;
  final Widget Function(bool active) art;
}

/// Three-slide animated intro. Auto-advances; swiping takes over.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  Timer? _auto;
  int _index = 0;

  late final List<_Slide> _slides = [
    _Slide(
      'Log every rep',
      'A lightning-fast workout logger with rest timers, previous-session hints and offline safety.',
      (active) => _TimerArt(active: active),
    ),
    _Slide(
      'Smash your PRs',
      'IronRank spots new personal records the moment you save — and celebrates them with you.',
      (active) => _PrArt(active: active),
    ),
    _Slide(
      'Climb the ranks',
      'From Bronze to Legend: see how strong you are for your bodyweight on every big lift.',
      (active) => _RankArt(active: active),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _auto = Timer.periodic(AppMotion.carouselAutoAdvance, (_) => _next(auto: true));
  }

  @override
  void dispose() {
    _auto?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _next({bool auto = false}) {
    if (!mounted) return;
    if (_index == _slides.length - 1) {
      if (!auto) _finish(Routes.register);
      return;
    }
    _pages.nextPage(duration: AppMotion.slow, curve: AppMotion.emphasized);
  }

  Future<void> _finish(String route) async {
    _auto?.cancel();
    await ref.read(settingsProvider.notifier).markOnboardingSeen();
    if (mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final last = _index == _slides.length - 1;
    return Scaffold(
      body: AppBackground(
        intensity: 1.6,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.sm, 0),
                child: Row(
                  children: [
                    const BrandMark(size: AppSizes.iconXl, showWordmark: false),
                    const Spacer(),
                    TextButton(onPressed: () => _finish(Routes.login), child: const Text('Sign in')),
                  ],
                ),
              ),
              Expanded(
                child: NotificationListener<UserScrollNotification>(
                  // Manual swiping stops the auto-advance.
                  onNotification: (_) {
                    _auto?.cancel();
                    return false;
                  },
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => _SlideView(slide: _slides[i], active: i == _index),
                  ),
                ),
              ),
              _Dots(count: _slides.length, index: _index),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xl, AppSpacing.screen, AppSpacing.lg),
                child: GradientButton(
                  label: last ? 'Get started' : 'Next',
                  icon: last ? Icons.arrow_forward_rounded : null,
                  onPressed: () {
                    _auto?.cancel();
                    _next();
                  },
                ),
              ),
              Text('Free · Offline-ready · No ads', style: context.text.bodySmall?.copyWith(color: c.textMuted)),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.active});

  final _Slide slide;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        children: [
          Expanded(child: Center(child: slide.art(active))),
          Text(slide.title, textAlign: TextAlign.center, style: context.text.displaySmall)
              .animate(target: active ? 1 : 0)
              .fadeIn(duration: AppMotion.slow)
              .slideY(begin: AppMotion.entranceSlide, curve: AppMotion.enter),
          const SizedBox(height: AppSpacing.md),
          Text(slide.body, textAlign: TextAlign.center, style: context.text.bodyLarge?.copyWith(color: context.colors.textSecondary))
              .animate(target: active ? 1 : 0, delay: AppMotion.stagger * 2)
              .fadeIn(duration: AppMotion.slow)
              .slideY(begin: AppMotion.entranceSlide, curve: AppMotion.enter),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Slide ${index + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: AppMotion.medium,
              curve: AppMotion.emphasized,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              width: i == index ? AppSpacing.xl : AppSpacing.sm,
              height: AppSpacing.sm,
              decoration: BoxDecoration(
                borderRadius: AppRadii.pillAll,
                gradient: i == index ? c.accentGradient : null,
                color: i == index ? null : c.glassBorder,
              ),
            ),
        ],
      ),
    );
  }
}

// ---- Slide artwork, built from the app's own components ----------------------

class _TimerArt extends StatelessWidget {
  const _TimerArt({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return TimerRing(
      progress: active ? 0.72 : 0,
      animationDuration: AppMotion.ring,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('1:05', style: context.numbers.timer),
          const SizedBox(height: AppSpacing.xs),
          Text('REST', style: context.text.labelSmall),
        ],
      ),
    );
  }
}

class _PrArt extends StatelessWidget {
  const _PrArt({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.emoji_events_rounded, size: AppSizes.iconXl * 2, color: c.warning)
            .animate(target: active ? 1 : 0)
            .scaleXY(begin: AppMotion.popScale, end: 1, duration: AppMotion.slower, curve: AppMotion.elastic),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AnimatedCounter(value: active ? 142.5 : 0, formatter: (v) => v.toStringAsFixed(1), style: context.numbers.hero),
            const SizedBox(width: AppSpacing.sm),
            Text('kg', style: context.numbers.medium.copyWith(color: c.textSecondary)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(gradient: c.accentGradient, borderRadius: AppRadii.pillAll),
          child: Text('NEW SQUAT PR', style: context.text.labelSmall?.copyWith(color: c.onAccent)),
        ),
      ],
    );
  }
}

class _RankArt extends StatefulWidget {
  const _RankArt({required this.active});

  final bool active;

  @override
  State<_RankArt> createState() => _RankArtState();
}

class _RankArtState extends State<_RankArt> {
  Timer? _cycle;
  int _tier = 0;

  static const _names = ['Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond', 'Elite', 'Legend'];

  @override
  void didUpdateWidget(covariant _RankArt old) {
    super.didUpdateWidget(old);
    if (widget.active && _cycle == null) {
      _cycle = Timer.periodic(AppMotion.slower * 2, (_) => setState(() => _tier = (_tier + 1) % _names.length));
    } else if (!widget.active) {
      _cycle?.cancel();
      _cycle = null;
    }
  }

  @override
  void dispose() {
    _cycle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: AppMotion.slow,
          switchInCurve: AppMotion.overshoot,
          transitionBuilder: (child, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: child)),
          child: RankBadge(
            key: ValueKey(_tier),
            tierIndex: _tier,
            tierName: _names[_tier],
            progress: 65,
            size: AppSizes.rankBadgeLg,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AnimatedSwitcher(
          duration: AppMotion.medium,
          child: Text(
            _names[_tier].toUpperCase(),
            key: ValueKey(_tier),
            style: context.text.titleLarge?.copyWith(letterSpacing: 3, color: TierColors.of(_tier).primary),
          ),
        ),
      ],
    );
  }
}
