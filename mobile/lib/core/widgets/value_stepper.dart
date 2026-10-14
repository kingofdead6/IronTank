import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/motion.dart';
import '../utils/haptics.dart';
import '../utils/units.dart';
import 'animated_counter.dart';
import 'glass_card.dart';
import 'pressable_scale.dart';

/// Big-number input: −/+ buttons (hold to repeat) plus a slider for coarse moves.
class ValueStepper extends StatefulWidget {
  const ValueStepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.unit,
    this.decimals = 0,
    this.caption,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final String? unit;
  final int decimals;

  /// Secondary line under the number (e.g. the value in another unit).
  final String? caption;

  @override
  State<ValueStepper> createState() => _ValueStepperState();
}

class _ValueStepperState extends State<ValueStepper> {
  Timer? _repeat;

  double _snap(double v) {
    final stepped = (v / widget.step).round() * widget.step;
    return double.parse(stepped.clamp(widget.min, widget.max).toStringAsFixed(widget.decimals + 1));
  }

  void _nudge(int dir) {
    final next = _snap(widget.value + dir * widget.step);
    if (next != widget.value) {
      Haptics.tap();
      widget.onChanged(next);
    }
  }

  void _startRepeat(int dir) {
    _repeat?.cancel();
    _repeat = Timer.periodic(AppMotion.holdRepeat, (_) => _nudge(dir));
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    String fmt(double v) => Units.formatNumber(v, decimals: widget.decimals);

    return Semantics(
      label: widget.label,
      value: '${fmt(widget.value)} ${widget.unit ?? ''}',
      increasedValue: fmt(_snap(widget.value + widget.step)),
      decreasedValue: fmt(_snap(widget.value - widget.step)),
      onIncrease: () => _nudge(1),
      onDecrease: () => _nudge(-1),
      child: GlassCard(
        child: Column(
          children: [
            Text(widget.label.toUpperCase(), style: context.text.labelSmall),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _RoundButton(icon: Icons.remove_rounded, onTap: () => _nudge(-1), onHoldStart: () => _startRepeat(-1), onHoldEnd: _stopRepeat),
                Expanded(
                  child: Column(
                    children: [
                      FittedBox(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            AnimatedCounter(
                              value: widget.value,
                              duration: AppMotion.fast,
                              formatter: fmt,
                              style: context.numbers.timer,
                            ),
                            if (widget.unit != null) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Text(widget.unit!, style: context.numbers.medium.copyWith(color: c.textSecondary)),
                            ],
                          ],
                        ),
                      ),
                      if (widget.caption != null)
                        Text(widget.caption!, style: context.text.bodySmall),
                    ],
                  ),
                ),
                _RoundButton(icon: Icons.add_rounded, onTap: () => _nudge(1), onHoldStart: () => _startRepeat(1), onHoldEnd: _stopRepeat),
              ],
            ),
            Slider(
              value: widget.value.clamp(widget.min, widget.max),
              min: widget.min,
              max: widget.max,
              onChanged: (v) => widget.onChanged(_snap(v)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, required this.onHoldStart, required this.onHoldEnd});

  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onLongPressStart: (_) => onHoldStart(),
      onLongPressEnd: (_) => onHoldEnd(),
      onLongPressCancel: onHoldEnd,
      child: PressableScale(
        onTap: onTap,
        haptic: false,
        child: Container(
          width: AppSizes.minTapTarget,
          height: AppSizes.minTapTarget,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.glassFill, border: Border.all(color: c.glassBorder)),
          child: Icon(icon, color: c.textPrimary),
        ),
      ),
    );
  }
}
