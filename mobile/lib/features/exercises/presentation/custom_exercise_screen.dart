import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/staggered.dart';
import '../application/exercise_providers.dart';
import '../data/exercise.dart';
import '../data/exercise_repository.dart';

/// Create a user-defined exercise. Pops with the created [Exercise].
class CustomExerciseScreen extends ConsumerStatefulWidget {
  const CustomExerciseScreen({super.key});

  @override
  ConsumerState<CustomExerciseScreen> createState() => _CustomExerciseScreenState();
}

class _CustomExerciseScreenState extends ConsumerState<CustomExerciseScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _notes = TextEditingController();
  final Set<String> _primary = {};
  final Set<String> _secondary = {};
  String _equipment = 'barbell';
  String _category = 'strength';
  bool _bodyweight = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_primary.isEmpty) {
      await Haptics.warning();
      if (mounted) showAppSnack(context, 'Pick at least one primary muscle', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final created = await ref.read(exerciseRepositoryProvider).createCustom({
        'name': _name.text.trim(),
        'primaryMuscles': _primary.toList(),
        'secondaryMuscles': _secondary.difference(_primary).toList(),
        'equipment': _equipment,
        'category': _category,
        'isBodyweight': _bodyweight,
        if (_notes.text.trim().isNotEmpty) 'instructions': [_notes.text.trim()],
      });
      ref.read(exerciseLibraryProvider.notifier).prepend(created);
      await Haptics.setComplete();
      if (mounted) context.pop(created);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(exerciseFilterOptionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('New exercise')),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: options.when(
            loading: () => const SkeletonList(count: 4),
            error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(exerciseFilterOptionsProvider)),
            data: (o) {
              final fields = <Widget>[
                AppTextField(
                  label: 'Name',
                  controller: _name,
                  icon: Icons.edit_rounded,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v?.trim().length ?? 0) < 2 ? 'At least 2 characters' : null,
                ),
                _ChipGroup(
                  title: 'Primary muscles',
                  values: o.muscles,
                  selected: _primary,
                  onToggle: (m) => setState(() => _primary.contains(m) ? _primary.remove(m) : _primary.add(m)),
                ),
                _ChipGroup(
                  title: 'Secondary muscles (optional)',
                  values: o.muscles.where((m) => !_primary.contains(m)).toList(),
                  selected: _secondary,
                  onToggle: (m) => setState(() => _secondary.contains(m) ? _secondary.remove(m) : _secondary.add(m)),
                ),
                _SingleChoice(
                  title: 'Equipment',
                  values: o.equipment,
                  selected: _equipment,
                  onSelect: (v) => setState(() {
                    _equipment = v;
                    _bodyweight = v == 'body only';
                  }),
                ),
                _SingleChoice(
                  title: 'Category',
                  values: o.categories,
                  selected: _category,
                  onSelect: (v) => setState(() => _category = v),
                ),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: SwitchListTile(
                    title: const Text('Bodyweight exercise'),
                    subtitle: const Text('Weight is logged as added load (e.g. weighted pull-ups)'),
                    value: _bodyweight,
                    onChanged: (v) => setState(() => _bodyweight = v),
                  ),
                ),
                AppTextField(label: 'Notes / cues (optional)', controller: _notes, icon: Icons.notes_rounded),
                GradientButton(label: 'Create exercise', icon: Icons.check_rounded, loading: _saving, onPressed: _save),
              ];
              return Form(
                key: _form,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.xxl),
                  itemCount: fields.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
                  itemBuilder: (_, i) => fields[i].staggered(i),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({required this.title, required this.values, required this.selected, required this.onToggle});

  final String title;
  final List<String> values;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title.toUpperCase(), style: context.text.labelSmall),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final v in values) FilterChip(label: Text(labelize(v)), selected: selected.contains(v), onSelected: (_) => onToggle(v)),
        ],
      ),
    ],
  );
}

class _SingleChoice extends StatelessWidget {
  const _SingleChoice({required this.title, required this.values, required this.selected, required this.onSelect});

  final String title;
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title.toUpperCase(), style: context.text.labelSmall),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final v in values) ChoiceChip(label: Text(labelize(v)), selected: selected == v, onSelected: (_) => onSelect(v)),
        ],
      ),
    ],
  );
}
