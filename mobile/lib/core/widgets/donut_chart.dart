import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/motion.dart';
import 'charts.dart';

/// A labelled slice for [AnimatedDonutChart].
class DonutSlice {
  const DonutSlice({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;
}

/// Donut chart whose slices grow in from thin, equal wedges, with a centre label.
class AnimatedDonutChart extends StatefulWidget {
  const AnimatedDonutChart({super.key, required this.slices, this.center, this.size = AppSizes.chartHeight});

  final List<DonutSlice> slices;
  final Widget? center;
  final double size;

  @override
  State<AnimatedDonutChart> createState() => _AnimatedDonutChartState();
}

class _AnimatedDonutChartState extends State<AnimatedDonutChart> with ChartDrawIn {
  /// Hole radius as a fraction of the chart radius.
  static const double _holeFraction = 0.62;

  /// Ring thickness before the draw-in, as a fraction of its final thickness.
  static const double _initialRing = 0.4;

  @override
  Widget build(BuildContext context) {
    final radius = widget.size / 2;
    final ring = radius * (1 - _holeFraction);
    final visible = widget.slices.where((s) => s.value > 0).toList();
    return SizedBox.square(
      dimension: widget.size,
      child: Semantics(
        label: visible.map((s) => '${s.label} ${s.value.round()} percent').join(', '),
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              duration: AppMotion.chart,
              curve: AppMotion.emphasized,
              PieChartData(
                startDegreeOffset: -90,
                sectionsSpace: AppSizes.borderWidth * 2,
                centerSpaceRadius: radius * _holeFraction,
                sections: [
                  for (final s in visible)
                    PieChartSectionData(
                      value: shown ? s.value : 1,
                      color: shown ? s.color : s.color.withValues(alpha: 0),
                      radius: shown ? ring : ring * _initialRing,
                      showTitle: false,
                    ),
                ],
              ),
            ),
            ?widget.center,
          ],
        ),
      ),
    );
  }
}
