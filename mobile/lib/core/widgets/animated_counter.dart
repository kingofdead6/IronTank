import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// Rolls a number from its previous value (or zero, on first build) to [value].
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.formatter,
    this.duration = AppMotion.counter,
    this.curve = AppMotion.emphasized,
    this.semanticsSuffix,
  });

  final num value;
  final TextStyle? style;

  /// Formats the interpolated value; defaults to a rounded integer.
  final String Function(double value)? formatter;
  final Duration duration;
  final Curve curve;

  /// Appended to the final value for screen readers (e.g. "kilograms").
  final String? semanticsSuffix;

  @override
  Widget build(BuildContext context) {
    final format = formatter ?? (v) => v.round().toString();
    final target = value.toDouble();
    return Semantics(
      label: semanticsSuffix == null ? format(target) : '${format(target)} $semanticsSuffix',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        // Starts at 0 on first build; later changes animate from the current value.
        tween: Tween(begin: 0, end: target),
        duration: duration,
        curve: curve,
        builder: (context, v, _) => Text(format(v), style: style),
      ),
    );
  }
}
