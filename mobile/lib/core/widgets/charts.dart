import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/motion.dart';

/// Headroom above/below the data range, as a fraction of the range.
const double _chartPadding = 0.15;

/// Shared chart grid/axis styling.
FlGridData chartGrid(BuildContext context, {double? interval}) => FlGridData(
  drawVerticalLine: false,
  horizontalInterval: interval,
  getDrawingHorizontalLine: (_) => FlLine(color: context.colors.chartGrid, strokeWidth: AppSizes.borderWidth),
);

/// fl_chart only animates *between* datasets, so these charts first render a
/// flat baseline and then switch to the real data, which makes them draw in.
mixin ChartDrawIn<T extends StatefulWidget> on State<T> {
  bool shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => shown = true);
    });
  }
}

/// Smooth gradient line chart with an area fill and touch tooltips.
class AnimatedLineChart extends StatefulWidget {
  const AnimatedLineChart({
    super.key,
    required this.points,
    required this.bottomLabel,
    required this.valueLabel,
    this.height = AppSizes.chartHeight,
    this.colors,
    this.showDots = true,
  });

  /// x is an ordinal or time value; y the metric.
  final List<FlSpot> points;

  /// Label for an x value on the bottom axis.
  final String Function(double x) bottomLabel;

  /// Label for a y value (axis + tooltip).
  final String Function(double y) valueLabel;

  final double height;
  final List<Color>? colors;
  final bool showDots;

  @override
  State<AnimatedLineChart> createState() => _AnimatedLineChartState();
}

class _AnimatedLineChartState extends State<AnimatedLineChart> with ChartDrawIn {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final colors = widget.colors ?? [c.accentStart, c.accentEnd];
    final ys = widget.points.map((p) => p.y);
    final minY = ys.isEmpty ? 0.0 : ys.reduce(math.min);
    final maxY = ys.isEmpty ? 1.0 : ys.reduce(math.max);
    final pad = math.max((maxY - minY) * _chartPadding, 1.0);
    final lo = math.max(0.0, minY - pad);
    final hi = maxY + pad;
    final spots = shown ? widget.points : widget.points.map((p) => FlSpot(p.x, lo)).toList();
    final xs = widget.points.map((p) => p.x);
    final labelEvery = math.max(1, (widget.points.length / 4).ceil());

    return SizedBox(
      height: widget.height,
      child: Semantics(
        label: 'Chart, ${widget.points.length} points, latest ${widget.points.isEmpty ? '-' : widget.valueLabel(widget.points.last.y)}',
        child: LineChart(
          duration: AppMotion.chart,
          curve: AppMotion.emphasized,
          LineChartData(
            minY: lo,
            maxY: hi,
            minX: xs.isEmpty ? 0 : xs.reduce(math.min),
            maxX: xs.isEmpty ? 1 : xs.reduce(math.max),
            gridData: chartGrid(context, interval: (hi - lo) / 3),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: AppSpacing.xxxl,
                  interval: (hi - lo) / 3,
                  getTitlesWidget: (v, meta) => v == meta.min || v == meta.max
                      ? const SizedBox.shrink()
                      : SideTitleWidget(meta: meta, child: Text(widget.valueLabel(v), style: context.text.bodySmall)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: AppSpacing.xl,
                  interval: 1,
                  getTitlesWidget: (v, meta) {
                    final i = widget.points.indexWhere((p) => p.x == v);
                    if (i < 0 || (i % labelEvery != 0 && i != widget.points.length - 1)) return const SizedBox.shrink();
                    return SideTitleWidget(meta: meta, child: Text(widget.bottomLabel(v), style: context.text.bodySmall));
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => c.surfaceHigh,
                tooltipBorderRadius: AppRadii.smAll,
                getTooltipItems: (spots) => spots
                    .map((s) => LineTooltipItem(
                          '${widget.valueLabel(s.y)}\n${widget.bottomLabel(s.x)}',
                          context.text.bodySmall!.copyWith(color: c.textPrimary),
                        ))
                    .toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                preventCurveOverShooting: true,
                barWidth: AppSizes.ringStrokeSm / 2,
                isStrokeCapRound: true,
                gradient: LinearGradient(colors: colors),
                dotData: FlDotData(
                  show: widget.showDots,
                  getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                    radius: AppSizes.ringStrokeSm / 2,
                    color: c.background,
                    strokeWidth: AppSizes.borderWidth * 2,
                    strokeColor: colors.last,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [colors.first.withValues(alpha: AppOpacity.subtle), colors.last.withValues(alpha: 0)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient bar chart (weekly volume, sessions).
class AnimatedBarChart extends StatefulWidget {
  const AnimatedBarChart({
    super.key,
    required this.values,
    required this.bottomLabel,
    required this.valueLabel,
    this.height = AppSizes.chartHeight,
    this.highlightLast = true,
  });

  final List<double> values;
  final String Function(int index) bottomLabel;
  final String Function(double value) valueLabel;
  final double height;

  /// Draws the last bar (current period) in full accent, others muted.
  final bool highlightLast;

  @override
  State<AnimatedBarChart> createState() => _AnimatedBarChartState();
}

class _AnimatedBarChartState extends State<AnimatedBarChart> with ChartDrawIn {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final maxV = widget.values.isEmpty ? 1.0 : math.max(widget.values.reduce(math.max), 1.0);
    // Narrower bars when there are many periods.
    final barWidth = widget.values.length > 8 ? AppSpacing.md : AppSpacing.lg;

    return SizedBox(
      height: widget.height,
      child: Semantics(
        label: 'Bar chart, ${widget.values.length} bars',
        child: BarChart(
          duration: AppMotion.chart,
          curve: AppMotion.emphasized,
          BarChartData(
            maxY: maxV * (1 + _chartPadding),
            gridData: chartGrid(context, interval: maxV / 2),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: AppSpacing.xl,
                  getTitlesWidget: (v, meta) =>
                      SideTitleWidget(meta: meta, child: Text(widget.bottomLabel(v.toInt()), style: context.text.bodySmall)),
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => c.surfaceHigh,
                tooltipBorderRadius: AppRadii.smAll,
                getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                  widget.valueLabel(rod.toY),
                  context.text.bodySmall!.copyWith(color: c.textPrimary),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < widget.values.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: shown ? widget.values[i] : 0,
                      width: barWidth,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.sm / 2)),
                      gradient: !widget.highlightLast || i == widget.values.length - 1
                          ? LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [c.accentStart, c.accentEnd])
                          : null,
                      color: c.textMuted.withValues(alpha: AppOpacity.subtle * 2),
                      backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxV * (1 + _chartPadding), color: c.glassFill),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
