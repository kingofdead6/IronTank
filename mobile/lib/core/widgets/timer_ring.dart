import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/motion.dart';

/// Circular countdown/progress ring with a gradient sweep, rounded caps and a
/// glowing leading tip. [progress] changes are animated smoothly.
class TimerRing extends StatelessWidget {
  const TimerRing({
    super.key,
    required this.progress,
    this.size = AppSizes.timerRingSize,
    this.strokeWidth = AppSizes.ringStroke,
    this.gradient,
    this.trackColor,
    this.child,
    this.animationDuration = AppMotion.medium,
    this.curve = AppMotion.standard,
    this.showTip = true,
  });

  /// 0 → empty, 1 → full.
  final double progress;
  final double size;
  final double strokeWidth;

  /// Defaults to the accent gradient.
  final List<Color>? gradient;
  final Color? trackColor;
  final Widget? child;
  final Duration animationDuration;

  /// Use [AppMotion.linear] with a one-second duration for live countdowns.
  final Curve curve;
  final bool showTip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final colors = gradient ?? [c.accentStart, c.accentEnd];
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: animationDuration,
        curve: curve,
        builder: (context, value, inner) => CustomPaint(
          painter: TimerRingPainter(
            progress: value,
            strokeWidth: strokeWidth,
            colors: colors,
            trackColor: trackColor ?? c.glassFill,
            showTip: showTip,
          ),
          child: inner,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class TimerRingPainter extends CustomPainter {
  TimerRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.colors,
    required this.trackColor,
    this.showTip = true,
  });

  final double progress;
  final double strokeWidth;
  final List<Color> colors;
  final Color trackColor;
  final bool showTip;

  static const double _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    final sweep = 2 * math.pi * progress;

    // Rotate the gradient so it starts at 12 o'clock with the arc.
    final shader = SweepGradient(
      startAngle: 0,
      endAngle: 2 * math.pi,
      colors: [...colors, colors.first],
      transform: const GradientRotation(_start),
    ).createShader(rect);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = shader;

    // Soft glow under the arc.
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = shader
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 0.8);
    canvas.drawArc(rect, _start, sweep, false, glow);
    canvas.drawArc(rect, _start, sweep, false, arc);

    if (showTip && progress < 1) {
      final angle = _start + sweep;
      final tip = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(tip, strokeWidth * 0.32, Paint()..color = colors.last);
    }
  }

  @override
  bool shouldRepaint(TimerRingPainter old) =>
      old.progress != progress ||
      old.strokeWidth != strokeWidth ||
      old.trackColor != trackColor ||
      old.showTip != showTip ||
      !_sameColors(old.colors, colors);

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
