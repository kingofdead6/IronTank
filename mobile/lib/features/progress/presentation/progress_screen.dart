import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/donut_chart.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/rank_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/staggered.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/training_heatmap.dart';
import '../../../core/widgets/value_stepper.dart';
import '../../auth/application/auth_controller.dart';
import '../../exercises/application/exercise_providers.dart';
import '../../exercises/data/exercise.dart';
import '../../exercises/presentation/exercise_picker_sheet.dart';
import '../application/progress_providers.dart';
import '../data/progress_models.dart';
import '../data/progress_repository.dart';

/// Period options for the Progress tab, in weeks.
const _periods = [4, 12, 26];

/// Progress tab: training totals and every chart in one scroll.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _weeks = 12;

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(statsOverviewProvider(_weeks));
    final unit = ref.watch(currentUserProvider)?.unit ?? WeightUnit.kg;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () {
              ref
                ..invalidate(ranksProvider)
                ..invalidate(bodyweightHistoryProvider);
              return ref.refresh(statsOverviewProvider(_weeks).future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xl, AppSpacing.screen, AppSpacing.bottomNavClearance),
              children: [
                Text('Progress', style: context.text.displaySmall).entrance(),
                const SizedBox(height: AppSpacing.lg),
                SegmentedButton<int>(
                  segments: [for (final w in _periods) ButtonSegment(value: w, label: Text('${w}W'))],
                  selected: {_weeks},
                  onSelectionChanged: (s) => setState(() => _weeks = s.first),
                ).entrance(delay: AppMotion.stagger),
                const SizedBox(height: AppSpacing.lg),
                const _Shortcuts(),
                ...overview.when(
                  loading: () => [
                    const SizedBox(height: AppSpacing.lg),
                    const SkeletonList(count: 3, itemHeight: AppSizes.chartHeight, padding: EdgeInsets.zero),
                  ],
                  error: (e, _) => [ErrorState(error: e, onRetry: () => ref.invalidate(statsOverviewProvider(_weeks)))],
                  data: (o) => _sections(o, unit),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _sections(StatsOverview o, WeightUnit unit) {
    final sections = <Widget>[
      const SizedBox(height: AppSpacing.lg),
      StatGrid(
        children: [
          StatTile(label: 'Sessions', value: o.sessions, icon: Icons.event_available_rounded, caption: '${Units.formatNumber(o.avgSessionsPerWeek)} per week'),
          StatTile(
            label: 'Volume',
            value: Units.fromKg(o.volume, unit),
            unit: unit.label,
            icon: Icons.stacked_bar_chart_rounded,
            formatter: (v) => Units.volume(Units.toKg(v, unit), unit),
          ),
          StatTile(label: 'Week streak', value: o.streakWeeks, icon: Icons.local_fire_department_rounded, caption: '${Fmt.count(o.streakDays, 'day')} in a row'),
          StatTile(label: 'New PRs', value: o.prs, icon: Icons.emoji_events_rounded, caption: '${Fmt.integer(o.calories)} kcal burned'),
        ],
      ),
      if (o.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: AppSpacing.xl),
          child: EmptyState(
            icon: Icons.insights_rounded,
            title: 'No workouts in this period',
            message: 'Charts fill in as you log sessions. Try a longer period or start a workout.',
          ),
        )
      else ...[
        const SectionHeader(title: 'Weekly volume'),
        _ChartCard(
          child: AnimatedBarChart(
            key: ValueKey('volume-$_weeks'),
            values: [for (final w in o.weekly) Units.fromKg(w.volume, unit)],
            bottomLabel: (i) => _weekLabel(o.weekly, i),
            valueLabel: (v) => '${Units.volume(Units.toKg(v, unit), unit)} ${unit.label}',
          ),
        ),
        const SectionHeader(title: 'Sessions per week'),
        _ChartCard(
          child: AnimatedBarChart(
            key: ValueKey('sessions-$_weeks'),
            height: AppSizes.chartHeightSm,
            values: [for (final w in o.weekly) w.sessions.toDouble()],
            bottomLabel: (i) => _weekLabel(o.weekly, i),
            valueLabel: (v) => Fmt.count(v.round(), 'session'),
          ),
        ),
        _MuscleSection(shares: o.muscleDistribution),
        const SectionHeader(title: 'Training calendar'),
        GlassCard(
          child: TrainingHeatmap(
            from: o.from,
            to: o.to,
            volumeByDay: {for (final d in o.heatmap) TrainingHeatmap.dayKey(d.date): d.volume},
          ),
        ),
      ],
      _StrengthSection(unit: unit),
      _BodyweightSection(unit: unit),
    ];
    return [for (var i = 0; i < sections.length; i++) sections[i].staggered(i)];
  }

  /// Labels about four bars evenly, so 26 weeks stay readable.
  static String _weekLabel(List<WeeklyPoint> weeks, int i) {
    if (i < 0 || i >= weeks.length) return '';
    final every = (weeks.length / 4).ceil();
    final last = i == weeks.length - 1;
    if (!last && i % every != 0) return '';
    return last ? 'Now' : Fmt.dayMonth(weeks[i].weekStart);
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      GlassCard(padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm), child: child);
}

/// Ranks + Calories entry points.
class _Shortcuts extends ConsumerWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overall = ref.watch(ranksProvider).value?.overall;
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            onTap: () => context.push(Routes.ranks),
            semanticLabel: 'Open ranks',
            child: Row(
              children: [
                RankBadge(
                  tierIndex: overall?.ranked ?? false ? overall!.tierIndex : null,
                  tierName: overall?.tier,
                  size: AppSizes.avatar,
                  showProgress: false,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ranks', style: context.text.titleSmall),
                      Text(overall?.tier ?? 'Unranked', style: context.text.bodySmall, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: GlassCard(
            onTap: () => context.push(Routes.calories),
            semanticLabel: 'Open calories',
            child: Row(
              children: [
                Container(
                  width: AppSizes.avatar,
                  height: AppSizes.avatar,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: context.colors.accentGradient),
                  child: Icon(Icons.restaurant_rounded, color: context.colors.onAccent, size: AppSizes.iconMd),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Calories', style: context.text.titleSmall),
                      Text('Food & targets', style: context.text.bodySmall, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MuscleSection extends StatelessWidget {
  const _MuscleSection({required this.shares});

  final List<MuscleShare> shares;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sorted = [...shares]..sort((a, b) => b.percent.compareTo(a.percent));
    final total = sorted.fold<double>(0, (s, m) => s + m.sets);
    Color colorAt(int i) =>
        Color.lerp(c.accentStart, c.accentEnd, sorted.length < 2 ? 0 : i / (sorted.length - 1))!
            .withValues(alpha: 1 - AppOpacity.faint * i);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Muscle distribution'),
        GlassCard(
          child: Row(
            children: [
              AnimatedDonutChart(
                size: AppSizes.chartHeightSm,
                slices: [for (var i = 0; i < sorted.length; i++) DonutSlice(label: sorted[i].group, value: sorted[i].percent, color: colorAt(i))],
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Units.formatNumber(total, decimals: 0), style: context.numbers.medium),
                    Text('sets', style: context.text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < sorted.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                        child: Row(
                          children: [
                            Container(
                              width: AppSpacing.sm + AppSpacing.xxs,
                              height: AppSpacing.sm + AppSpacing.xxs,
                              decoration: BoxDecoration(color: colorAt(i), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: Text(labelize(sorted[i].group), style: context.text.bodyMedium)),
                            Text('${sorted[i].percent.round()}%', style: context.numbers.small),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// e1RM over time for a ranked lift (or any exercise picked by the user).
class _StrengthSection extends ConsumerStatefulWidget {
  const _StrengthSection({required this.unit});

  final WeightUnit unit;

  @override
  ConsumerState<_StrengthSection> createState() => _StrengthSectionState();
}

class _StrengthSectionState extends ConsumerState<_StrengthSection> {
  String? _exerciseId;
  String? _customName;

  Future<void> _pickOther() async {
    final picked = await showExercisePicker(context, multiple: false, title: 'Chart an exercise');
    if (picked == null || picked.isEmpty) return;
    setState(() {
      _exerciseId = picked.first.id;
      _customName = picked.first.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ranks = ref.watch(ranksProvider).value;
    final lifts = ranks?.lifts.where((l) => l.exerciseId != null).toList() ?? const <LiftRank>[];
    final selected = _exerciseId ?? (lifts.isEmpty ? null : lifts.first.exerciseId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Estimated 1RM'),
        SizedBox(
          height: AppSizes.chipHeight + AppSpacing.xs,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final l in lifts)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(l.name),
                    selected: selected == l.exerciseId,
                    onSelected: (_) => setState(() {
                      _exerciseId = l.exerciseId;
                      _customName = null;
                    }),
                  ),
                ),
              if (_customName != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(label: Text(_customName!), selected: true, onSelected: (_) {}),
                ),
              ActionChip(avatar: const Icon(Icons.search_rounded, size: AppSizes.iconSm), label: const Text('Other'), onPressed: _pickOther),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (selected == null)
          const GlassCard(
            child: EmptyState(
              compact: true,
              icon: Icons.show_chart_rounded,
              title: 'No strength data yet',
              message: 'Log bench, squat or deadlift to see your estimated 1RM trend — or pick any exercise.',
            ),
          )
        else
          _E1rmChart(exerciseId: selected, unit: widget.unit),
      ],
    );
  }
}

class _E1rmChart extends ConsumerWidget {
  const _E1rmChart({required this.exerciseId, required this.unit});

  final String exerciseId;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(exerciseHistoryProvider(exerciseId));
    return history.when(
      loading: () => const Shimmer(child: SkeletonBox(height: AppSizes.chartHeight, radius: AppRadii.lgAll)),
      error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(exerciseHistoryProvider(exerciseId))),
      data: (points) {
        final pts = points.where((p) => p.bestE1rm != null).toList();
        if (pts.length < 2) {
          return const GlassCard(
            child: EmptyState(compact: true, icon: Icons.show_chart_rounded, title: 'Not enough data', message: 'Log this exercise in at least two sessions.'),
          );
        }
        final first = Units.fromKg(pts.first.bestE1rm!, unit);
        final last = Units.fromKg(pts.last.bestE1rm!, unit);
        final delta = last - first;
        return GlassCard(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.md, bottom: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(Units.formatNumber(last), style: context.numbers.large),
                    const SizedBox(width: AppSpacing.xs),
                    Text(unit.label, style: context.numbers.unit),
                    const Spacer(),
                    Text(
                      '${delta >= 0 ? '+' : ''}${Units.formatNumber(delta)} ${unit.label}',
                      style: context.text.labelLarge?.copyWith(color: delta >= 0 ? context.colors.success : context.colors.danger),
                    ),
                  ],
                ),
              ),
              AnimatedLineChart(
                key: ValueKey(exerciseId),
                points: [for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), Units.fromKg(pts[i].bestE1rm!, unit))],
                bottomLabel: (x) => Fmt.dayMonth(pts[x.round().clamp(0, pts.length - 1)].date),
                valueLabel: (y) => '${Units.formatNumber(y, decimals: 0)} ${unit.label}',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BodyweightSection extends ConsumerWidget {
  const _BodyweightSection({required this.unit});

  final WeightUnit unit;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final current = ref.read(currentUserProvider)?.bodyweightKg ?? 75;
    final kg = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BodyweightSheet(initialKg: current, unit: unit),
    );
    if (kg == null) return;
    try {
      await ref.read(progressRepositoryProvider).addBodyweight(kg);
      ref.read(bodyweightRevisionProvider.notifier).bump();
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (context.mounted) showAppSnack(context, 'Bodyweight logged: ${Units.weight(kg, unit)}');
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(bodyweightHistoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Bodyweight', actionLabel: 'Log weight', onAction: () => _add(context, ref)),
        history.when(
          loading: () => const Shimmer(child: SkeletonBox(height: AppSizes.chartHeightSm, radius: AppRadii.lgAll)),
          error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(bodyweightHistoryProvider)),
          data: (entries) {
            if (entries.length < 2) {
              return GlassCard(
                child: EmptyState(
                  compact: true,
                  icon: Icons.monitor_weight_outlined,
                  title: entries.isEmpty ? 'No weigh-ins yet' : 'One weigh-in so far',
                  message: 'Log your weight regularly to see the trend. It also keeps your ranks accurate.',
                  actionLabel: 'Log weight',
                  onAction: () => _add(context, ref),
                ),
              );
            }
            return _ChartCard(
              child: AnimatedLineChart(
                height: AppSizes.chartHeightSm,
                colors: [context.colors.success, context.colors.accentStart],
                points: [for (var i = 0; i < entries.length; i++) FlSpot(i.toDouble(), Units.fromKg(entries[i].kg, unit))],
                bottomLabel: (x) => Fmt.dayMonth(entries[x.round().clamp(0, entries.length - 1)].date),
                valueLabel: (y) => '${Units.formatNumber(y)} ${unit.label}',
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BodyweightSheet extends StatefulWidget {
  const _BodyweightSheet({required this.initialKg, required this.unit});

  final double initialKg;
  final WeightUnit unit;

  @override
  State<_BodyweightSheet> createState() => _BodyweightSheetState();
}

class _BodyweightSheetState extends State<_BodyweightSheet> {
  late double _value = double.parse(Units.fromKg(widget.initialKg, widget.unit).toStringAsFixed(1));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Log bodyweight', style: context.text.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            ValueStepper(
              label: 'Today',
              value: _value,
              min: Units.fromKg(30, widget.unit).roundToDouble(),
              max: Units.fromKg(250, widget.unit).roundToDouble(),
              step: widget.unit == WeightUnit.kg ? 0.1 : 0.2,
              decimals: 1,
              unit: widget.unit.label,
              onChanged: (v) => setState(() => _value = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            GradientButton(label: 'Save', icon: Icons.check_rounded, onPressed: () => Navigator.pop(context, Units.toKg(_value, widget.unit))),
          ],
        ),
      ),
    );
  }
}
