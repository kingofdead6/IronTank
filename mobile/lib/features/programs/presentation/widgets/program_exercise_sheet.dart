import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../data/program.dart';

/// Rest options offered as chips (seconds).
const restOptions = [30, 45, 60, 90, 120, 150, 180, 240];

/// Edits sets / rep range / rest / target RPE / notes of a planned exercise.
Future<ProgramExercise?> showProgramExerciseSheet(BuildContext context, ProgramExercise initial) =>
    showModalBottomSheet<ProgramExercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _Sheet(initial: initial),
    );

class _Sheet extends StatefulWidget {
  const _Sheet({required this.initial});

  final ProgramExercise initial;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  late ProgramExercise _e = widget.initial;
  late final _notes = TextEditingController(text: widget.initial.notes);

  static const _minRpe = 5.0;
  static const _maxRpe = 10.0;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_e.exercise.name, style: context.text.headlineSmall),
            const SizedBox(height: AppSpacing.xl),
            _Counter(label: 'Sets', value: _e.sets, min: 1, max: 20, onChanged: (v) => setState(() => _e = _e.copyWith(sets: v))),
            _Counter(
              label: 'Min reps',
              value: _e.repMin,
              min: 1,
              max: 100,
              onChanged: (v) => setState(() => _e = _e.copyWith(repMin: v, repMax: v > _e.repMax ? v : _e.repMax)),
            ),
            _Counter(
              label: 'Max reps',
              value: _e.repMax,
              min: 1,
              max: 100,
              onChanged: (v) => setState(() => _e = _e.copyWith(repMax: v, repMin: v < _e.repMin ? v : _e.repMin)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('REST', style: context.text.labelSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final s in restOptions)
                  ChoiceChip(
                    label: Text(s < 60 ? '${s}s' : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}'),
                    selected: _e.restSeconds == s,
                    onSelected: (_) => setState(() => _e = _e.copyWith(restSeconds: s)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Text('TARGET RPE', style: context.text.labelSmall),
                const Spacer(),
                Text(
                  _e.targetRpe == null ? 'Off' : _e.targetRpe!.toStringAsFixed(_e.targetRpe! % 1 == 0 ? 0 : 1),
                  style: context.numbers.small.copyWith(color: _e.targetRpe == null ? c.textMuted : c.accent),
                ),
                Switch(
                  value: _e.targetRpe != null,
                  onChanged: (on) => setState(() => _e = on ? _e.copyWith(targetRpe: 8) : _e.copyWith(clearRpe: true)),
                ),
              ],
            ),
            if (_e.targetRpe != null)
              Slider(
                value: _e.targetRpe!,
                min: _minRpe,
                max: _maxRpe,
                divisions: ((_maxRpe - _minRpe) * 2).round(),
                label: _e.targetRpe!.toString(),
                onChanged: (v) => setState(() => _e = _e.copyWith(targetRpe: v)),
              ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(label: 'Notes (optional)', controller: _notes, icon: Icons.notes_rounded),
            const SizedBox(height: AppSpacing.xl),
            GradientButton(
              label: 'Done',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.pop(context, _e.copyWith(notes: _notes.text.trim())),
            ),
          ],
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: '$value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(child: Text(label, style: context.text.titleMedium)),
            IconButton.filledTonal(
              tooltip: 'Decrease $label',
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: AppSizes.minTapTarget,
              child: Text('$value', textAlign: TextAlign.center, style: context.numbers.medium),
            ),
            IconButton.filledTonal(
              tooltip: 'Increase $label',
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
