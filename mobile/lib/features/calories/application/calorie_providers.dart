import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_zone.dart';
import '../../workout/application/workout_providers.dart';
import '../data/calorie_models.dart';
import '../data/calorie_repository.dart';

/// Bumped after food entries or the target change.
class CalorieRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final calorieRevisionProvider = NotifierProvider<CalorieRevision, int>(CalorieRevision.new);

/// One local day (YYYY-MM-DD). Also refreshes after workouts (calories burned).
final calorieDayProvider = FutureProvider.autoDispose.family<CalorieDay, String>((ref, date) async {
  ref
    ..watch(calorieRevisionProvider)
    ..watch(workoutRevisionProvider);
  final tz = await ref.watch(timeZoneProvider.future);
  return ref.watch(calorieRepositoryProvider).day(date, tz);
});

final calorieTargetProvider = FutureProvider.autoDispose<CalorieTarget>((ref) {
  ref.watch(calorieRevisionProvider);
  return ref.watch(calorieRepositoryProvider).target();
});

/// Today's local date as the API expects it.
String todayKey() => Fmt.isoDay(DateTime.now());
