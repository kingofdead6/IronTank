import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/staggered.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../auth/application/auth_controller.dart';
import '../application/exercise_providers.dart';
import '../data/exercise.dart';
import '../data/exercise_repository.dart';
import 'widgets/exercise_image.dart';

/// Exercise detail: hero gallery, muscles, records, e1RM trend and instructions.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId, this.initial});

  final String exerciseId;

  /// Passed from the library so the hero and header render instantly.
  final Exercise? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(exerciseDetailProvider(exerciseId));
    final exercise = async.value ?? initial;

    return Scaffold(
      body: AppBackground(
        child: exercise == null
            ? async.hasError
                  ? SafeArea(child: ErrorState(error: async.error!, onRetry: () => ref.invalidate(exerciseDetailProvider(exerciseId))))
                  : const SafeArea(child: SkeletonList(count: 5, itemHeight: AppSizes.chartHeight))
            : _Body(exercise: exercise),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.exercise});

  final Exercise exercise;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete exercise?'),
        content: Text('"${exercise.name}" will be removed from your library. Past workouts keep their history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(exerciseRepositoryProvider).deleteCustom(exercise.id);
      ref.read(exerciseLibraryProvider.notifier).remove(exercise.id);
      if (context.mounted) context.pop();
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final unit = ref.watch(currentUserProvider)?.unit ?? WeightUnit.kg;
    final sections = <Widget>[
      Text(exercise.name, style: context.text.headlineLarge),
      const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final m in exercise.primaryMuscles) _MuscleChip(label: labelize(m), primary: true),
          for (final m in exercise.secondaryMuscles) _MuscleChip(label: labelize(m), primary: false),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      Row(
        children: [
          _Info(icon: Icons.fitness_center_rounded, label: labelize(exercise.equipment)),
          _Info(icon: Icons.signal_cellular_alt_rounded, label: labelize(exercise.level)),
          _Info(icon: Icons.category_rounded, label: labelize(exercise.category)),
        ],
      ),
      if (exercise.isBodyweight)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Text(
            'Bodyweight exercise: log added weight (negative for assistance).',
            style: context.text.bodySmall?.copyWith(color: c.textSecondary),
          ),
        ),
      _RecordsSection(exerciseId: exercise.id, unit: unit),
      _TrendSection(exerciseId: exercise.id, unit: unit),
      if (exercise.instructions.isNotEmpty) ...[
        const SectionHeader(title: 'How to do it'),
        for (var i = 0; i < exercise.instructions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: AppSizes.iconLg,
                  height: AppSizes.iconLg,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c.accentSoft),
                  child: Text('${i + 1}', style: context.numbers.small.copyWith(color: c.accent)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(exercise.instructions[i], style: context.text.bodyLarge)),
              ],
            ),
          ),
      ],
      const SizedBox(height: AppSpacing.xxxl),
    ];

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          stretch: true,
          expandedHeight: AppSizes.timerRingSize + AppSpacing.huge,
          backgroundColor: c.background,
          leading: const _CircleBack(),
          actions: [
            if (exercise.isCustom)
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (v) => _delete(context, ref),
                itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete exercise'))],
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [StretchMode.zoomBackground],
            background: _Gallery(exercise: exercise),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xl, AppSpacing.screen, 0),
          sliver: SliverList.list(children: [for (var i = 0; i < sections.length; i++) sections[i].staggered(i)]),
        ),
      ],
    );
  }
}

class _CircleBack extends StatelessWidget {
  const _CircleBack();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: IconButton.filledTonal(
        tooltip: 'Back',
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    );
  }
}

/// Image gallery. With two frames (start/end position) it auto-alternates,
/// reading like a looping demo of the movement. Swipe to step manually.
class _Gallery extends StatefulWidget {
  const _Gallery({required this.exercise});

  final Exercise exercise;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _pages = PageController();
  Timer? _loop;
  int _index = 0;

  List<String> get _images => widget.exercise.images;

  @override
  void initState() {
    super.initState();
    if (_images.length > 1) {
      // Wait for the hero flight before starting the loop.
      _loop = Timer.periodic(AppMotion.slower * 2, (_) {
        if (!_pages.hasClients) return;
        final next = (_index + 1) % _images.length;
        _pages.animateToPage(next, duration: AppMotion.slow, curve: AppMotion.standard);
      });
    }
  }

  @override
  void dispose() {
    _loop?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<UserScrollNotification>(
          onNotification: (_) {
            _loop?.cancel();
            return false;
          },
          child: PageView.builder(
            controller: _pages,
            itemCount: _images.isEmpty ? 1 : _images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final image = ExerciseImage(url: _images.isEmpty ? null : _images[i]);
              // Only the first frame is the hero target.
              return i == 0 ? Hero(tag: widget.exercise.heroTag, child: image) : image;
            },
          ),
        ),
        // Fade into the page background.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: AppSpacing.huge,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.background.withValues(alpha: 0), c.background],
                ),
              ),
            ),
          ),
        ),
        if (_images.length > 1)
          Positioned(
            bottom: AppSpacing.lg,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _images.length; i++)
                  AnimatedContainer(
                    duration: AppMotion.medium,
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                    width: i == _index ? AppSpacing.lg : AppSpacing.sm,
                    height: AppSpacing.xs + AppSpacing.xxs,
                    decoration: BoxDecoration(
                      borderRadius: AppRadii.pillAll,
                      color: i == _index ? c.accent : c.textMuted,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MuscleChip extends StatelessWidget {
  const _MuscleChip({required this.label, required this.primary});

  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs + AppSpacing.xxs),
      decoration: BoxDecoration(
        gradient: primary ? c.accentGradient : null,
        color: primary ? null : c.glassFill,
        borderRadius: AppRadii.pillAll,
        border: primary ? null : Border.all(color: c.glassBorder),
      ),
      child: Text(label, style: context.text.labelMedium?.copyWith(color: primary ? c.onAccent : c.textSecondary)),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: AppSizes.iconSm, color: context.colors.textMuted),
          const SizedBox(width: AppSpacing.xs),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}

class _RecordsSection extends ConsumerWidget {
  const _RecordsSection({required this.exerciseId, required this.unit});

  final String exerciseId;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(exerciseRecordsProvider(exerciseId));
    String w(double v) => Units.formatNumber(Units.fromKg(v, unit));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'My records'),
        records.when(
          loading: () => const Shimmer(child: SkeletonBox(height: AppSizes.chartHeightSm / 1.2, radius: AppRadii.lgAll)),
          error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(exerciseRecordsProvider(exerciseId))),
          data: (r) {
            if (r.bests.isEmpty) {
              return const GlassCard(
                child: EmptyState(
                  compact: true,
                  icon: Icons.emoji_events_outlined,
                  title: 'No records yet',
                  message: 'Log this exercise in a workout and your bests will appear here.',
                ),
              );
            }
            final b = r.bests;
            final celebrated = r.history.where((e) => !e.isBaseline).take(5).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Est. 1RM',
                        value: Units.fromKg(b.e1rm?.value ?? 0, unit),
                        unit: unit.label,
                        icon: Icons.trending_up_rounded,
                        formatter: (v) => Units.formatNumber(v),
                        caption: b.e1rm?.weight == null ? null : 'from ${w(b.e1rm!.weight!)} × ${b.e1rm!.reps}',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatTile(
                        label: 'Heaviest',
                        value: Units.fromKg(b.maxWeight?.value ?? 0, unit),
                        unit: unit.label,
                        icon: Icons.fitness_center_rounded,
                        formatter: (v) => Units.formatNumber(v),
                        caption: b.maxWeight?.reps == null ? null : '× ${b.maxWeight!.reps} reps',
                      ),
                    ),
                  ],
                ),
                if (b.maxVolumeSet != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  StatTile(
                    label: 'Best set',
                    value: Units.fromKg(b.maxVolumeSet!.value, unit),
                    unit: '${unit.label} volume',
                    icon: Icons.stacked_bar_chart_rounded,
                    caption: '${w(b.maxVolumeSet!.weight ?? 0)} ${unit.label} × ${b.maxVolumeSet!.reps ?? 0}',
                  ),
                ],
                if (celebrated.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  GlassCard(
                    child: Column(
                      children: [
                        for (final e in celebrated)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.emoji_events_rounded, color: context.colors.warning),
                            title: Text(_prLabel(e, unit)),
                            subtitle: Text(Fmt.relativeDay(e.achievedAt)),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// "New e1RM: 120 kg (+5)" style label for a record event.
String _prLabel(RecordEvent e, WeightUnit unit) {
  String w(double kg) => Units.weight(kg, unit);
  final delta = e.previousValue == null ? '' : ' (+${Units.formatNumber(e.type == 'maxRepsAtWeight' ? e.value - e.previousValue! : Units.fromKg(e.value - e.previousValue!, unit))})';
  return switch (e.type) {
    'maxWeight' => 'Heaviest: ${w(e.value)}$delta',
    'e1rm' => 'Est. 1RM: ${w(e.value)}$delta',
    'maxVolumeSet' => 'Best set: ${w(e.weight ?? 0)} × ${e.reps}$delta',
    'maxRepsAtWeight' => '${e.value.round()} reps @ ${w(e.weight ?? 0)}$delta',
    _ => 'Record',
  };
}

class _TrendSection extends ConsumerWidget {
  const _TrendSection({required this.exerciseId, required this.unit});

  final String exerciseId;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(exerciseHistoryProvider(exerciseId));
    return history.maybeWhen(
      data: (points) {
        final withE1rm = points.where((p) => p.bestE1rm != null).toList();
        if (withE1rm.length < 2) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Estimated 1RM'),
            GlassCard(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
              child: AnimatedLineChart(
                points: [
                  for (var i = 0; i < withE1rm.length; i++) FlSpot(i.toDouble(), Units.fromKg(withE1rm[i].bestE1rm!, unit)),
                ],
                bottomLabel: (x) => Fmt.dayMonth(withE1rm[x.round().clamp(0, withE1rm.length - 1)].date),
                valueLabel: (y) => '${Units.formatNumber(y, decimals: 0)} ${unit.label}',
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
