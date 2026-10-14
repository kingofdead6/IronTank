double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

class Macros {
  const Macros({this.kcal = 0, this.protein = 0, this.carbs = 0, this.fat = 0});

  factory Macros.fromJson(Map<String, dynamic> j) =>
      Macros(kcal: _d(j['kcal']), protein: _d(j['protein']), carbs: _d(j['carbs']), fat: _d(j['fat']));

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
}

class FoodEntry {
  const FoodEntry({required this.id, required this.name, required this.macros, required this.loggedAt});

  factory FoodEntry.fromJson(Map<String, dynamic> j) => FoodEntry(
    id: j['id'] as String,
    name: j['name'] as String,
    macros: Macros.fromJson(j),
    loggedAt: DateTime.parse(j['loggedAt'] as String),
  );

  final String id;
  final String name;
  final Macros macros;
  final DateTime loggedAt;
}

class BurnedWorkout {
  const BurnedWorkout({required this.id, required this.name, required this.kcal, required this.durationSec});

  factory BurnedWorkout.fromJson(Map<String, dynamic> j) => BurnedWorkout(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'Workout',
    kcal: (j['kcal'] as num?)?.toInt() ?? 0,
    durationSec: (j['durationSec'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String name;
  final int kcal;
  final int durationSec;
}

/// `GET /calories?date=` — one local day.
class CalorieDay {
  const CalorieDay({
    required this.date,
    required this.entries,
    required this.consumed,
    required this.targetKcal,
    required this.burnedKcal,
    required this.burnedWorkouts,
    required this.remainingKcal,
  });

  factory CalorieDay.fromJson(Map<String, dynamic> j) {
    final burned = j['burned'] as Map<String, dynamic>;
    return CalorieDay(
      date: j['date'] as String,
      entries: (j['entries'] as List<dynamic>).map((e) => FoodEntry.fromJson(e as Map<String, dynamic>)).toList(),
      consumed: Macros.fromJson(j['consumed'] as Map<String, dynamic>),
      targetKcal: (j['targetKcal'] as num?)?.toInt(),
      burnedKcal: (burned['kcal'] as num?)?.toInt() ?? 0,
      burnedWorkouts: (burned['workouts'] as List<dynamic>).map((e) => BurnedWorkout.fromJson(e as Map<String, dynamic>)).toList(),
      remainingKcal: (j['remainingKcal'] as num?)?.toInt(),
    );
  }

  /// YYYY-MM-DD.
  final String date;
  final List<FoodEntry> entries;
  final Macros consumed;

  /// null when the profile is incomplete and no manual target is set.
  final int? targetKcal;
  final int burnedKcal;
  final List<BurnedWorkout> burnedWorkouts;
  final int? remainingKcal;
}

class GoalTarget {
  const GoalTarget({required this.kcal, required this.proteinG, required this.fatG, required this.carbsG});

  factory GoalTarget.fromJson(Map<String, dynamic> j) {
    final m = j['macros'] as Map<String, dynamic>;
    return GoalTarget(
      kcal: (j['kcal'] as num).toInt(),
      proteinG: (m['proteinG'] as num).toInt(),
      fatG: (m['fatG'] as num).toInt(),
      carbsG: (m['carbsG'] as num).toInt(),
    );
  }

  final int kcal;
  final int proteinG;
  final int fatG;
  final int carbsG;
}

/// `GET /calories/target` — TDEE breakdown plus the effective target.
class CalorieTarget {
  const CalorieTarget({
    required this.goal,
    this.customTargetKcal,
    this.effectiveTargetKcal,
    this.bmr,
    this.tdee,
    this.targets = const {},
    this.missing = const [],
  });

  factory CalorieTarget.fromJson(Map<String, dynamic> j) {
    final t = j['tdee'] as Map<String, dynamic>?;
    return CalorieTarget(
      goal: j['goal'] as String? ?? 'maintain',
      customTargetKcal: (j['customTargetKcal'] as num?)?.toInt(),
      effectiveTargetKcal: (j['effectiveTargetKcal'] as num?)?.toInt(),
      bmr: (t?['bmr'] as num?)?.toInt(),
      tdee: (t?['tdee'] as num?)?.toInt(),
      targets: t == null
          ? const {}
          : (t['targets'] as Map<String, dynamic>).map((k, v) => MapEntry(k, GoalTarget.fromJson(v as Map<String, dynamic>))),
      missing: (j['missing'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }

  final String goal;
  final int? customTargetKcal;
  final int? effectiveTargetKcal;
  final int? bmr;
  final int? tdee;
  final Map<String, GoalTarget> targets;
  final List<String> missing;

  bool get profileIncomplete => missing.isNotEmpty;

  /// Macro targets for the current goal, if the TDEE is known.
  GoalTarget? get goalTarget => targets[goal];
}
