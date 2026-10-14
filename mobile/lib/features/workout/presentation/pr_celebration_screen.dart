import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/animated_counter.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../auth/application/auth_controller.dart';
import '../data/workout_models.dart';

/// Full-screen celebration for new personal records: Lottie burst, confetti,
/// an elastic trophy and a rolling counter. Swipe through multiple PRs.
class PrCelebrationScreen extends ConsumerStatefulWidget {
  const PrCelebrationScreen({super.key, required this.result});

  final WorkoutResult result;

  static const lottieAsset = 'assets/lottie/pr_burst.json';

  @override
  ConsumerState<PrCelebrationScreen> createState() => _PrCelebrationScreenState();
}

class _PrCelebrationScreenState extends ConsumerState<PrCelebrationScreen> with TickerProviderStateMixin {
  late final ConfettiController _confetti = ConfettiController(duration: AppMotion.celebration);
  late final AnimationController _burst = AnimationController(vsync: this);
  final _pages = PageController();
  int _index = 0;

  List<NewRecord> get _records => widget.result.newRecords;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _celebrate());
  }

  void _celebrate() {
    if (!mounted) return;
    _confetti.play();
    if (_burst.duration != null) _burst.forward(from: 0);
    Haptics.celebrate();
  }

  @override
  void dispose() {
    _confetti.dispose();
    _burst.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unit = ref.watch(currentUserProvider)?.unit ?? WeightUnit.kg;
    final confettiColors = [c.accentStart, c.accentEnd, TierColors.gold.primary, c.onAccent];

    return Scaffold(
      body: AppBackground(
        intensity: 2,
        child: Stack(
          children: [
            // Burst behind the trophy.
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: const Alignment(0, -0.35),
                  child: Lottie.asset(
                    PrCelebrationScreen.lottieAsset,
                    controller: _burst,
                    width: AppSizes.timerRingSize * 1.6,
                    onLoaded: (composition) {
                      _burst
                        ..duration = composition.duration
                        ..forward(from: 0);
                    },
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    _records.length == 1 ? 'NEW PERSONAL RECORD' : '${_records.length} NEW PERSONAL RECORDS',
                    style: context.text.labelSmall?.copyWith(letterSpacing: 3, color: c.accent),
                  ).animate().fadeIn(duration: AppMotion.slow).slideY(begin: -AppMotion.entranceSlide),
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: _records.length,
                      onPageChanged: (i) {
                        setState(() => _index = i);
                        _celebrate();
                      },
                      itemBuilder: (_, i) => _RecordPage(record: _records[i], unit: unit),
                    ),
                  ),
                  if (_records.length > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _records.length; i++)
                          AnimatedContainer(
                            duration: AppMotion.medium,
                            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                            width: i == _index ? AppSpacing.xl : AppSpacing.sm,
                            height: AppSpacing.sm,
                            decoration: BoxDecoration(
                              borderRadius: AppRadii.pillAll,
                              gradient: i == _index ? c.accentGradient : null,
                              color: i == _index ? null : c.glassBorder,
                            ),
                          ),
                      ],
                    ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.screen),
                    child: GradientButton(
                      label: _index < _records.length - 1 ? 'Next record' : 'Continue',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () {
                        if (_index < _records.length - 1) {
                          _pages.nextPage(duration: AppMotion.slow, curve: AppMotion.emphasized);
                        } else {
                          context.pop();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Confetti cannons from both top corners.
            Align(
              alignment: Alignment.topLeft,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirection: math.pi / 4,
                emissionFrequency: ConfettiTuning.emissionFrequency,
                numberOfParticles: ConfettiTuning.particlesPerBurst,
                maxBlastForce: ConfettiTuning.maxBlastForce,
                minBlastForce: ConfettiTuning.minBlastForce,
                gravity: ConfettiTuning.gravity,
                colors: confettiColors,
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirection: 3 * math.pi / 4,
                emissionFrequency: ConfettiTuning.emissionFrequency,
                numberOfParticles: ConfettiTuning.particlesPerBurst,
                maxBlastForce: ConfettiTuning.maxBlastForce,
                minBlastForce: ConfettiTuning.minBlastForce,
                gravity: ConfettiTuning.gravity,
                colors: confettiColors,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordPage extends StatelessWidget {
  const _RecordPage({required this.record, required this.unit});

  final NewRecord record;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isReps = record.type == 'maxRepsAtWeight';
    final value = isReps ? record.value : Units.fromKg(record.value, unit);
    final suffix = isReps ? 'reps' : record.type == 'maxVolumeSet' ? '${unit.label} vol' : unit.label;
    final delta = record.previousValue == null
        ? null
        : isReps
        ? record.value - record.previousValue!
        : Units.fromKg(record.value - record.previousValue!, unit);

    final detail = switch (record.type) {
      'maxRepsAtWeight' => 'at ${Units.weight(record.weight ?? 0, unit)}',
      'e1rm' => 'from ${Units.weight(record.weight ?? 0, unit)} × ${record.reps}',
      'maxVolumeSet' => '${Units.weight(record.weight ?? 0, unit)} × ${record.reps}',
      _ => record.reps == null ? '' : '× ${record.reps} reps',
    };

    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: AppSizes.rankBadgeMd,
            height: AppSizes.rankBadgeMd,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: TierColors.gold.gradient,
              boxShadow: [BoxShadow(color: TierColors.gold.glow, blurRadius: AppSpacing.xxxl, spreadRadius: AppSpacing.sm)],
            ),
            child: Icon(Icons.emoji_events_rounded, size: AppSizes.iconXl * 1.4, color: c.onAccent),
          )
              .animate()
              .scaleXY(begin: 0, end: 1, duration: AppMotion.slower, curve: AppMotion.elastic)
              .then()
              .shimmer(duration: AppMotion.slower, color: c.onAccent.withValues(alpha: AppOpacity.muted)),
          const SizedBox(height: AppSpacing.xl),
          Text(record.exerciseName, textAlign: TextAlign.center, style: context.text.headlineMedium)
              .animate(delay: AppMotion.stagger * 3)
              .fadeIn(duration: AppMotion.slow)
              .slideY(begin: AppMotion.entranceSlide),
          const SizedBox(height: AppSpacing.xs),
          Text(record.title.toUpperCase(), style: context.text.labelSmall?.copyWith(letterSpacing: 2))
              .animate(delay: AppMotion.stagger * 4)
              .fadeIn(duration: AppMotion.slow),
          const SizedBox(height: AppSpacing.lg),
          FittedBox(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (r) => c.accentGradient.createShader(r),
                  child: AnimatedCounter(
                    value: value,
                    duration: AppMotion.celebration ~/ 2,
                    formatter: (v) => isReps ? v.round().toString() : Units.formatNumber(v),
                    style: context.numbers.hero,
                    semanticsSuffix: suffix,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(suffix, style: context.numbers.medium.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          if (detail.isNotEmpty) Text(detail, style: context.text.bodyLarge?.copyWith(color: c.textSecondary)),
          if (delta != null && delta > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              decoration: BoxDecoration(color: c.success.withValues(alpha: AppOpacity.subtle), borderRadius: AppRadii.pillAll),
              child: Text(
                '+${Units.formatNumber(delta)} ${isReps ? 'reps' : unit.label} vs previous best',
                style: context.text.labelLarge?.copyWith(color: c.success),
              ),
            ).animate(delay: AppMotion.counter).fadeIn(duration: AppMotion.medium).scaleXY(begin: AppMotion.popScale, curve: AppMotion.overshoot),
          ],
        ],
      ),
    );
  }
}
