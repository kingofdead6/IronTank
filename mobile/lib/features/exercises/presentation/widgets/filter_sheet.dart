import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../application/exercise_providers.dart';
import '../../data/exercise.dart';

/// Bottom sheet with every filter dimension. Returns the new filters on apply.
Future<ExerciseFilters?> showExerciseFilterSheet(BuildContext context, ExerciseFilters current) {
  return showModalBottomSheet<ExerciseFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FilterSheet(initial: current),
  );
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});

  final ExerciseFilters initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late ExerciseFilters _f = widget.initial;

  Set<String> _toggle(Set<String> set, String v) => set.contains(v) ? ({...set}..remove(v)) : {...set, v};

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(exerciseFilterOptionsProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scroll) => options.when(
        loading: () => const Padding(padding: AppSpacing.screenPadding, child: SkeletonList(count: 4)),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(exerciseFilterOptionsProvider)),
        data: (o) => Column(
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                padding: AppSpacing.screenPadding,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Filters', style: context.text.headlineSmall)),
                      TextButton(
                        onPressed: () => setState(() => _f = ExerciseFilters(query: _f.query)),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('My custom exercises only'),
                    value: _f.customOnly,
                    onChanged: (v) => setState(() => _f = _f.copyWith(customOnly: v)),
                  ),
                  _Group(
                    title: 'Category',
                    values: o.categories,
                    selected: _f.categories,
                    onToggle: (v) => setState(() => _f = _f.copyWith(categories: _toggle(_f.categories, v))),
                  ),
                  _Group(
                    title: 'Muscle',
                    values: o.muscles,
                    selected: _f.muscles,
                    onToggle: (v) => setState(() => _f = _f.copyWith(muscles: _toggle(_f.muscles, v))),
                  ),
                  _Group(
                    title: 'Equipment',
                    values: o.equipment,
                    selected: _f.equipment,
                    onToggle: (v) => setState(() => _f = _f.copyWith(equipment: _toggle(_f.equipment, v))),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.lg),
              child: GradientButton(
                label: _f.activeCount == 0 ? 'Show all exercises' : 'Apply ${_f.activeCount} filter${_f.activeCount == 1 ? '' : 's'}',
                onPressed: () => Navigator.pop(context, _f),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.values, required this.selected, required this.onToggle});

  final String title;
  final List<String> values;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(title.toUpperCase(), style: context.text.labelSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final v in values)
              FilterChip(label: Text(labelize(v)), selected: selected.contains(v), onSelected: (_) => onToggle(v)),
          ],
        ),
      ],
    );
  }
}
