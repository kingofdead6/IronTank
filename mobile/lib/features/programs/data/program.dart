import '../../exercises/data/exercise.dart';

/// Lightweight exercise info embedded in program responses.
class ExerciseSummary {
  const ExerciseSummary({
    required this.id,
    required this.name,
    this.image,
    this.primaryMuscles = const [],
    this.equipment = 'none',
    this.isBodyweight = false,
  });

  factory ExerciseSummary.fromJson(Map<String, dynamic> j) => ExerciseSummary(
    id: j['id'] as String,
    name: j['name'] as String,
    image: j['image'] as String?,
    primaryMuscles: (j['primaryMuscles'] as List<dynamic>? ?? const []).cast<String>(),
    equipment: j['equipment'] as String? ?? 'none',
    isBodyweight: j['isBodyweight'] as bool? ?? false,
  );

  factory ExerciseSummary.fromExercise(Exercise e) => ExerciseSummary(
    id: e.id,
    name: e.name,
    image: e.thumbnail,
    primaryMuscles: e.primaryMuscles,
    equipment: e.equipment,
    isBodyweight: e.isBodyweight,
  );

  final String id;
  final String name;
  final String? image;
  final List<String> primaryMuscles;
  final String equipment;
  final bool isBodyweight;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'image': image,
    'primaryMuscles': primaryMuscles,
    'equipment': equipment,
    'isBodyweight': isBodyweight,
  };
}

/// One planned exercise within a program day.
class ProgramExercise {
  const ProgramExercise({
    this.id,
    required this.exercise,
    this.sets = 3,
    this.repMin = 8,
    this.repMax = 12,
    this.targetRpe,
    this.restSeconds = 90,
    this.notes = '',
  });

  factory ProgramExercise.fromJson(Map<String, dynamic> j) {
    final range = j['repRange'] as Map<String, dynamic>? ?? const {};
    final summary = j['exercise'] as Map<String, dynamic>?;
    return ProgramExercise(
      id: j['id'] as String?,
      exercise: summary != null
          ? ExerciseSummary.fromJson(summary)
          : ExerciseSummary(id: j['exerciseId'] as String, name: 'Exercise'),
      sets: (j['sets'] as num?)?.toInt() ?? 3,
      repMin: (range['min'] as num?)?.toInt() ?? 8,
      repMax: (range['max'] as num?)?.toInt() ?? 12,
      targetRpe: (j['targetRPE'] as num?)?.toDouble(),
      restSeconds: (j['restSeconds'] as num?)?.toInt() ?? 90,
      notes: j['notes'] as String? ?? '',
    );
  }

  final String? id;
  final ExerciseSummary exercise;
  final int sets;
  final int repMin;
  final int repMax;
  final double? targetRpe;
  final int restSeconds;
  final String notes;

  String get repLabel => repMin == repMax ? '$repMin' : '$repMin–$repMax';
  String get prescription => '$sets × $repLabel';

  ProgramExercise copyWith({int? sets, int? repMin, int? repMax, double? targetRpe, bool clearRpe = false, int? restSeconds, String? notes}) =>
      ProgramExercise(
        id: id,
        exercise: exercise,
        sets: sets ?? this.sets,
        repMin: repMin ?? this.repMin,
        repMax: repMax ?? this.repMax,
        targetRpe: clearRpe ? null : (targetRpe ?? this.targetRpe),
        restSeconds: restSeconds ?? this.restSeconds,
        notes: notes ?? this.notes,
      );

  /// Request body shape for create/update.
  Map<String, dynamic> toApi() => {
    'exerciseId': exercise.id,
    'sets': sets,
    'repRange': {'min': repMin, 'max': repMax},
    'targetRPE': targetRpe,
    'restSeconds': restSeconds,
    'notes': notes,
  };

  /// Local persistence (active workout snapshot).
  Map<String, dynamic> toJson() => {
    'id': id,
    'exercise': exercise.toJson(),
    'exerciseId': exercise.id,
    'sets': sets,
    'repRange': {'min': repMin, 'max': repMax},
    'targetRPE': targetRpe,
    'restSeconds': restSeconds,
    'notes': notes,
  };
}

class ProgramDay {
  const ProgramDay({this.id, required this.name, this.exercises = const []});

  factory ProgramDay.fromJson(Map<String, dynamic> j) => ProgramDay(
    id: j['id'] as String?,
    name: j['name'] as String,
    exercises: (j['exercises'] as List<dynamic>? ?? const [])
        .map((e) => ProgramExercise.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final String? id;
  final String name;
  final List<ProgramExercise> exercises;

  int get totalSets => exercises.fold(0, (s, e) => s + e.sets);

  ProgramDay copyWith({String? name, List<ProgramExercise>? exercises}) =>
      ProgramDay(id: id, name: name ?? this.name, exercises: exercises ?? this.exercises);

  Map<String, dynamic> toApi() => {'name': name, 'exercises': exercises.map((e) => e.toApi()).toList()};
}

class Program {
  const Program({
    required this.id,
    required this.name,
    this.description = '',
    this.weeks = 8,
    this.days = const [],
    this.isTemplate = false,
    this.isActive = false,
    this.templateKey,
  });

  factory Program.fromJson(Map<String, dynamic> j) => Program(
    id: j['id'] as String,
    name: j['name'] as String,
    description: j['description'] as String? ?? '',
    weeks: (j['weeks'] as num?)?.toInt() ?? 8,
    days: (j['days'] as List<dynamic>? ?? const []).map((d) => ProgramDay.fromJson(d as Map<String, dynamic>)).toList(),
    isTemplate: j['isTemplate'] as bool? ?? false,
    isActive: j['isActive'] as bool? ?? false,
    templateKey: j['templateKey'] as String?,
  );

  final String id;
  final String name;
  final String description;
  final int weeks;
  final List<ProgramDay> days;
  final bool isTemplate;
  final bool isActive;
  final String? templateKey;

  int get exerciseCount => days.fold(0, (s, d) => s + d.exercises.length);

  /// Distinct primary muscles trained across the program (for card subtitles).
  List<String> get focusMuscles {
    final counts = <String, int>{};
    for (final d in days) {
      for (final e in d.exercises) {
        for (final m in e.exercise.primaryMuscles) {
          counts[m] = (counts[m] ?? 0) + e.sets;
        }
      }
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }
}

/// `GET /programs/active` → program + the day to train next.
class ActiveProgram {
  const ActiveProgram({this.program, this.nextDay, this.nextDayIndex});

  factory ActiveProgram.fromJson(Map<String, dynamic> j) {
    final next = j['nextDay'] as Map<String, dynamic>?;
    return ActiveProgram(
      program: j['program'] == null ? null : Program.fromJson(j['program'] as Map<String, dynamic>),
      nextDay: next == null ? null : ProgramDay.fromJson(next),
      nextDayIndex: (next?['index'] as num?)?.toInt(),
    );
  }

  final Program? program;
  final ProgramDay? nextDay;
  final int? nextDayIndex;
}
