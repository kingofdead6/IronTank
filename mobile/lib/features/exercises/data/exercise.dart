/// A library or custom exercise (mirrors the API's Exercise).
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.equipment = 'none',
    this.category = 'strength',
    this.level = 'beginner',
    this.instructions = const [],
    this.images = const [],
    this.metValue = 5,
    this.isBodyweight = false,
    this.liftKey,
    this.isCustom = false,
  });

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
    id: j['id'] as String,
    name: j['name'] as String,
    primaryMuscles: _strings(j['primaryMuscles']),
    secondaryMuscles: _strings(j['secondaryMuscles']),
    equipment: j['equipment'] as String? ?? 'none',
    category: j['category'] as String? ?? 'strength',
    level: j['level'] as String? ?? 'beginner',
    instructions: _strings(j['instructions']),
    images: _strings(j['images']),
    metValue: (j['metValue'] as num?)?.toDouble() ?? 5,
    isBodyweight: j['isBodyweight'] as bool? ?? false,
    liftKey: j['liftKey'] as String?,
    isCustom: j['isCustom'] as bool? ?? false,
  );

  static List<String> _strings(Object? v) => (v as List<dynamic>? ?? const []).cast<String>();

  final String id;
  final String name;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final String equipment;
  final String category;
  final String level;
  final List<String> instructions;
  final List<String> images;
  final double metValue;
  final bool isBodyweight;
  final String? liftKey;
  final bool isCustom;

  String? get thumbnail => images.isEmpty ? null : images.first;

  /// Hero tag shared by the library card image and the detail gallery.
  String get heroTag => 'exercise-image-$id';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'primaryMuscles': primaryMuscles,
    'secondaryMuscles': secondaryMuscles,
    'equipment': equipment,
    'category': category,
    'level': level,
    'instructions': instructions,
    'images': images,
    'metValue': metValue,
    'isBodyweight': isBodyweight,
    'liftKey': liftKey,
    'isCustom': isCustom,
  };
}

/// Filter values offered by `GET /exercises/filters`.
class ExerciseFilterOptions {
  const ExerciseFilterOptions({
    required this.muscles,
    required this.equipment,
    required this.categories,
    required this.levels,
  });

  factory ExerciseFilterOptions.fromJson(Map<String, dynamic> j) => ExerciseFilterOptions(
    muscles: (j['muscles'] as List<dynamic>).cast<String>(),
    equipment: (j['equipment'] as List<dynamic>).cast<String>(),
    categories: (j['categories'] as List<dynamic>).cast<String>(),
    levels: (j['levels'] as List<dynamic>).cast<String>(),
  );

  final List<String> muscles;
  final List<String> equipment;
  final List<String> categories;
  final List<String> levels;
}

/// Active library filters.
class ExerciseFilters {
  const ExerciseFilters({
    this.query = '',
    this.muscles = const {},
    this.equipment = const {},
    this.categories = const {},
    this.customOnly = false,
  });

  final String query;
  final Set<String> muscles;
  final Set<String> equipment;
  final Set<String> categories;
  final bool customOnly;

  int get activeCount => muscles.length + equipment.length + categories.length + (customOnly ? 1 : 0);

  ExerciseFilters copyWith({
    String? query,
    Set<String>? muscles,
    Set<String>? equipment,
    Set<String>? categories,
    bool? customOnly,
  }) => ExerciseFilters(
    query: query ?? this.query,
    muscles: muscles ?? this.muscles,
    equipment: equipment ?? this.equipment,
    categories: categories ?? this.categories,
    customOnly: customOnly ?? this.customOnly,
  );

  Map<String, dynamic> toQuery() => {
    'q': query.trim().isEmpty ? null : query.trim(),
    'muscle': muscles.toList(),
    'equipment': equipment.toList(),
    'category': categories.toList(),
    'scope': customOnly ? 'custom' : 'all',
  };
}

/// Human labels for API muscle/equipment values ("middle back" → "Middle back").
String labelize(String value) => value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

/// A personal-record value (`maxWeight`, `e1rm`, ...).
class RecordValue {
  const RecordValue({required this.value, this.weight, this.reps, this.achievedAt});

  factory RecordValue.fromJson(Map<String, dynamic> j) => RecordValue(
    value: (j['value'] as num).toDouble(),
    weight: (j['weight'] as num?)?.toDouble(),
    reps: (j['reps'] as num?)?.toInt(),
    achievedAt: j['achievedAt'] == null ? null : DateTime.parse(j['achievedAt'] as String),
  );

  final double value;
  final double? weight;
  final int? reps;
  final DateTime? achievedAt;
}

/// Current bests for one exercise (from `GET /prs/:exerciseId`).
class ExerciseBests {
  const ExerciseBests({this.maxWeight, this.e1rm, this.maxVolumeSet, this.repsAtWeight = const []});

  factory ExerciseBests.fromJson(Map<String, dynamic> j) {
    RecordValue? r(String k) => j[k] == null ? null : RecordValue.fromJson(j[k] as Map<String, dynamic>);
    return ExerciseBests(
      maxWeight: r('maxWeight'),
      e1rm: r('e1rm'),
      maxVolumeSet: r('maxVolumeSet'),
      repsAtWeight: (j['repsAtWeight'] as List<dynamic>? ?? const [])
          .map((e) => (weight: ((e as Map)['weight'] as num).toDouble(), reps: (e['reps'] as num).toInt()))
          .toList(),
    );
  }

  final RecordValue? maxWeight;
  final RecordValue? e1rm;
  final RecordValue? maxVolumeSet;
  final List<({double weight, int reps})> repsAtWeight;

  bool get isEmpty => maxWeight == null && e1rm == null && maxVolumeSet == null && repsAtWeight.isEmpty;
}

/// One point of an exercise's history (from `GET /stats/exercise/:id`).
class ExerciseHistoryPoint {
  const ExerciseHistoryPoint({required this.sessionId, required this.date, this.bestE1rm, this.topWeight, this.topReps, required this.volume});

  factory ExerciseHistoryPoint.fromJson(Map<String, dynamic> j) {
    final top = j['topSet'] as Map<String, dynamic>?;
    return ExerciseHistoryPoint(
      sessionId: j['sessionId'] as String,
      date: DateTime.parse(j['date'] as String),
      bestE1rm: (j['bestE1rm'] as num?)?.toDouble(),
      topWeight: (top?['weight'] as num?)?.toDouble(),
      topReps: (top?['reps'] as num?)?.toInt(),
      volume: (j['volume'] as num?)?.toDouble() ?? 0,
    );
  }

  final String sessionId;
  final DateTime date;
  final double? bestE1rm;
  final double? topWeight;
  final int? topReps;
  final double volume;
}

/// One record event in an exercise's PR history.
class RecordEvent {
  const RecordEvent({
    required this.id,
    required this.type,
    required this.value,
    this.previousValue,
    this.weight,
    this.reps,
    required this.isBaseline,
    required this.achievedAt,
    this.exerciseId,
    this.exerciseName,
    this.exerciseImage,
  });

  factory RecordEvent.fromJson(Map<String, dynamic> j) {
    final ex = j['exercise'] as Map<String, dynamic>?;
    return RecordEvent(
      id: j['id'] as String,
      type: j['type'] as String,
      value: (j['value'] as num).toDouble(),
      previousValue: (j['previousValue'] as num?)?.toDouble(),
      weight: (j['weight'] as num?)?.toDouble(),
      reps: (j['reps'] as num?)?.toInt(),
      isBaseline: j['isBaseline'] as bool? ?? false,
      achievedAt: DateTime.parse(j['achievedAt'] as String),
      exerciseId: j['exerciseId'] as String?,
      exerciseName: ex?['name'] as String?,
      exerciseImage: ex?['image'] as String?,
    );
  }

  final String id;
  final String type;
  final double value;
  final double? previousValue;
  final double? weight;
  final int? reps;
  final bool isBaseline;
  final DateTime achievedAt;
  final String? exerciseId;
  final String? exerciseName;
  final String? exerciseImage;
}
