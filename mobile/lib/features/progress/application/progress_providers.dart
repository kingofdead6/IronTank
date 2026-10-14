import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/time_zone.dart';
import '../../exercises/data/exercise.dart';
import '../../workout/application/workout_providers.dart';
import '../data/progress_models.dart';
import '../data/progress_repository.dart';

/// Every provider here watches [workoutRevisionProvider], so finishing,
/// syncing or deleting a workout refreshes them automatically.

final statsOverviewProvider = FutureProvider.autoDispose.family<StatsOverview, int>((ref, weeks) async {
  ref.watch(workoutRevisionProvider);
  final tz = await ref.watch(timeZoneProvider.future);
  return ref.watch(progressRepositoryProvider).overview(weeks: weeks, tz: tz);
});

final ranksProvider = FutureProvider.autoDispose<Ranks>((ref) {
  ref.watch(workoutRevisionProvider);
  return ref.watch(progressRepositoryProvider).ranks();
});

final latestRecordsProvider = FutureProvider.autoDispose<List<RecordEvent>>((ref) {
  ref.watch(workoutRevisionProvider);
  return ref.watch(progressRepositoryProvider).latestRecords();
});

/// Bumped when a bodyweight entry is added/removed.
class BodyweightRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final bodyweightRevisionProvider = NotifierProvider<BodyweightRevision, int>(BodyweightRevision.new);

final bodyweightHistoryProvider = FutureProvider.autoDispose<List<BodyweightEntry>>((ref) {
  ref.watch(bodyweightRevisionProvider);
  return ref.watch(progressRepositoryProvider).bodyweight();
});
