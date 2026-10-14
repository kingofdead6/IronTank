import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/staggered.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../auth/application/auth_controller.dart';
import '../application/workout_providers.dart';
import '../data/workout_history.dart';
import '../data/workout_models.dart';
import '../data/workout_repository.dart';

/// Read-only view of a saved workout, with delete.
class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});

  final String workoutId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete workout?'),
        content: const Text('Its sets are removed and your records and ranks are recalculated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(workoutRepositoryProvider).delete(workoutId);
      ref.read(workoutRevisionProvider.notifier).bump();
      if (context.mounted) context.pop();
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workoutDetailProvider(workoutId));
    final unit = ref.watch(currentUserProvider)?.unit ?? WeightUnit.kg;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        actions: [
          IconButton(tooltip: 'Delete workout', onPressed: () => _delete(context, ref), icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: async.when(
            loading: () => const SkeletonList(count: 4),
            error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(workoutDetailProvider(workoutId))),
            data: (w) => _body(context, w, unit),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WorkoutSummary w, WeightUnit unit) {
    final c = context.colors;
    final items = <Widget>[
      Text(w.name, style: context.text.displaySmall),
      Text('${Fmt.weekdayDayMonth(w.startedAt)} · ${Fmt.time(w.startedAt)}', style: context.text.bodyMedium),
      const SizedBox(height: AppSpacing.lg),
      Row(
        children: [
          Expanded(child: StatTile(label: 'Time', value: w.durationSec ~/ 60, unit: 'min', icon: Icons.timer_rounded)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: StatTile(
              label: 'Volume',
              value: Units.fromKg(w.totalVolume, unit),
              unit: unit.label,
              icon: Icons.stacked_bar_chart_rounded,
              formatter: (v) => Units.volume(Units.toKg(v, unit), unit),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: StatTile(label: 'kcal', value: w.caloriesBurned, icon: Icons.local_fire_department_rounded)),
        ],
      ),
      if (w.notes.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        GlassCard(child: Text(w.notes, style: context.text.bodyMedium)),
      ],
      const SizedBox(height: AppSpacing.lg),
      for (final e in w.exercises)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: GlassCard(
            blur: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name, style: context.text.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < e.sets.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                    child: Row(
                      children: [
                        SizedBox(
                          width: AppSizes.iconXl,
                          child: Text(
                            e.sets[i].type == SetType.working ? '${i + 1}' : e.sets[i].type.short,
                            style: context.numbers.small.copyWith(color: c.textMuted),
                          ),
                        ),
                        Text(
                          '${Units.weight(e.sets[i].weightKg ?? 0, unit)} × ${e.sets[i].reps ?? 0}',
                          style: context.numbers.small,
                        ),
                        if (e.sets[i].rpe != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text('@ ${Units.formatNumber(e.sets[i].rpe!)}', style: context.text.bodySmall?.copyWith(color: c.accent)),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xxl),
      children: [for (var i = 0; i < items.length; i++) items[i].staggered(i)],
    );
  }
}
