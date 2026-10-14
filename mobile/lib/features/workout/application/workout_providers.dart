import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/workout_history.dart';
import '../data/workout_repository.dart';

/// Bumped whenever workout history changes (finish, offline sync, delete).
/// Providers derived from history (stats, PRs, ranks, calories burned) watch
/// it, so they refetch automatically.
class WorkoutRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final workoutRevisionProvider = NotifierProvider<WorkoutRevision, int>(WorkoutRevision.new);

/// Most recent workouts (first page) for the Workout tab.
final recentWorkoutsProvider = FutureProvider.autoDispose<List<WorkoutSummary>>((ref) async {
  ref.watch(workoutRevisionProvider);
  return (await ref.watch(workoutRepositoryProvider).history(limit: 10)).items;
});

final workoutDetailProvider = FutureProvider.autoDispose.family<WorkoutSummary, String>((ref, id) {
  ref.watch(workoutRevisionProvider);
  return ref.watch(workoutRepositoryProvider).get(id);
});
