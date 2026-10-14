import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../../core/widgets/timer_ring.dart';
import '../../application/active_workout_controller.dart';
import '../../data/workout_models.dart';

/// Rest adjustment step for the ± buttons.
const restStepSeconds = 15;

/// Floating compact rest timer. Tap to open the full-screen countdown.
class RestTimerPanel extends ConsumerWidget {
  const RestTimerPanel({super.key, required this.rest, required this.nextLabel});

  final RestTimer rest;
  final String nextLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = nowFrom(ref.watch(clockProvider));
    final remaining = rest.remaining(now);
    final ctrl = ref.read(activeWorkoutProvider.notifier);

    return Semantics(
      liveRegion: true,
      label: 'Resting, ${remaining.inSeconds} seconds left',
      child: GlassCard(
        onTap: () => showRestTimerSheet(context),
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
        child: Row(
          children: [
            TimerRing(
              progress: rest.progress(now),
              size: AppSizes.buttonHeight,
              strokeWidth: AppSizes.ringStrokeSm,
              animationDuration: AppMotion.tick,
              curve: AppMotion.linear,
              showTip: false,
              child: Icon(Icons.timer_rounded, size: AppSizes.iconSm, color: context.colors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(Fmt.clock(remaining), style: context.numbers.medium),
                  Text(nextLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                ],
              ),
            ),
            _RoundAction(label: '−$restStepSeconds', semantic: 'Remove 15 seconds', onTap: () => ctrl.adjustRest(-restStepSeconds)),
            _RoundAction(label: '+$restStepSeconds', semantic: 'Add 15 seconds', onTap: () => ctrl.adjustRest(restStepSeconds)),
            IconButton(tooltip: 'Skip rest', onPressed: ctrl.skipRest, icon: const Icon(Icons.skip_next_rounded)),
          ],
        ),
      ),
    );
  }
}

/// Full-screen circular countdown with ±15 s and skip.
Future<void> showRestTimerSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => const _RestSheet(),
);

class _RestSheet extends ConsumerWidget {
  const _RestSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rest = ref.watch(activeWorkoutProvider.select((w) => w?.rest));
    final now = nowFrom(ref.watch(clockProvider));
    final ctrl = ref.read(activeWorkoutProvider.notifier);
    final c = context.colors;

    // Close automatically when the rest ends or is skipped.
    if (rest == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('REST', style: context.text.labelSmall?.copyWith(letterSpacing: 4)),
          const SizedBox(height: AppSpacing.xl),
          TimerRing(
            progress: rest?.progress(now) ?? 0,
            animationDuration: AppMotion.tick,
            curve: AppMotion.linear,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(Fmt.clock(rest?.remaining(now) ?? Duration.zero), style: context.numbers.timer),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  rest == null ? 'Done' : 'of ${Fmt.clock(Duration(seconds: rest.totalSeconds))}',
                  style: context.text.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BigAction(label: '−$restStepSeconds s', icon: Icons.remove_rounded, onTap: () => ctrl.adjustRest(-restStepSeconds)),
              _BigAction(label: 'Skip', icon: Icons.skip_next_rounded, onTap: ctrl.skipRest, primary: true),
              _BigAction(label: '+$restStepSeconds s', icon: Icons.add_rounded, onTap: () => ctrl.adjustRest(restStepSeconds)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text("We'll buzz you when it's time, even if you leave the app.", textAlign: TextAlign.center, style: context.text.bodySmall?.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.label, required this.semantic, required this.onTap});

  final String label;
  final String semantic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: PressableScale(
        onTap: onTap,
        semanticLabel: semantic,
        child: Container(
          width: AppSizes.minTapTarget,
          height: AppSizes.minTapTarget * 0.8,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.glassFill, borderRadius: AppRadii.mdAll, border: Border.all(color: c.glassBorder)),
          child: Text(label, style: context.numbers.small.copyWith(fontSize: context.numbers.unit.fontSize)),
        ),
      ),
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({required this.label, required this.icon, required this.onTap, this.primary = false});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: AppSizes.buttonHeight * 1.2,
              height: AppSizes.buttonHeight * 1.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: primary ? c.accentGradient : null,
                color: primary ? null : c.glassFill,
                border: primary ? null : Border.all(color: c.glassBorder),
                boxShadow: primary ? [BoxShadow(color: c.accentGlow, blurRadius: AppSizes.shadowBlur)] : null,
              ),
              child: Icon(icon, color: primary ? c.onAccent : c.textPrimary, size: AppSizes.iconLg),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(label, style: context.text.labelMedium),
          ],
        ),
      ),
    );
  }
}
