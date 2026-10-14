import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/paginated.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/motion.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/staggered.dart';
import '../data/exercise.dart';
import '../data/exercise_repository.dart';
import 'widgets/exercise_card.dart';

/// Searchable exercise picker. With [multiple], returns a list in tap order;
/// otherwise returns a single-item list as soon as one is tapped.
Future<List<Exercise>?> showExercisePicker(BuildContext context, {bool multiple = true, String title = 'Add exercises'}) {
  return showModalBottomSheet<List<Exercise>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PickerSheet(multiple: multiple, title: title),
  );
}

class _PickerSheet extends ConsumerStatefulWidget {
  const _PickerSheet({required this.multiple, required this.title});

  final bool multiple;
  final String title;

  @override
  ConsumerState<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends ConsumerState<_PickerSheet> {
  final _selected = <Exercise>[];
  Timer? _debounce;
  String _query = '';
  late Future<Paginated<Exercise>> _results = _load();

  Future<Paginated<Exercise>> _load() =>
      ref.read(exerciseRepositoryProvider).list(ExerciseFilters(query: _query), limit: 50);

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(AppMotion.searchDebounce, () {
      if (!mounted) return;
      setState(() {
        _query = q;
        _results = _load();
      });
    });
  }

  void _tap(Exercise e) {
    if (!widget.multiple) {
      Navigator.pop(context, [e]);
      return;
    }
    setState(() {
      final i = _selected.indexWhere((s) => s.id == e.id);
      i >= 0 ? _selected.removeAt(i) : _selected.add(e);
    });
  }

  Future<void> _createCustom() async {
    final created = await context.push<Exercise>(Routes.exerciseNew);
    if (created != null && mounted) _tap(created);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: AppSpacing.screenPadding,
            child: Row(
              children: [
                Expanded(child: Text(widget.title, style: context.text.headlineSmall)),
                TextButton.icon(onPressed: _createCustom, icon: const Icon(Icons.add_rounded), label: const Text('Custom')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.md),
            child: TextField(
              autofocus: false,
              onChanged: _onSearch,
              decoration: const InputDecoration(hintText: 'Search exercises', prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
          Expanded(
            child: FutureBuilder<Paginated<Exercise>>(
              future: _results,
              builder: (context, snap) {
                if (snap.hasError) {
                  return ErrorState(error: snap.error!, compact: true, onRetry: () => setState(() => _results = _load()));
                }
                if (!snap.hasData) return const SkeletonList(count: 6);
                final items = snap.data!.items;
                if (items.isEmpty) {
                  return EmptyState(
                    compact: true,
                    icon: Icons.search_off_rounded,
                    title: 'Nothing matches "$_query"',
                    actionLabel: 'Create custom exercise',
                    onAction: _createCustom,
                  );
                }
                return ListView.separated(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.xl),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final e = items[i];
                    final order = _selected.indexWhere((s) => s.id == e.id);
                    return ExerciseListTile(
                      exercise: e,
                      selected: order >= 0,
                      onTap: () => _tap(e),
                      trailing: widget.multiple
                          ? AnimatedSwitcher(
                              duration: AppMotion.fast,
                              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                              child: order >= 0
                                  ? CircleAvatar(
                                      key: ValueKey(order),
                                      radius: AppSizes.iconMd / 2 + AppSpacing.xxs,
                                      backgroundColor: c.accent,
                                      child: Text('${order + 1}', style: context.text.labelMedium?.copyWith(color: c.onAccent)),
                                    )
                                  : Icon(Icons.add_circle_outline_rounded, key: const ValueKey('add'), color: c.textMuted),
                            )
                          : Icon(Icons.chevron_right_rounded, color: c.textMuted),
                    ).staggered(i);
                  },
                );
              },
            ),
          ),
          if (widget.multiple)
            AnimatedSize(
              duration: AppMotion.medium,
              curve: AppMotion.standard,
              child: _selected.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.lg),
                      child: GradientButton(
                        label: 'Add ${_selected.length} exercise${_selected.length == 1 ? '' : 's'}',
                        icon: Icons.check_rounded,
                        onPressed: () => Navigator.pop(context, List<Exercise>.of(_selected)),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
