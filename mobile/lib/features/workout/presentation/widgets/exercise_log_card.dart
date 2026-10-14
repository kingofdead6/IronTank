import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/utils/units.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../exercises/presentation/exercise_picker_sheet.dart';
import '../../../exercises/presentation/widgets/exercise_image.dart';
import '../../../programs/data/program.dart';
import '../../../programs/presentation/widgets/program_exercise_sheet.dart' show restOptions;
import '../../application/active_workout_controller.dart';
import '../../data/workout_models.dart';
import 'set_row.dart';

/// One exercise in the active workout: header, column labels, set rows, add-set.
class ExerciseLogCard extends ConsumerWidget {
  const ExerciseLogCard({super.key, required this.exercise, required this.index, required this.unit});

  final WorkoutExercise exercise;
  final int index;
  final WeightUnit unit;

  ActiveWorkoutController _ctrl(WidgetRef ref) => ref.read(activeWorkoutProvider.notifier);

  Future<void> _menu(BuildContext context, WidgetRef ref, String action) async {
    final ctrl = _ctrl(ref);
    switch (action) {
      case 'swap':
        final picked = await showExercisePicker(context, multiple: false, title: 'Swap exercise');
        if (picked != null && picked.isNotEmpty) await ctrl.swapExercise(exercise.id, ExerciseSummary.fromExercise(picked.first));
      case 'rest':
        if (!context.mounted) return;
        final seconds = await showModalBottomSheet<int>(
          context: context,
          builder: (context) => _RestPicker(current: exercise.restSeconds),
        );
        if (seconds != null) ctrl.setExerciseRest(exercise.id, seconds);
      case 'notes':
        if (!context.mounted) return;
        final notes = await _editNotes(context, exercise.notes);
        if (notes != null) ctrl.setExerciseNotes(exercise.id, notes);
      case 'remove':
        ctrl.removeExercise(exercise.id);
        if (context.mounted) {
          showAppSnack(
            context,
            'Removed ${exercise.exercise.name}',
            action: SnackBarAction(label: 'Undo', onPressed: () => ctrl.insertExercise(index, exercise)),
          );
        }
    }
  }

  Future<String?> _editNotes(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exercise notes'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          decoration: const InputDecoration(hintText: 'Seat height, grip, how it felt…'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _pickRpe(BuildContext context, WidgetRef ref, WorkoutSet set) async {
    final value = await showModalBottomSheet<double>(
      context: context,
      builder: (context) => _RpePicker(current: set.rpe),
    );
    if (value == null) return;
    _ctrl(ref).setRpe(exercise.id, set.id, value < 0 ? null : value);
  }

  Widget _setRow(BuildContext context, WidgetRef ref, int i, int workingNumber) {
    final c = context.colors;
    final ctrl = _ctrl(ref);
    final set = exercise.sets[i];
    return Dismissible(
      key: ValueKey(set.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: c.danger.withValues(alpha: AppOpacity.subtle),
        child: Icon(Icons.delete_rounded, color: c.danger),
      ),
      onDismissed: (_) => ctrl.removeSet(exercise.id, set.id),
      child: SetRow(
        key: ValueKey('row-${set.id}'),
        index: i,
        workingNumber: workingNumber,
        set: set,
        previous: exercise.previousFor(i),
        unit: unit,
        isBodyweight: exercise.exercise.isBodyweight,
        actions: SetRowActions(
          onWeight: (kg) => ctrl.setWeight(exercise.id, set.id, kg),
          onReps: (r) => ctrl.setReps(exercise.id, set.id, r),
          onRpe: () => _pickRpe(context, ref, set),
          onCycleType: () => ctrl.cycleSetType(exercise.id, set.id),
          onToggle: () => ctrl.toggleSet(exercise.id, set.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final ctrl = _ctrl(ref);
    // Working-set numbers skip warm-ups: W, 1, 2, 3...
    final numbers = <int>[];
    var working = 0;
    for (final set in exercise.sets) {
      if (set.type != SetType.warmup) working++;
      numbers.add(working);
    }

    return GlassCard(
      blur: false,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.xs, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push(Routes.exercise(exercise.exercise.id)),
                child: ExerciseThumb(url: exercise.exercise.image, size: AppSizes.avatar),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.exercise.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        if (exercise.targetReps != null)
                          Text('${exercise.targetReps} reps', style: context.text.bodySmall?.copyWith(color: c.accent)),
                        Text(
                          '${exercise.completedSets}/${exercise.sets.length} sets · ${exercise.restSeconds}s rest',
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Exercise options',
                icon: Icon(Icons.more_horiz_rounded, color: c.textSecondary),
                onSelected: (v) => _menu(context, ref, v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'swap', child: ListTile(leading: Icon(Icons.swap_horiz_rounded), title: Text('Swap exercise'))),
                  PopupMenuItem(value: 'rest', child: ListTile(leading: Icon(Icons.timer_outlined), title: Text('Rest time'))),
                  PopupMenuItem(value: 'notes', child: ListTile(leading: Icon(Icons.notes_rounded), title: Text('Notes'))),
                  PopupMenuItem(value: 'remove', child: ListTile(leading: Icon(Icons.delete_outline_rounded), title: Text('Remove'))),
                ],
              ),
            ],
          ),
          if (exercise.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm, right: AppSpacing.md),
              child: Text(exercise.notes, style: context.text.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
            ),
          const SizedBox(height: AppSpacing.md),
          _HeaderRow(unit: unit, isBodyweight: exercise.exercise.isBodyweight),
          const SizedBox(height: AppSpacing.xs),
          for (var i = 0; i < exercise.sets.length; i++) _setRow(context, ref, i, numbers[i]),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => ctrl.addSet(exercise.id),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add set'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.unit, required this.isBodyweight});

  final WeightUnit unit;
  final bool isBodyweight;

  @override
  Widget build(BuildContext context) {
    final style = context.text.labelSmall;
    Widget cell(String label, {int? flex, double? width}) {
      final text = Text(label, textAlign: TextAlign.center, style: style, overflow: TextOverflow.ellipsis);
      return width != null ? SizedBox(width: width, child: text) : Expanded(flex: flex!, child: text);
    }

    return ExcludeSemantics(
      child: Row(
        children: [
          cell('SET', width: SetColumns.badge),
          cell('PREVIOUS', flex: SetColumns.previousFlex),
          cell(isBodyweight ? '+${unit.label.toUpperCase()}' : unit.label.toUpperCase(), flex: SetColumns.fieldFlex),
          const SizedBox(width: AppSpacing.xs),
          cell('REPS', flex: SetColumns.fieldFlex),
          cell('RPE', width: SetColumns.rpe),
          const SizedBox(width: SetColumns.check),
        ],
      ),
    );
  }
}

/// RPE chips 6–10 in half steps; returns -1 to clear.
class _RpePicker extends StatelessWidget {
  const _RpePicker({this.current});

  final double? current;

  static const _values = [6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0];

  static String _describe(double v) => switch (v) {
    >= 10 => 'Max effort, no reps left',
    >= 9 => '1 rep left',
    >= 8 => '2 reps left',
    >= 7 => '3 reps left',
    _ => '4+ reps left',
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Rate of perceived exertion', style: context.text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(current == null ? 'How hard was that set?' : _describe(current!), style: context.text.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final v in _values)
                  ChoiceChip(
                    label: Text(Units.formatNumber(v)),
                    tooltip: _describe(v),
                    selected: current == v,
                    onSelected: (_) => Navigator.pop(context, v),
                  ),
              ],
            ),
            if (current != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: () => Navigator.pop(context, -1.0), child: const Text('Clear RPE')),
              ),
          ],
        ),
      ),
    );
  }
}

class _RestPicker extends StatelessWidget {
  const _RestPicker({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Rest between sets', style: context.text.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final s in restOptions)
                  AnimatedScale(
                    duration: AppMotion.fast,
                    scale: s == current ? 1.05 : 1,
                    child: ChoiceChip(
                      label: Text(s < 60 ? '${s}s' : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}'),
                      selected: s == current,
                      onSelected: (_) => Navigator.pop(context, s),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
