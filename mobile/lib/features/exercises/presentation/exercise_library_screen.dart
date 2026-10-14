import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/motion.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/staggered.dart';
import '../application/exercise_providers.dart';
import '../data/exercise.dart';
import '../data/exercise_repository.dart';
import 'widgets/exercise_card.dart';
import 'widgets/filter_sheet.dart';

/// Quick muscle chips shown above the grid (the full list is in the filter sheet).
const _quickMuscles = ['chest', 'lats', 'shoulders', 'biceps', 'triceps', 'quadriceps', 'hamstrings', 'glutes', 'abdominals', 'calves'];

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  final _scroll = ScrollController();
  late final _search = TextEditingController(text: ref.read(exerciseLibraryProvider).filters.query);

  /// Start loading the next page this far before the end.
  static const _prefetchExtent = 600.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < _prefetchExtent) ref.read(exerciseLibraryProvider.notifier).loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final controller = ref.read(exerciseLibraryProvider.notifier);
    final next = await showExerciseFilterSheet(context, ref.read(exerciseLibraryProvider).filters);
    if (next != null) controller.setFilters(next);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exerciseLibraryProvider);
    final controller = ref.read(exerciseLibraryProvider.notifier);
    final c = context.colors;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            color: c.accent,
            child: CustomScrollView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xl, AppSpacing.sm, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Exercises', style: context.text.displaySmall),
                              AnimatedSwitcher(
                                duration: AppMotion.fast,
                                child: Text(
                                  state.loading ? 'Loading…' : '${state.total} exercises',
                                  key: ValueKey(state.loading ? -1 : state.total),
                                  style: context.text.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Create custom exercise',
                          onPressed: () => context.push(Routes.exerciseNew),
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ).entrance(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            onChanged: controller.search,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search 870+ exercises',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: state.filters.query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () {
                                        _search.clear();
                                        controller.search('');
                                      },
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Badge(
                          isLabelVisible: state.filters.activeCount > 0,
                          label: Text('${state.filters.activeCount}'),
                          backgroundColor: c.accentEnd,
                          child: IconButton.filledTonal(
                            tooltip: 'Filters',
                            onPressed: _openFilters,
                            icon: const Icon(Icons.tune_rounded),
                          ),
                        ),
                      ],
                    ).entrance(delay: AppMotion.stagger),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: AppSizes.chipHeight + AppSpacing.xl,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, 0),
                      itemCount: _quickMuscles.length,
                      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (_, i) {
                        final m = _quickMuscles[i];
                        return FilterChip(
                          label: Text(labelize(m)),
                          selected: state.filters.muscles.contains(m),
                          onSelected: (_) => controller.toggleMuscle(m),
                        ).staggered(i, horizontal: true);
                      },
                    ),
                  ),
                ),
                ..._content(state, controller),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.bottomNavClearance)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(ExerciseLibraryState state, ExerciseLibraryController controller) {
    const gridPadding = EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, 0);
    const delegate = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: AppSizes.rankBadgeLg * 1.4,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 0.78,
    );

    if (state.loading && state.items.isEmpty) {
      return [
        SliverPadding(
          padding: gridPadding,
          sliver: SliverGrid.builder(
            gridDelegate: delegate,
            itemCount: 6,
            itemBuilder: (_, _) => const Shimmer(child: SkeletonBox(height: double.infinity, radius: AppRadii.lgAll)),
          ),
        ),
      ];
    }
    if (state.error != null && state.items.isEmpty) {
      return [SliverFillRemaining(hasScrollBody: false, child: ErrorState(error: state.error!, onRetry: controller.refresh))];
    }
    if (state.items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No exercises found',
            message: 'Try a different search or clear some filters.',
            actionLabel: 'Create custom exercise',
            onAction: () => context.push(Routes.exerciseNew),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: gridPadding,
        sliver: SliverGrid.builder(
          gridDelegate: delegate,
          itemCount: state.items.length,
          itemBuilder: (_, i) {
            final ex = state.items[i];
            return ExerciseCard(
              key: ValueKey(ex.id),
              exercise: ex,
              onTap: () => context.push(Routes.exercise(ex.id), extra: ex),
            ).staggered(i % ExerciseRepository.pageSize);
          },
        ),
      ),
      if (state.loadingMore)
        const SliverPadding(
          padding: EdgeInsets.only(top: AppSpacing.lg),
          sliver: SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
        ),
    ];
  }
}

