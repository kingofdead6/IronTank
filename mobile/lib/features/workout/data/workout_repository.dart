import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/paginated.dart';
import '../../../core/storage/local_store.dart';
import 'workout_history.dart';
import 'workout_models.dart';

/// Response of `POST /workouts`.
class SaveWorkoutResponse {
  const SaveWorkoutResponse({
    required this.sessionId,
    required this.durationSec,
    required this.volumeKg,
    required this.caloriesKcal,
    required this.newRecords,
    required this.rankChanges,
  });

  factory SaveWorkoutResponse.fromJson(Map<String, dynamic> j) {
    final session = j['session'] as Map<String, dynamic>;
    return SaveWorkoutResponse(
      sessionId: session['id'] as String,
      durationSec: (session['activeDurationSec'] as num?)?.toInt() ?? (session['durationSec'] as num?)?.toInt() ?? 0,
      volumeKg: (session['totalVolume'] as num?)?.toDouble() ?? 0,
      caloriesKcal: ((j['calories'] as Map<String, dynamic>?)?['kcal'] as num?)?.toInt() ?? 0,
      newRecords: (j['newPRs'] as List<dynamic>? ?? const []).map((e) => NewRecord.fromJson(e as Map<String, dynamic>)).toList(),
      rankChanges: (j['rankChanges'] as List<dynamic>? ?? const [])
          .map((e) => RankChange.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String sessionId;
  final int durationSec;
  final double volumeKg;
  final int caloriesKcal;
  final List<NewRecord> newRecords;
  final List<RankChange> rankChanges;
}

class WorkoutRepository {
  WorkoutRepository(this._api, this._store);

  final ApiClient _api;
  final LocalStore _store;

  // ---- Local persistence of the active workout ----------------------------

  ActiveWorkout? loadLocal() {
    final json = _store.readActiveWorkout();
    if (json == null) return null;
    try {
      return ActiveWorkout.fromJson(json);
    } on Object {
      // Corrupt snapshot (e.g. after a schema change): drop it rather than crash.
      return null;
    }
  }

  Future<void> saveLocal(ActiveWorkout w) => _store.writeActiveWorkout(w.toJson());
  Future<void> clearLocal() => _store.clearActiveWorkout();

  // ---- Server ---------------------------------------------------------------

  /// Best-effort upload of the in-progress copy (enables resume on another device).
  Future<void> pushDraft(ActiveWorkout w) => _api.put('/workouts/active', body: w.toDraftApi(DateTime.now()));

  Future<void> deleteDraft() => _api.delete('/workouts/active');

  /// Previous-session sets per exercise id (for ghost values).
  Future<Map<String, List<PreviousSet>>> previous(List<String> exerciseIds) async {
    if (exerciseIds.isEmpty) return const {};
    final res = await _api.get('/workouts/previous', query: {'exerciseIds': exerciseIds});
    final map = res['previous'] as Map<String, dynamic>;
    return {
      for (final entry in map.entries)
        entry.key: entry.value == null
            ? const <PreviousSet>[]
            : ((entry.value as Map<String, dynamic>)['sets'] as List<dynamic>)
                .map((s) => PreviousSet.fromJson(s as Map<String, dynamic>))
                .toList(),
    };
  }

  Future<SaveWorkoutResponse> save(Map<String, dynamic> body) async =>
      SaveWorkoutResponse.fromJson(await _api.post('/workouts', body: body));

  /// Saves, or queues the workout locally when offline. Returns null when queued.
  Future<SaveWorkoutResponse?> saveOrQueue(Map<String, dynamic> body) async {
    try {
      return await save(body);
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      await _store.addPendingWorkout(body['clientId'] as String, body);
      return null;
    }
  }

  /// Uploads queued workouts. Returns how many were synced.
  Future<int> syncPending() async {
    var synced = 0;
    for (final body in _store.pendingWorkouts()) {
      final clientId = body['clientId'] as String;
      try {
        await save(body);
        await _store.removePendingWorkout(clientId);
        synced++;
      } on ApiException catch (e) {
        if (e.isNetwork) break; // still offline; try again later
        // The server rejected it (e.g. an exercise was deleted): drop it so the queue can't jam.
        await _store.removePendingWorkout(clientId);
      }
    }
    return synced;
  }

  int get pendingCount => _store.pendingWorkouts().length;

  // ---- History --------------------------------------------------------------

  Future<Paginated<WorkoutSummary>> history({int page = 1, int limit = 20}) async =>
      Paginated.fromJson(await _api.get('/workouts', query: {'page': page, 'limit': limit}), WorkoutSummary.fromJson);

  Future<WorkoutSummary> get(String id) async =>
      WorkoutSummary.fromJson((await _api.get('/workouts/$id'))['session'] as Map<String, dynamic>);

  Future<void> delete(String id) => _api.delete('/workouts/$id');
}

final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => WorkoutRepository(ref.watch(apiClientProvider), ref.watch(localStoreProvider)),
);
