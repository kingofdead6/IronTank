import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../../exercises/presentation/exercise_picker_sheet.dart';
import '../../exercises/presentation/widgets/exercise_image.dart';
import '../application/program_builder_controller.dart';
import '../data/program.dart';
import 'widgets/program_exercise_sheet.dart';

/// Create or edit a program: name → days → exercises → sets/reps/rest,
/// with drag-to-reorder for both days and exercises.
class ProgramBuilderScreen extends ConsumerStatefulWidget {
  const ProgramBuilderScreen({super.key, this.programId});

  /// null to create a new program.
  final String? programId;

  @override
  ConsumerState<ProgramBuilderScreen> createState() => _ProgramBuilderScreenState();
}

class _ProgramBuilderScreenState extends ConsumerState<ProgramBuilderScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  int _day = 0;
  bool _saving = false;
  bool _seeded = false;

  String get _key => widget.programId ?? '';
  ProgramBuilderController get _ctrl => ref.read(programBuilderProvider(_key).notifier);

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Fills the text fields once the draft has loaded.
  void _seed(ProgramDraft d) {
    if (_seeded) return;
    _seeded = true;
    _name.text = d.name;
    _description.text = d.description;
  }

  Future<void> _addExercises() async {
    final picked = await showExercisePicker(context);
    if (picked == null || picked.isEmpty) return;
    _ctrl.addExercises(_day, picked);
    await Haptics.tap();
  }

  Future<void> _editExercise(int index, ProgramExercise e) async {
    final updated = await showProgramExerciseSheet(context, e);
    if (updated != null) _ctrl.updateExercise(_day, index, updated);
  }

  Future<void> _renameDay(ProgramDay day) async {
    final controller = TextEditingController(text: day.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Day name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Push, Legs, Upper A'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) _ctrl.renameDay(_day, name);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = await _ctrl.save();
      await Haptics.setComplete();
      if (!mounted) return;
      showAppSnack(context, 'Program saved');
      if (widget.programId == null) {
        context.pushReplacement(Routes.program(saved.id));
      } else {
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    final draft = ref.read(programBuilderProvider(_key)).value;
    if (draft == null || !draft.dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your edits to this program will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(programBuilderProvider(_key));
    final draft = async.value;
    if (draft != null) _seed(draft);

    return PopScope(
      canPop: draft == null || !draft.dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.programId == null ? 'New program' : 'Edit program')),
        extendBodyBehindAppBar: true,
        body: AppBackground(
          child: SafeArea(
            child: async.when(
              loading: () => const SkeletonList(count: 4),
              error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(programBuilderProvider(_key))),
              data: _body,
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(ProgramDraft draft) {
    final c = context.colors;
    final day = _day.clamp(0, draft.days.length - 1);
    if (day != _day) _day = day;
    final current = draft.days[day];

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, 0),
                sliver: SliverList.list(
                  children: [
                    TextField(
                      controller: _name,
                      onChanged: _ctrl.setName,
                      textCapitalization: TextCapitalization.words,
                      style: context.text.headlineSmall,
                      decoration: const InputDecoration(hintText: 'Program name'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _description,
                      onChanged: _ctrl.setDescription,
                      maxLines: 2,
                      minLines: 1,
                      decoration: const InputDecoration(hintText: 'Description (optional)'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Text('Length', style: context.text.titleSmall),
                        const Spacer(),
                        IconButton.filledTonal(
                          tooltip: 'Fewer weeks',
                          onPressed: draft.weeks > 1 ? () => _ctrl.setWeeks(draft.weeks - 1) : null,
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        SizedBox(
                          width: AppSizes.minTapTarget * 1.6,
                          child: Text('${draft.weeks} wk', textAlign: TextAlign.center, style: context.numbers.small),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'More weeks',
                          onPressed: draft.weeks < 52 ? () => _ctrl.setWeeks(draft.weeks + 1) : null,
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('DAYS · hold and drag to reorder', style: context.text.labelSmall),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
              SliverToBoxAdapter(child: _DayStrip(draft: draft, selected: day, onSelect: (i) => setState(() => _day = i), ctrl: _ctrl)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(child: Text(current.name, style: context.text.titleLarge)),
                      IconButton(tooltip: 'Rename day', onPressed: () => _renameDay(current), icon: const Icon(Icons.edit_rounded)),
                      IconButton(
                        tooltip: 'Duplicate day',
                        onPressed: draft.days.length < ProgramBuilderController.maxDays ? () => _ctrl.duplicateDay(day) : null,
                        icon: const Icon(Icons.copy_rounded),
                      ),
                      IconButton(
                        tooltip: 'Delete day',
                        onPressed: draft.days.length > 1 ? () => _ctrl.removeDay(day) : null,
                        icon: Icon(Icons.delete_outline_rounded, color: draft.days.length > 1 ? c.danger : null),
                      ),
                    ],
                  ),
                ),
              ),
              if (current.exercises.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    compact: true,
                    icon: Icons.playlist_add_rounded,
                    title: 'No exercises on ${current.name}',
                    message: 'Add exercises, then drag to set their order.',
                    actionLabel: 'Add exercises',
                    onAction: _addExercises,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                  sliver: SliverReorderableList(
                    itemCount: current.exercises.length,
                    onReorderStart: (_) => Haptics.tap(),
                    onReorderItem: (a, b) => _ctrl.reorderExercise(day, a, b),
                    proxyDecorator: (child, _, anim) => AnimatedBuilder(
                      animation: anim,
                      builder: (_, child) => Transform.scale(scale: 1 + (AppMotion.dragLiftScale - 1) * anim.value, child: child),
                      child: Material(color: Colors.transparent, child: child),
                    ),
                    itemBuilder: (_, i) {
                      final e = current.exercises[i];
                      return Padding(
                        key: ValueKey('${current.name}-$i-${e.exercise.id}'),
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Dismissible(
                          key: ValueKey('dismiss-${current.name}-$i-${e.exercise.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: AppSpacing.xl),
                            decoration: BoxDecoration(color: c.danger.withValues(alpha: AppOpacity.subtle), borderRadius: AppRadii.lgAll),
                            child: Icon(Icons.delete_rounded, color: c.danger),
                          ),
                          onDismissed: (_) {
                            _ctrl.removeExercise(day, i);
                            showAppSnack(
                              context,
                              'Removed ${e.exercise.name}',
                              action: SnackBarAction(label: 'Undo', onPressed: () => _ctrl.insertExercise(day, i, e)),
                            );
                          },
                          child: _ExerciseRow(index: i, exercise: e, onTap: () => _editExercise(i, e)),
                        ),
                      );
                    },
                  ),
                ),
              if (current.exercises.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xl),
                  sliver: SliverToBoxAdapter(
                    child: GradientButton(
                      label: 'Add exercises',
                      icon: Icons.add_rounded,
                      variant: GradientButtonVariant.outlined,
                      onPressed: _addExercises,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.lg),
          child: GradientButton(
            label: 'Save program',
            icon: Icons.check_rounded,
            loading: _saving,
            onPressed: draft.canSave ? _save : null,
          ),
        ),
      ],
    );
  }
}

/// Horizontal, drag-reorderable strip of day chips plus an "add day" chip.
class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.draft, required this.selected, required this.onSelect, required this.ctrl});

  final ProgramDraft draft;
  final int selected;
  final ValueChanged<int> onSelect;
  final ProgramBuilderController ctrl;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: AppSizes.chipHeight + AppSpacing.sm,
      child: Row(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: AppSpacing.screen),
              itemCount: draft.days.length,
              onReorderStart: (_) => Haptics.tap(),
              onReorderItem: (a, b) {
                ctrl.reorderDays(a, b);
                // Keep the same day selected after it moves.
                if (a == selected) onSelect(b);
              },
              proxyDecorator: (child, _, _) => Material(color: Colors.transparent, child: child),
              itemBuilder: (_, i) {
                final d = draft.days[i];
                return Padding(
                  key: ValueKey('day-$i-${d.name}'),
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text('${d.name}${d.exercises.isEmpty ? '' : ' · ${d.exercises.length}'}'),
                    selected: i == selected,
                    onSelected: (_) => onSelect(i),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.screen),
            child: ActionChip(
              avatar: Icon(Icons.add_rounded, size: AppSizes.iconSm, color: c.accent),
              label: const Text('Day'),
              onPressed: draft.days.length < ProgramBuilderController.maxDays ? () => onSelect(ctrl.addDay()) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.index, required this.exercise, required this.onTap});

  final int index;
  final ProgramExercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassCard(
      blur: false,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      semanticLabel: '${exercise.exercise.name}, ${exercise.prescription}. Tap to edit.',
      child: Row(
        children: [
          ExerciseThumb(url: exercise.exercise.image, size: AppSizes.avatar),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.exercise.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                AnimatedSwitcher(
                  duration: AppMotion.fast,
                  child: Text(
                    '${exercise.prescription} · ${exercise.restSeconds}s rest',
                    key: ValueKey(exercise.prescription + exercise.restSeconds.toString()),
                    style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Semantics(
                label: 'Drag to reorder',
                child: Icon(Icons.drag_indicator_rounded, color: c.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
