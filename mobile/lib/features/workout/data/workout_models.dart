import 'package:uuid/uuid.dart';

import '../../programs/data/program.dart';

const _uuid = Uuid();
String newLocalId() => _uuid.v4();

enum SetType {
  warmup('W'),
  working(''),
  dropset('D'),
  failure('F');

  const SetType(this.short);

  /// Badge letter ("" for a normal working set, which shows its number).
  final String short;

  static SetType fromApi(String? v) => values.firstWhere((t) => t.name == v, orElse: () => working);

  /// Next type when the set badge is tapped.
  SetType get next => values[(index + 1) % values.length];

  String get label => switch (this) {
    warmup => 'Warm-up',
    working => 'Working',
    dropset => 'Drop set',
    failure => 'To failure',
  };
}

/// One set in the active workout. Weight is always kg (null = not entered).
class WorkoutSet {
  const WorkoutSet({
    required this.id,
    this.weightKg,
    this.reps,
    this.rpe,
    this.type = SetType.working,
    this.completed = false,
    this.restTaken,
    this.completedAt,
  });

  factory WorkoutSet.fromJson(Map<String, dynamic> j) => WorkoutSet(
    id: j['id'] as String? ?? newLocalId(),
    weightKg: (j['weight'] as num?)?.toDouble(),
    reps: (j['reps'] as num?)?.toInt(),
    rpe: (j['rpe'] as num?)?.toDouble(),
    type: SetType.fromApi(j['type'] as String?),
    completed: j['completed'] as bool? ?? false,
    restTaken: (j['restTaken'] as num?)?.toInt(),
    completedAt: j['completedAt'] == null ? null : DateTime.parse(j['completedAt'] as String),
  );

  final String id;
  final double? weightKg;
  final int? reps;
  final double? rpe;
  final SetType type;
  final bool completed;
  final int? restTaken;
  final DateTime? completedAt;

  WorkoutSet copyWith({
    double? weightKg,
    bool clearWeight = false,
    int? reps,
    bool clearReps = false,
    double? rpe,
    bool clearRpe = false,
    SetType? type,
    bool? completed,
    int? restTaken,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) => WorkoutSet(
    id: id,
    weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
    reps: clearReps ? null : (reps ?? this.reps),
    rpe: clearRpe ? null : (rpe ?? this.rpe),
    type: type ?? this.type,
    completed: completed ?? this.completed,
    restTaken: restTaken ?? this.restTaken,
    completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
  );

  /// A fresh, incomplete set pre-filled with this set's values.
  WorkoutSet duplicate() => WorkoutSet(id: newLocalId(), weightKg: weightKg, reps: reps, rpe: rpe, type: type);

  Map<String, dynamic> toJson() => {
    'id': id,
    'weight': weightKg,
    'reps': reps,
    'rpe': rpe,
    'type': type.name,
    'completed': completed,
    'restTaken': restTaken,
    'completedAt': completedAt?.toIso8601String(),
  };

  /// API body; blank fields become 0 (the server derives nothing from them unless completed).
  Map<String, dynamic> toApi() => {
    'weight': double.parse((weightKg ?? 0).toStringAsFixed(2)),
    'reps': reps ?? 0,
    'rpe': rpe,
    'type': type.name,
    'completed': completed,
    'restTaken': restTaken,
    'completedAt': completedAt?.toUtc().toIso8601String(),
  };
}

/// What the user did last time, shown as ghost text.
class PreviousSet {
  const PreviousSet({required this.weightKg, required this.reps});

  factory PreviousSet.fromJson(Map<String, dynamic> j) =>
      PreviousSet(weightKg: (j['weight'] as num?)?.toDouble() ?? 0, reps: (j['reps'] as num?)?.toInt() ?? 0);

  final double weightKg;
  final int reps;

  Map<String, dynamic> toJson() => {'weight': weightKg, 'reps': reps};
}

class WorkoutExercise {
  const WorkoutExercise({
    required this.id,
    required this.exercise,
    this.sets = const [],
    this.restSeconds = 90,
    this.notes = '',
    this.targetReps,
    this.previous = const [],
  });

  factory WorkoutExercise.fromJson(Map<String, dynamic> j) => WorkoutExercise(
    id: j['id'] as String? ?? newLocalId(),
    exercise: ExerciseSummary.fromJson(j['exercise'] as Map<String, dynamic>),
    sets: (j['sets'] as List<dynamic>? ?? const []).map((s) => WorkoutSet.fromJson(s as Map<String, dynamic>)).toList(),
    restSeconds: (j['restSeconds'] as num?)?.toInt() ?? 90,
    notes: j['notes'] as String? ?? '',
    targetReps: j['targetReps'] as String?,
    previous: (j['previous'] as List<dynamic>? ?? const []).map((s) => PreviousSet.fromJson(s as Map<String, dynamic>)).toList(),
  );

  final String id;
  final ExerciseSummary exercise;
  final List<WorkoutSet> sets;
  final int restSeconds;
  final String notes;

  /// Rep prescription from the program ("5", "8–12"), shown as a hint.
  final String? targetReps;
  final List<PreviousSet> previous;

  int get completedSets => sets.where((s) => s.completed).length;

  PreviousSet? previousFor(int setIndex) => setIndex < previous.length ? previous[setIndex] : null;

  WorkoutExercise copyWith({
    ExerciseSummary? exercise,
    List<WorkoutSet>? sets,
    int? restSeconds,
    String? notes,
    List<PreviousSet>? previous,
    String? targetReps,
    bool clearTarget = false,
  }) => WorkoutExercise(
    id: id,
    exercise: exercise ?? this.exercise,
    sets: sets ?? this.sets,
    restSeconds: restSeconds ?? this.restSeconds,
    notes: notes ?? this.notes,
    targetReps: clearTarget ? null : (targetReps ?? this.targetReps),
    previous: previous ?? this.previous,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'exercise': exercise.toJson(),
    'sets': sets.map((s) => s.toJson()).toList(),
    'restSeconds': restSeconds,
    'notes': notes,
    'targetReps': targetReps,
    'previous': previous.map((p) => p.toJson()).toList(),
  };

  Map<String, dynamic> toApi() => {
    'exerciseId': exercise.id,
    'restSeconds': restSeconds,
    'notes': notes,
    'sets': sets.map((s) => s.toApi()).toList(),
  };
}

/// A running rest countdown.
class RestTimer {
  const RestTimer({required this.endsAt, required this.totalSeconds, required this.exerciseId});

  factory RestTimer.fromJson(Map<String, dynamic> j) => RestTimer(
    endsAt: DateTime.parse(j['endsAt'] as String),
    totalSeconds: (j['totalSeconds'] as num).toInt(),
    exerciseId: j['exerciseId'] as String,
  );

  final DateTime endsAt;
  final int totalSeconds;

  /// Local id of the exercise whose set started the rest.
  final String exerciseId;

  Duration remaining(DateTime now) {
    final r = endsAt.difference(now);
    return r.isNegative ? Duration.zero : r;
  }

  double progress(DateTime now) =>
      totalSeconds == 0 ? 0 : (remaining(now).inMilliseconds / (totalSeconds * 1000)).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {'endsAt': endsAt.toIso8601String(), 'totalSeconds': totalSeconds, 'exerciseId': exerciseId};
}

/// The in-progress session. Persisted locally after every change.
class ActiveWorkout {
  const ActiveWorkout({
    required this.clientId,
    required this.name,
    required this.startedAt,
    this.programId,
    this.dayId,
    this.exercises = const [],
    this.notes = '',
    this.pausedAt,
    this.pausedSeconds = 0,
    this.rest,
  });

  factory ActiveWorkout.fromJson(Map<String, dynamic> j) => ActiveWorkout(
    clientId: j['clientId'] as String,
    name: j['name'] as String? ?? 'Workout',
    startedAt: DateTime.parse(j['startedAt'] as String),
    programId: j['programId'] as String?,
    dayId: j['dayId'] as String?,
    exercises: (j['exercises'] as List<dynamic>? ?? const [])
        .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
        .toList(),
    notes: j['notes'] as String? ?? '',
    pausedAt: j['pausedAt'] == null ? null : DateTime.parse(j['pausedAt'] as String),
    pausedSeconds: (j['pausedSeconds'] as num?)?.toInt() ?? 0,
    rest: j['rest'] == null ? null : RestTimer.fromJson(j['rest'] as Map<String, dynamic>),
  );

  final String clientId;
  final String name;
  final DateTime startedAt;
  final String? programId;
  final String? dayId;
  final List<WorkoutExercise> exercises;
  final String notes;

  /// Non-null while the session timer is paused.
  final DateTime? pausedAt;

  /// Total paused time before the current pause.
  final int pausedSeconds;
  final RestTimer? rest;

  bool get isPaused => pausedAt != null;

  /// Session time excluding pauses.
  Duration activeDuration(DateTime now) {
    final end = pausedAt ?? now;
    final total = end.difference(startedAt) - Duration(seconds: pausedSeconds);
    return total.isNegative ? Duration.zero : total;
  }

  int get totalSets => exercises.fold(0, (s, e) => s + e.sets.length);
  int get completedSets => exercises.fold(0, (s, e) => s + e.completedSets);

  /// Volume of completed, non-warm-up sets (kg) — mirrors the server's formula.
  double get volumeKg {
    var v = 0.0;
    for (final e in exercises) {
      for (final s in e.sets) {
        if (s.completed && s.type != SetType.warmup && (s.weightKg ?? 0) > 0) v += s.weightKg! * (s.reps ?? 0);
      }
    }
    return v;
  }

  ActiveWorkout copyWith({
    String? name,
    List<WorkoutExercise>? exercises,
    String? notes,
    DateTime? pausedAt,
    bool clearPause = false,
    int? pausedSeconds,
    RestTimer? rest,
    bool clearRest = false,
  }) => ActiveWorkout(
    clientId: clientId,
    name: name ?? this.name,
    startedAt: startedAt,
    programId: programId,
    dayId: dayId,
    exercises: exercises ?? this.exercises,
    notes: notes ?? this.notes,
    pausedAt: clearPause ? null : (pausedAt ?? this.pausedAt),
    pausedSeconds: pausedSeconds ?? this.pausedSeconds,
    rest: clearRest ? null : (rest ?? this.rest),
  );

  Map<String, dynamic> toJson() => {
    'clientId': clientId,
    'name': name,
    'startedAt': startedAt.toIso8601String(),
    'programId': programId,
    'dayId': dayId,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'notes': notes,
    'pausedAt': pausedAt?.toIso8601String(),
    'pausedSeconds': pausedSeconds,
    'rest': rest?.toJson(),
  };

  /// Body for `PUT /workouts/active` (in-progress copy).
  Map<String, dynamic> toDraftApi(DateTime now) => {
    'clientId': clientId,
    'name': name,
    'programId': programId,
    'dayId': dayId,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'activeDurationSec': activeDuration(now).inSeconds,
    'notes': notes,
    'exercises': exercises.map((e) => e.toApi()).toList(),
  };

  /// Body for `POST /workouts`. Only completed sets are kept; empty exercises dropped.
  Map<String, dynamic> toFinishApi(DateTime endedAt) => {
    ...toDraftApi(endedAt),
    'endedAt': endedAt.toUtc().toIso8601String(),
    'exercises': [
      for (final e in exercises)
        if (e.completedSets > 0) e.copyWith(sets: e.sets.where((s) => s.completed).toList()).toApi(),
    ],
  };
}

/// A personal record returned when a workout is saved.
class NewRecord {
  const NewRecord({
    required this.exerciseId,
    required this.exerciseName,
    this.exerciseImage,
    required this.type,
    required this.value,
    this.previousValue,
    this.weight,
    this.reps,
  });

  factory NewRecord.fromJson(Map<String, dynamic> j) => NewRecord(
    exerciseId: j['exerciseId'] as String? ?? '',
    exerciseName: j['exerciseName'] as String? ?? 'Exercise',
    exerciseImage: j['exerciseImage'] as String?,
    type: j['type'] as String,
    value: (j['value'] as num).toDouble(),
    previousValue: (j['previousValue'] as num?)?.toDouble(),
    weight: (j['weight'] as num?)?.toDouble(),
    reps: (j['reps'] as num?)?.toInt(),
  );

  final String exerciseId;
  final String exerciseName;
  final String? exerciseImage;
  final String type;
  final double value;
  final double? previousValue;
  final double? weight;
  final int? reps;

  /// Weight-based records are shown in the user's unit; rep records as reps.
  bool get isWeight => type == 'maxWeight' || type == 'e1rm';

  String get title => switch (type) {
    'maxWeight' => 'Heaviest lift',
    'e1rm' => 'Estimated 1RM',
    'maxVolumeSet' => 'Best set volume',
    'maxRepsAtWeight' => 'Most reps',
    _ => 'Personal record',
  };
}

class RankChange {
  const RankChange({required this.key, required this.name, this.from, required this.to, required this.up});

  factory RankChange.fromJson(Map<String, dynamic> j) => RankChange(
    key: j['key'] as String,
    name: j['name'] as String,
    from: j['from'] as String?,
    to: j['to'] as String,
    up: j['direction'] == 'up',
  );

  static const tierNames = ['Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond', 'Elite', 'Legend'];

  final String key;
  final String name;
  final String? from;
  final String to;
  final bool up;

  int get toIndex => tierNames.indexOf(to);
}

/// What the summary screen shows after finishing.
class WorkoutResult {
  const WorkoutResult({
    required this.name,
    required this.duration,
    required this.volumeKg,
    required this.completedSets,
    required this.exerciseCount,
    this.caloriesKcal,
    this.sessionId,
    this.newRecords = const [],
    this.rankChanges = const [],
    this.synced = true,
  });

  final String name;
  final Duration duration;
  final double volumeKg;
  final int completedSets;
  final int exerciseCount;

  /// Server estimate; null when saved offline.
  final int? caloriesKcal;
  final String? sessionId;
  final List<NewRecord> newRecords;
  final List<RankChange> rankChanges;

  /// False when the workout is queued for upload.
  final bool synced;
}

/// Exercises from a program day as a ready-to-log workout.
List<WorkoutExercise> exercisesFromDay(ProgramDay day) => [
  for (final pe in day.exercises)
    WorkoutExercise(
      id: newLocalId(),
      exercise: pe.exercise,
      restSeconds: pe.restSeconds,
      targetReps: pe.repLabel,
      sets: [for (var i = 0; i < pe.sets; i++) WorkoutSet(id: newLocalId())],
    ),
];
