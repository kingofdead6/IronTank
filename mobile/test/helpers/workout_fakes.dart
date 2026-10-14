import 'package:ironrank/core/network/api_exception.dart';
import 'package:ironrank/core/network/paginated.dart';
import 'package:ironrank/core/notifications/notification_service.dart';
import 'package:ironrank/core/storage/local_store.dart';
import 'package:ironrank/features/workout/data/workout_history.dart';
import 'package:ironrank/features/workout/data/workout_models.dart';
import 'package:ironrank/features/workout/data/workout_repository.dart';

import 'fakes.dart';

/// Records alarms instead of talking to the platform.
class FakeNotifications extends NotificationService {
  DateTime? scheduledAt;
  int cancels = 0;

  @override
  Future<void> init() async {}

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> scheduleRestEnd(DateTime at, {required String nextLabel, required bool sound}) async => scheduledAt = at;

  @override
  Future<void> cancelRestEnd() async {
    cancels++;
    scheduledAt = null;
  }
}

/// In-memory workout backend with switchable offline mode.
class FakeWorkoutRepository extends WorkoutRepository {
  FakeWorkoutRepository(LocalStore store) : super(unusedApi, store);

  bool offline = false;
  final saved = <Map<String, dynamic>>[];
  Map<String, List<PreviousSet>> previousValues = {};
  List<NewRecord> recordsToReturn = const [];

  /// Kept in memory: real Hive file I/O never completes inside widget tests'
  /// fake-async zone and would block later tests.
  ActiveWorkout? local;

  @override
  ActiveWorkout? loadLocal() => local;

  @override
  Future<void> saveLocal(ActiveWorkout w) async => local = w;

  @override
  Future<void> clearLocal() async => local = null;

  @override
  Future<void> pushDraft(ActiveWorkout w) async {}

  @override
  Future<void> deleteDraft() async {}

  @override
  Future<Map<String, List<PreviousSet>>> previous(List<String> exerciseIds) async {
    if (offline) throw const ApiException(code: ApiException.networkCode, message: 'offline');
    return {for (final id in exerciseIds) id: previousValues[id] ?? const []};
  }

  @override
  Future<SaveWorkoutResponse> save(Map<String, dynamic> body) async {
    if (offline) throw const ApiException(code: ApiException.networkCode, message: 'offline');
    saved.add(body);
    return SaveWorkoutResponse(
      sessionId: 'session-${saved.length}',
      durationSec: (body['activeDurationSec'] as int?) ?? 0,
      volumeKg: 1234,
      caloriesKcal: 321,
      newRecords: recordsToReturn,
      rankChanges: const [],
    );
  }

  @override
  Future<Paginated<WorkoutSummary>> history({int page = 1, int limit = 20}) async =>
      Paginated(items: const [], page: 1, limit: limit, total: 0, totalPages: 1);
}
