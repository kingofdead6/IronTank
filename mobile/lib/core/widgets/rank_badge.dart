import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/motion.dart';

/// Hexagonal rank badge drawn with a [CustomPainter]: tier gradient body,
/// inner facets, a glow, and an outer progress ring toward the next tier.
/// Pops in with an elastic scale and fills its ring on first build.
class RankBadge extends StatelessWidget {
  const RankBadge({
    super.key,
    required this.tierIndex,
    this.tierName,
    this.progress = 0,
    this.size = AppSizes.rankBadgeMd,
    this.showProgress = true,
    this.showLabel = true,
    this.animate = true,
  });

  /// 0 (Bronze) … 6 (Legend); null = unranked.
  final int? tierIndex;
  final String? tierName;

  /// 0–100 toward the next tier.
  final num progress;
  final double size;
  final bool showProgress;
  final bool showLabel;
  final bool animate;

  static const _numerals = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'];

  @override
  Widget build(BuildContext context) {
    final tier = TierColors.of(tierIndex);
    final target = (progress / 100).clamp(0.0, 1.0).toDouble();
    final label = tierIndex == null ? '—' : _numerals[tierIndex!.clamp(0, _numerals.length - 1)];

    Widget painted(double scale, double ring) => Transform.scale(
      scale: scale,
      child: CustomPaint(
        size: Size.square(size),
        painter: RankBadgePainter(
          tier: tier,
          progress: showProgress ? ring : null,
          trackColor: context.colors.glassFill,
        ),
        child: SizedBox.square(
          dimension: size,
          child: showLabel
              ? Center(
                  child: Text(
                    label,
                    style: context.numbers.medium.copyWith(
                      fontSize: size * 0.22,
                      color: tierIndex == null ? context.colors.textMuted : TierColors.numeral,
                      shadows: [Shadow(color: tier.secondary, blurRadius: size * 0.06)],
                    ),
                  ),
                )
              : null,
        ),
      ),
    );

    final semantics = tierIndex == null
        ? 'Unranked'
        : '${tierName ?? 'Tier ${tierIndex! + 1}'}, ${progress.round()} percent to next tier';

    if (!animate) return Semantics(label: semantics, child: painted(1, target));

    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.slower,
        curve: AppMotion.overshoot,
        builder: (context, pop, _) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: target),
          duration: AppMotion.ring,
          curve: AppMotion.emphasized,
          builder: (context, ring, _) => painted(AppMotion.popScale + (1 - AppMotion.popScale) * pop, ring),
        ),
      ),
    );
  }
}

class RankBadgePainter extends CustomPainter {
  RankBadgePainter({required this.tier, required this.trackColor, this.progress});

  final TierColors tier;
  final Color trackColor;

  /// null hides the outer ring.
  final double? progress;

  /// Fraction of the badge used by the progress ring and the gap inside it.
  static const double _ringFraction = 0.06;
  static const double _gapFraction = 0.05;

  Path _hexagon(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      // Pointy-top hexagon with slightly rounded look via many-point polygon below.
      final a = -math.pi / 2 + i * math.pi / 3;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final ringWidth = outer * _ringFraction * 2;
    final hexR = outer - (progress == null ? 0 : ringWidth + outer * _gapFraction * 2);

    // Progress ring toward next tier.
    if (progress != null) {
      final rect = Rect.fromCircle(center: c, radius: outer - ringWidth / 2);
      final base = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..color = trackColor;
      canvas.drawCircle(c, outer - ringWidth / 2, base);
      if (progress! > 0) {
        final arc = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            colors: [tier.primary, tier.secondary, tier.primary],
            transform: const GradientRotation(-math.pi / 2),
          ).createShader(rect);
        canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress!, false, arc);
      }
    }

    final hex = _hexagon(c, hexR);

    // Glow.
    canvas.drawPath(
      hex,
      Paint()
        ..color = tier.glow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, hexR * 0.25),
    );

    // Body.
    final bounds = Rect.fromCircle(center: c, radius: hexR);
    canvas.drawPath(hex, Paint()..shader = tier.gradient.createShader(bounds));

    // Facets: lighter top half and darker bottom-right for a cut-gem feel.
    final facetTop = Path()
      ..moveTo(c.dx, c.dy - hexR)
      ..lineTo(c.dx + hexR * math.cos(-math.pi / 6), c.dy - hexR * 0.5)
      ..lineTo(c.dx, c.dy)
      ..lineTo(c.dx - hexR * math.cos(-math.pi / 6), c.dy - hexR * 0.5)
      ..close();
    canvas.drawPath(facetTop, Paint()..color = TierColors.facetLight);

    final facetBottom = Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(c.dx + hexR * math.cos(-math.pi / 6), c.dy + hexR * 0.5)
      ..lineTo(c.dx, c.dy + hexR)
      ..close();
    canvas.drawPath(facetBottom, Paint()..color = TierColors.facetShadow);

    // Inner bevel.
    canvas.drawPath(
      _hexagon(c, hexR * 0.78),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hexR * 0.04
        ..color = TierColors.bevel,
    );

    // Rim.
    canvas.drawPath(
      hex,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hexR * 0.05
        ..color = tier.primary,
    );
  }

  @override
  bool shouldRepaint(RankBadgePainter old) =>
      old.progress != progress || old.tier != tier || old.trackColor != trackColor;
}
