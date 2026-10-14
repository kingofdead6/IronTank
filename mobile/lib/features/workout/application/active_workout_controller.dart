import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/utils/haptics.dart';
import '../../auth/application/auth_controller.dart';
import '../../programs/application/program_providers.dart';
import '../../programs/data/program.dart';
import '../../profile/application/settings_controller.dart';
import '../data/workout_models.dart';
import '../data/workout_repository.dart';
import 'workout_providers.dart';

/// Owns the in-progress workout. Every change is written to local storage
/// immediately (so killing the app never loses a set) and pushed to the
/// server as a draft after a short debounce.
class ActiveWorkoutController extends Notifier<ActiveWorkout?> {
  Timer? _restTimer;
  Timer? _draftDebounce;

  static const _draftDelay = Duration(seconds: 4);
  static const _defaultSets = 3;
  static const _maxRestTakenSec = 7200;

  WorkoutRepository get _repo => ref.read(workoutRepositoryProvider);
  NotificationService get _notifications => ref.read(notificationServiceProvider);

  @override
  ActiveWorkout? build() {
    ref.onDispose(() {
      _restTimer?.cancel();
      _draftDebounce?.cancel();
    });
    final restored = _repo.loadLocal();
    if (restored?.rest case final rest?) {
      if (rest.endsAt.isAfter(DateTime.now())) {
        _armRestTimer(rest.endsAt);
      } else {
        return restored!.copyWith(clearRest: true);
      }
    }
    return restored;
  }

  bool get isActive => state != null;

  // ---- Persistence ----------------------------------------------------------

  void _commit(ActiveWorkout next) {
    state = next;
    unawaited(_repo.saveLocal(next));
    _draftDebounce?.cancel();
    _draftDebounce = Timer(_draftDelay, () async {
      final current = state;
      if (current == null) return;
      try {
        await _repo.pushDraft(current);
      } on Object {
        // Offline: the local copy is the source of truth until finish.
      }
    });
  }

  void _updateExercise(String exerciseId, WorkoutExercise Function(WorkoutExercise) change) {
    final w = state;
    if (w == null) return;
    _commit(w.copyWith(exercises: [for (final e in w.exercises) e.id == exerciseId ? change(e) : e]));
  }

  void _updateSet(String exerciseId, String setId, WorkoutSet Function(WorkoutSet) change) =>
      _updateExercise(exerciseId, (e) => e.copyWith(sets: [for (final s in e.sets) s.id == setId ? change(s) : s]));

  // ---- Lifecycle ------------------------------------------------------------

  /// Starts a workout, optionally from a program day.
  Future<void> start({String name = 'Workout', String? programId, ProgramDay? day}) async {
    if (state != null) return;
    final workout = ActiveWorkout(
      clientId: newLocalId(),
      name: day?.name ?? name,
      startedAt: DateTime.now(),
      programId: programId,
      dayId: day?.id,
      exercises: day == null ? const [] : exercisesFromDay(day),
    );
    _commit(workout);
    unawaited(_notifications.requestPermissions());
    await _loadPrevious(workout.exercises);
  }

  /// Fetches last-session values and pre-fills empty sets with them.
  Future<void> _loadPrevious(List<WorkoutExercise> exercises) async {
    if (exercises.isEmpty) return;
    try {
      final prev = await _repo.previous(exercises.map((e) => e.exercise.id).toSet().toList());
      if (!ref.mounted) return;
      final w = state;
      if (w == null) return;
      final ids = exercises.map((e) => e.id).toSet();
      _commit(
        w.copyWith(
          exercises: [
            for (final e in w.exercises)
              ids.contains(e.id) && (prev[e.exercise.id]?.isNotEmpty ?? false) ? e.copyWith(previous: prev[e.exercise.id]) : e,
          ],
        ),
      );
    } on Object {
      // Ghost values are a nicety; offline workouts simply go without them.
    }
  }

  /// Saves the workout. Returns the summary; queues it locally when offline.
  Future<WorkoutResult> finish() async {
    final w = state;
    if (w == null) throw StateError('No active workout');
    final now = DateTime.now();
    final body = w.toFinishApi(now);
    final response = await _repo.saveOrQueue(body);
    if (!ref.mounted) throw StateError('Workout controller disposed while saving');

    await _close();
    // Refresh everything that depends on workout history.
    ref.invalidate(activeProgramProvider);
    ref.read(workoutRevisionProvider.notifier).bump();
    if (response != null) unawaited(ref.read(authControllerProvider.notifier).refreshUser());

    final completed = w.exercises.where((e) => e.completedSets > 0);
    return WorkoutResult(
      name: w.name,
      duration: response == null ? w.activeDuration(now) : Duration(seconds: response.durationSec),
      volumeKg: response?.volumeKg ?? w.volumeKg,
      completedSets: w.completedSets,
      exerciseCount: completed.length,
      caloriesKcal: response?.caloriesKcal,
      sessionId: response?.sessionId,
      newRecords: response?.newRecords ?? const [],
      rankChanges: response?.rankChanges ?? const [],
      synced: response != null,
    );
  }

  Future<void> discard() async {
    await _close();
    try {
      await _repo.deleteDraft();
    } on Object {
      // Offline: the server draft is replaced by the next workout anyway.
    }
  }

  Future<void> _close() async {
    _restTimer?.cancel();
    _draftDebounce?.cancel();
    await _notifications.cancelRestEnd();
    await _repo.clearLocal();
    state = null;
  }

  // ---- Workout-level edits --------------------------------------------------

  void rename(String name) {
    if (state != null && name.trim().isNotEmpty) _commit(state!.copyWith(name: name.trim()));
  }

  void setNotes(String notes) {
    if (state != null) _commit(state!.copyWith(notes: notes));
  }

  void togglePause() {
    final w = state;
    if (w == null) return;
    if (w.isPaused) {
      final paused = DateTime.now().difference(w.pausedAt!).inSeconds;
      _commit(w.copyWith(clearPause: true, pausedSeconds: w.pausedSeconds + paused));
    } else {
      _commit(w.copyWith(pausedAt: DateTime.now()));
    }
  }

  // ---- Exercises ------------------------------------------------------------

  int get _defaultRest => ref.read(currentUserProvider)?.restTimerDefaultSec ?? 90;

  Future<void> addExercises(List<ExerciseSummary> exercises) async {
    final w = state;
    if (w == null || exercises.isEmpty) return;
    final added = [
      for (final ex in exercises)
        WorkoutExercise(
          id: newLocalId(),
          exercise: ex,
          restSeconds: _defaultRest,
          sets: [for (var i = 0; i < _defaultSets; i++) WorkoutSet(id: newLocalId())],
        ),
    ];
    _commit(w.copyWith(exercises: [...w.exercises, ...added]));
    await _loadPrevious(added);
  }

  /// Replaces an exercise, keeping the number of sets but clearing their values.
  Future<void> swapExercise(String exerciseId, ExerciseSummary replacement) async {
    final w = state;
    if (w == null) return;
    late WorkoutExercise swapped;
    _updateExercise(exerciseId, (e) {
      swapped = e.copyWith(
        exercise: replacement,
        previous: const [],
        clearTarget: false,
        sets: [for (final s in e.sets) WorkoutSet(id: s.id, type: s.type)],
      );
      return swapped;
    });
    await _loadPrevious([swapped]);
  }

  void removeExercise(String exerciseId) {
    final w = state;
    if (w == null) return;
    _commit(w.copyWith(exercises: w.exercises.where((e) => e.id != exerciseId).toList(), clearRest: w.rest?.exerciseId == exerciseId));
  }

  void insertExercise(int index, WorkoutExercise exercise) {
    final w = state;
    if (w == null) return;
    _commit(w.copyWith(exercises: [...w.exercises]..insert(index.clamp(0, w.exercises.length), exercise)));
  }

  /// [newIndex] is the final position (as reported by onReorderItem).
  void moveExercise(int oldIndex, int newIndex) {
    final w = state;
    if (w == null) return;
    final list = [...w.exercises];
    list.insert(newIndex, list.removeAt(oldIndex));
    _commit(w.copyWith(exercises: list));
  }

  void setExerciseRest(String exerciseId, int seconds) => _updateExercise(exerciseId, (e) => e.copyWith(restSeconds: seconds));

  void setExerciseNotes(String exerciseId, String notes) => _updateExercise(exerciseId, (e) => e.copyWith(notes: notes));

  // ---- Sets -----------------------------------------------------------------

  /// Adds a set pre-filled with the last set's values.
  void addSet(String exerciseId) => _updateExercise(exerciseId, (e) {
    final next = e.sets.isEmpty ? WorkoutSet(id: newLocalId()) : e.sets.last.duplicate().copyWith(type: SetType.working);
    return e.copyWith(sets: [...e.sets, next]);
  });

  void removeSet(String exerciseId, String setId) =>
      _updateExercise(exerciseId, (e) => e.copyWith(sets: e.sets.where((s) => s.id != setId).toList()));

  void setWeight(String exerciseId, String setId, double? kg) =>
      _updateSet(exerciseId, setId, (s) => kg == null ? s.copyWith(clearWeight: true) : s.copyWith(weightKg: kg));

  void setReps(String exerciseId, String setId, int? reps) =>
      _updateSet(exerciseId, setId, (s) => reps == null ? s.copyWith(clearReps: true) : s.copyWith(reps: reps));

  void setRpe(String exerciseId, String setId, double? rpe) =>
      _updateSet(exerciseId, setId, (s) => rpe == null ? s.copyWith(clearRpe: true) : s.copyWith(rpe: rpe));

  void cycleSetType(String exerciseId, String setId) => _updateSet(exerciseId, setId, (s) => s.copyWith(type: s.type.next));

  /// Ticks a set off (or un-ticks it). Empty fields are filled from the
  /// previous session's ghost values. Returns false when there's nothing to log.
  bool toggleSet(String exerciseId, String setId) {
    final w = state;
    if (w == null) return false;
    final exercise = w.exercises.firstWhere((e) => e.id == exerciseId);
    final index = exercise.sets.indexWhere((s) => s.id == setId);
    final set = exercise.sets[index];

    if (set.completed) {
      _updateSet(exerciseId, setId, (s) => s.copyWith(completed: false, clearCompletedAt: true));
      return true;
    }

    final ghost = exercise.previousFor(index);
    final reps = set.reps ?? ghost?.reps;
    final weight = set.weightKg ?? ghost?.weightKg ?? (exercise.exercise.isBodyweight ? 0 : null);
    if (reps == null || reps <= 0) return false;

    final now = DateTime.now();
    final withRest = _recordRestTaken(w, now);
    _commit(withRest.copyWith(
      exercises: [
        for (final e in withRest.exercises)
          e.id == exerciseId
              ? e.copyWith(sets: [
                  for (final s in e.sets)
                    s.id == setId ? s.copyWith(completed: true, completedAt: now, reps: reps, weightKg: weight) : s,
                ])
              : e,
      ],
    ));
    unawaited(Haptics.setComplete());

    // Warm-ups get a short rest; no rest after the very last set of the workout.
    final allDone = state!.completedSets == state!.totalSets;
    if (!allDone) startRest(set.type == SetType.warmup ? (exercise.restSeconds ~/ 2) : exercise.restSeconds, exerciseId);
    return true;
  }

  /// Stores the time since the previous completed set as that set's rest.
  ActiveWorkout _recordRestTaken(ActiveWorkout w, DateTime now) {
    String? lastExercise;
    String? lastSet;
    DateTime? lastAt;
    for (final e in w.exercises) {
      for (final s in e.sets) {
        if (s.completed && s.completedAt != null && s.restTaken == null && (lastAt == null || s.completedAt!.isAfter(lastAt))) {
          lastAt = s.completedAt;
          lastExercise = e.id;
          lastSet = s.id;
        }
      }
    }
    if (lastAt == null) return w;
    final rest = now.difference(lastAt).inSeconds.clamp(0, _maxRestTakenSec);
    return w.copyWith(
      exercises: [
        for (final e in w.exercises)
          e.id == lastExercise
              ? e.copyWith(sets: [for (final s in e.sets) s.id == lastSet ? s.copyWith(restTaken: rest) : s])
              : e,
      ],
    );
  }

  // ---- Rest timer -----------------------------------------------------------

  void startRest(int seconds, String exerciseId) {
    final w = state;
    if (w == null || seconds <= 0) return;
    final endsAt = DateTime.now().add(Duration(seconds: seconds));
    _commit(w.copyWith(rest: RestTimer(endsAt: endsAt, totalSeconds: seconds, exerciseId: exerciseId)));
    _armRestTimer(endsAt);
    _scheduleAlarm(endsAt, exerciseId);
  }

  /// Adds or removes time (±15 s buttons). Never goes below zero.
  void adjustRest(int deltaSeconds) {
    final w = state;
    final rest = w?.rest;
    if (w == null || rest == null) return;
    final endsAt = rest.endsAt.add(Duration(seconds: deltaSeconds));
    if (!endsAt.isAfter(DateTime.now())) {
      skipRest();
      return;
    }
    final total = (rest.totalSeconds + deltaSeconds).clamp(1, 3600);
    _commit(w.copyWith(rest: RestTimer(endsAt: endsAt, totalSeconds: total, exerciseId: rest.exerciseId)));
    _armRestTimer(endsAt);
    _scheduleAlarm(endsAt, rest.exerciseId);
  }

  void skipRest() {
    _restTimer?.cancel();
    unawaited(_notifications.cancelRestEnd());
    if (state?.rest != null) _commit(state!.copyWith(clearRest: true));
  }

  void _armRestTimer(DateTime endsAt) {
    _restTimer?.cancel();
    _restTimer = Timer(endsAt.difference(DateTime.now()), _onRestFinished);
  }

  void _scheduleAlarm(DateTime endsAt, String exerciseId) {
    final w = state;
    final exercise = w?.exercises.where((e) => e.id == exerciseId).firstOrNull;
    final next = exercise == null ? 'Next set' : 'Next: ${exercise.exercise.name}';
    unawaited(_notifications.scheduleRestEnd(endsAt, nextLabel: next, sound: ref.read(settingsProvider).timerSoundEnabled));
  }

  void _onRestFinished() {
    if (state?.rest == null) return;
    unawaited(Haptics.timerDone());
    if (ref.read(settingsProvider).timerSoundEnabled) unawaited(SystemSound.play(SystemSoundType.alert));
    _commit(state!.copyWith(clearRest: true));
  }

  /// Uploads workouts saved while offline.
  Future<int> syncPending() async {
    final synced = await _repo.syncPending();
    if (synced > 0 && ref.mounted) {
      ref.invalidate(activeProgramProvider);
      ref.read(workoutRevisionProvider.notifier).bump();
    }
    return synced;
  }
}

final activeWorkoutProvider = NotifierProvider<ActiveWorkoutController, ActiveWorkout?>(ActiveWorkoutController.new);
