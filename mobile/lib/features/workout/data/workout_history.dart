import 'workout_models.dart';

/// A saved workout as returned by `GET /workouts` (read-only history view).
class WorkoutSummary {
  const WorkoutSummary({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.durationSec,
    required this.totalVolume,
    required this.caloriesBurned,
    required this.prCount,
    required this.exercises,
    this.notes = '',
  });

  factory WorkoutSummary.fromJson(Map<String, dynamic> j) => WorkoutSummary(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'Workout',
    startedAt: DateTime.parse(j['startedAt'] as String),
    durationSec: (j['activeDurationSec'] as num?)?.toInt() ?? (j['durationSec'] as num?)?.toInt() ?? 0,
    totalVolume: (j['totalVolume'] as num?)?.toDouble() ?? 0,
    caloriesBurned: (j['caloriesBurned'] as num?)?.toInt() ?? 0,
    prCount: (j['prCount'] as num?)?.toInt() ?? 0,
    notes: j['notes'] as String? ?? '',
    exercises: (j['exercises'] as List<dynamic>? ?? const []).map((e) {
      final m = e as Map<String, dynamic>;
      return LoggedExercise(
        exerciseId: m['exerciseId'] as String,
        name: m['exerciseName'] as String? ?? 'Exercise',
        sets: (m['sets'] as List<dynamic>? ?? const []).map((s) => WorkoutSet.fromJson(s as Map<String, dynamic>)).toList(),
      );
    }).toList(),
  );

  final String id;
  final String name;
  final DateTime startedAt;
  final int durationSec;
  final double totalVolume;
  final int caloriesBurned;
  final int prCount;
  final String notes;
  final List<LoggedExercise> exercises;

  int get setCount => exercises.fold(0, (s, e) => s + e.sets.length);
}

class LoggedExercise {
  const LoggedExercise({required this.exerciseId, required this.name, required this.sets});

  final String exerciseId;
  final String name;
  final List<WorkoutSet> sets;
}
