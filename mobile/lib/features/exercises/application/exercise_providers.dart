import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/paginated.dart';
import '../../../core/theme/motion.dart';
import '../data/exercise.dart';
import '../../workout/application/workout_providers.dart';
import '../data/exercise_repository.dart';

/// State of the paginated, filterable exercise library.
class ExerciseLibraryState {
  const ExerciseLibraryState({
    this.filters = const ExerciseFilters(),
    this.items = const [],
    this.page = 0,
    this.total = 0,
    this.hasMore = true,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  final ExerciseFilters filters;
  final List<Exercise> items;
  final int page;
  final int total;
  final bool hasMore;
  final bool loading;
  final bool loadingMore;
  final Object? error;

  ExerciseLibraryState copyWith({
    ExerciseFilters? filters,
    List<Exercise>? items,
    int? page,
    int? total,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    Object? error,
    bool clearError = false,
  }) => ExerciseLibraryState(
    filters: filters ?? this.filters,
    items: items ?? this.items,
    page: page ?? this.page,
    total: total ?? this.total,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Drives search (debounced), filters and infinite scrolling. Stale responses
/// from superseded queries are ignored via a request counter.
class ExerciseLibraryController extends Notifier<ExerciseLibraryState> {
  Timer? _debounce;
  int _requestId = 0;

  ExerciseRepository get _repo => ref.read(exerciseRepositoryProvider);

  @override
  ExerciseLibraryState build() {
    ref.onDispose(() => _debounce?.cancel());
    Future.microtask(refresh);
    return const ExerciseLibraryState(loading: true);
  }

  Future<void> refresh() async {
    final id = ++_requestId;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await _repo.list(state.filters);
      if (id != _requestId) return;
      _apply(page, replace: true);
    } on Exception catch (e) {
      if (id != _requestId) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final id = _requestId;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _repo.list(state.filters, page: state.page + 1);
      if (id != _requestId) return;
      _apply(page, replace: false);
    } on Exception catch (e) {
      if (id != _requestId) return;
      state = state.copyWith(loadingMore: false, error: e);
    }
  }

  void _apply(Paginated<Exercise> page, {required bool replace}) {
    state = state.copyWith(
      items: replace ? page.items : [...state.items, ...page.items],
      page: page.page,
      total: page.total,
      hasMore: page.hasMore,
      loading: false,
      loadingMore: false,
      clearError: true,
    );
  }

  void search(String query) {
    state = state.copyWith(filters: state.filters.copyWith(query: query));
    _debounce?.cancel();
    _debounce = Timer(AppMotion.searchDebounce, refresh);
  }

  void setFilters(ExerciseFilters filters) {
    state = state.copyWith(filters: filters.copyWith(query: state.filters.query));
    refresh();
  }

  void toggleMuscle(String muscle) {
    final next = {...state.filters.muscles};
    next.contains(muscle) ? next.remove(muscle) : next.add(muscle);
    setFilters(state.filters.copyWith(muscles: next));
  }

  /// Puts a just-created custom exercise at the top without a refetch.
  void prepend(Exercise exercise) {
    state = state.copyWith(items: [exercise, ...state.items], total: state.total + 1);
  }

  void remove(String id) {
    state = state.copyWith(items: state.items.where((e) => e.id != id).toList(), total: state.total - 1);
  }
}

final exerciseLibraryProvider = NotifierProvider<ExerciseLibraryController, ExerciseLibraryState>(
  ExerciseLibraryController.new,
);

final exerciseFilterOptionsProvider = FutureProvider<ExerciseFilterOptions>(
  (ref) => ref.watch(exerciseRepositoryProvider).filterOptions(),
);

final exerciseDetailProvider = FutureProvider.autoDispose.family<Exercise, String>(
  (ref, id) => ref.watch(exerciseRepositoryProvider).get(id),
);

final exerciseRecordsProvider = FutureProvider.autoDispose.family<({ExerciseBests bests, List<RecordEvent> history}), String>(
  (ref, id) {
    ref.watch(workoutRevisionProvider);
    return ref.watch(exerciseRepositoryProvider).records(id);
  },
);

final exerciseHistoryProvider = FutureProvider.autoDispose.family<List<ExerciseHistoryPoint>, String>(
  (ref, id) {
    ref.watch(workoutRevisionProvider);
    return ref.watch(exerciseRepositoryProvider).history(id);
  },
);
