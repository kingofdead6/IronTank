import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/motion.dart';

/// GitHub-style calendar of training days: one column per week (Mon→Sun),
/// cell intensity by training volume. Columns fade in one after another.
class TrainingHeatmap extends StatelessWidget {
  const TrainingHeatmap({super.key, required this.from, required this.to, required this.volumeByDay});

  /// First day shown (a Monday) and the last day (today).
  final DateTime from;
  final DateTime to;

  /// Volume per local day ('YYYY-MM-DD'); absent days were rest days.
  final Map<String, double> volumeByDay;

  /// Intensity buckets for trained days.
  static const _levels = 4;

  /// Minimum opacity of a trained cell, so light days are still visible.
  static const double _minIntensity = 0.35;

  /// Scale cells grow from as they fade in.
  static const double _cellStartScale = 0.6;

  static const _weekdayLabels = ['M', '', 'W', '', 'F', '', 'S'];

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    final weeks = (end.difference(start).inDays ~/ 7) + 1;
    final maxVolume = volumeByDay.values.fold<double>(0, math.max);

    Color colorFor(DateTime day) {
      if (day.isAfter(end)) return Colors.transparent;
      final volume = volumeByDay[dayKey(day)];
      if (volume == null) return c.heatmapEmpty;
      final level = maxVolume <= 0 ? 1 : (volume / maxVolume * _levels).ceil().clamp(1, _levels);
      final t = level / _levels;
      return Color.lerp(c.accentStart, c.accentEnd, t)!.withValues(alpha: _minIntensity + (1 - _minIntensity) * t);
    }

    const gap = AppSizes.heatmapGap;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Grow cells to fill the width (up to 2× the base size); scroll if even the base size doesn't fit.
        final available = constraints.maxWidth - AppSpacing.md;
        final cell = (available / weeks - gap).clamp(AppSizes.heatmapCell, AppSizes.heatmapCell * 2).toDouble();
        return Semantics(
          label: '${volumeByDay.length} training days in the last $weeks weeks',
          excludeSemantics: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true, // Most recent weeks visible first.
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    for (final label in _weekdayLabels)
                      SizedBox(
                        height: cell + gap,
                        width: AppSpacing.md,
                        child: Text(label, style: context.text.labelSmall?.copyWith(letterSpacing: 0)),
                      ),
                  ],
                ),
                for (var w = 0; w < weeks; w++)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: AppMotion.slow + AppMotion.staggerDelay(w),
                    curve: AppMotion.enter,
                    builder: (_, t, child) => Opacity(
                      opacity: t,
                      child: Transform.scale(scale: _cellStartScale + (1 - _cellStartScale) * t, child: child),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(right: gap),
                      child: Column(
                        children: [
                          for (var d = 0; d < DateTime.daysPerWeek; d++)
                            Container(
                              width: cell,
                              height: cell,
                              margin: const EdgeInsets.only(bottom: gap),
                              decoration: BoxDecoration(
                                color: colorFor(start.add(Duration(days: w * DateTime.daysPerWeek + d))),
                                borderRadius: BorderRadius.all(Radius.circular(cell / 4)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
