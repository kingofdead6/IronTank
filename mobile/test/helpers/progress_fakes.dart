import 'package:ironrank/core/storage/local_store.dart';
import 'package:ironrank/core/utils/units.dart';
import 'package:ironrank/features/auth/application/auth_controller.dart';
import 'package:ironrank/features/auth/data/user.dart';
import 'package:ironrank/features/calories/data/calorie_models.dart';
import 'package:ironrank/features/calories/data/calorie_repository.dart';
import 'package:ironrank/features/exercises/data/exercise.dart';
import 'package:ironrank/features/progress/data/progress_models.dart';
import 'package:ironrank/features/progress/data/progress_repository.dart';

import 'fakes.dart';

final testUser = User(
  id: 'u1',
  email: 'lifter@test.dev',
  username: 'Nadia',
  sex: Sex.female,
  birthDate: DateTime(1996, 4, 2),
  heightCm: 168,
  bodyweightKg: 62,
  goal: Goal.cut,
  onboardingComplete: true,
  createdAt: DateTime(2026, 1, 10),
);

/// Signed-in session without touching storage or the network.
class FakeAuthController extends AuthController {
  FakeAuthController([this.user]);

  final User? user;

  @override
  AuthState build() => AuthState.signedIn(user ?? testUser);

  @override
  Future<void> updateProfile(ProfileUpdate update) async {
    final json = {...state.user!.toJson(), ...update.toJson()};
    state = AuthState.signedIn(User.fromJson(json));
  }

  @override
  Future<void> refreshUser() async {}
}

Map<String, dynamic> overviewJson({int sessions = 9}) {
  final today = DateTime.now();
  final monday = today.subtract(Duration(days: today.weekday - 1));
  String day(DateTime d) => d.toIso8601String().substring(0, 10);
  return {
    'range': {'from': day(monday.subtract(const Duration(days: 7 * 11))), 'to': day(today), 'weeks': 12, 'tz': 'UTC'},
    'totals': {'sessions': sessions, 'volume': 48250, 'durationSec': 32000, 'calories': 3100, 'prs': 6, 'avgSessionsPerWeek': 0.8},
    'streak': {'days': 1, 'weeks': 3},
    'weekly': [
      for (var i = 0; i < 12; i++)
        {'weekStart': day(monday.subtract(Duration(days: 7 * (11 - i)))), 'sessions': i % 3, 'volume': i * 900.0, 'durationSec': 3600},
    ],
    'muscleDistribution': [
      {'group': 'chest', 'sets': 30, 'percent': 28.0},
      {'group': 'back', 'sets': 26, 'percent': 24.0},
      {'group': 'legs', 'sets': 32, 'percent': 30.0},
      {'group': 'shoulders', 'sets': 10, 'percent': 9.0},
      {'group': 'arms', 'sets': 8, 'percent': 7.0},
      {'group': 'core', 'sets': 2, 'percent': 2.0},
    ],
    'heatmap': [
      for (var i = 0; i < sessions; i++) {'date': day(today.subtract(Duration(days: i * 3))), 'sessions': 1, 'volume': 4000.0 + i * 300},
    ],
    'lastWorkoutAt': today.toIso8601String(),
    'daysSinceLastWorkout': 0,
  };
}

Map<String, dynamic> ranksJson({int benchTier = 3}) {
  const tiers = ['Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond', 'Elite', 'Legend'];
  Map<String, dynamic> lift(String key, String name, int? tier, {double? e1rm, String? exerciseId}) => {
    'key': key,
    'name': name,
    'ranked': tier != null,
    if (tier != null) ...{
      'tierIndex': tier,
      'tier': tiers[tier],
      'nextTier': tier < 6 ? tiers[tier + 1] : null,
      'progress': 40,
      'ratio': 1.21,
      'e1rm': e1rm ?? 75.0,
      'bodyweightKg': 62.0,
      'nextTierE1rm': 84.0,
      'exerciseId': exerciseId,
    },
    'thresholds': [0, 0.35, 0.5, 0.7, 0.9, 1.1, 1.35],
  };
  return {
    'sex': 'female',
    'assumedSex': false,
    'tiers': tiers,
    'overall': {'ranked': true, 'liftsRanked': 3, 'tierIndex': 3, 'tier': 'Platinum', 'nextTier': 'Diamond', 'progress': 22, 'score': 3.22},
    'lifts': [
      lift('bench_press', 'Bench Press', benchTier, e1rm: 60, exerciseId: bench.id),
      lift('squat', 'Squat', 4, e1rm: 95, exerciseId: squat.id),
      lift('deadlift', 'Deadlift', 3, e1rm: 110),
      lift('overhead_press', 'Overhead Press', null),
      lift('barbell_row', 'Barbell Row', null),
      lift('pull_up', 'Pull-Up', null),
      lift('dips', 'Dips', null),
    ],
    'muscleGroups': [
      {'group': 'chest', 'ranked': true, 'tierIndex': benchTier, 'tier': tiers[benchTier], 'progress': 40},
      {'group': 'back', 'ranked': true, 'tierIndex': 3, 'tier': 'Platinum', 'progress': 10},
      {'group': 'shoulders', 'ranked': false},
      {'group': 'arms', 'ranked': true, 'tierIndex': 2, 'tier': 'Gold', 'progress': 80},
      {'group': 'legs', 'ranked': true, 'tierIndex': 4, 'tier': 'Diamond', 'progress': 5},
      {'group': 'core', 'ranked': true, 'tierIndex': 3, 'tier': 'Platinum', 'progress': 50},
    ],
  };
}

class FakeProgressRepository extends ProgressRepository {
  FakeProgressRepository(LocalStore store) : super(unusedApi, store);

  int benchTier = 3;
  final weighIns = <double>[63.4, 63.0, 62.6, 62.2, 62.0];

  @override
  Future<StatsOverview> overview({required int weeks, required String tz}) async => StatsOverview.fromJson(overviewJson());

  @override
  Future<Ranks> ranks() async => Ranks.fromJson(ranksJson(benchTier: benchTier));

  @override
  Future<List<RecordEvent>> latestRecords({int limit = 10}) async => [
    RecordEvent(
      id: 'r1',
      type: 'e1rm',
      value: 60,
      previousValue: 57.5,
      isBaseline: false,
      achievedAt: DateTime.now().subtract(const Duration(days: 1)),
      exerciseId: bench.id,
      exerciseName: 'Bench Press',
    ),
    RecordEvent(id: 'r2', type: 'maxRepsAtWeight', value: 12, weight: 0, isBaseline: false, achievedAt: DateTime.now(), exerciseName: 'Pullups'),
  ];

  @override
  Future<List<BodyweightEntry>> bodyweight({int limit = 100}) async => [
    for (var i = 0; i < weighIns.length; i++)
      BodyweightEntry(id: 'b$i', kg: weighIns[i], date: DateTime.now().subtract(Duration(days: (weighIns.length - i) * 7))),
  ];

  @override
  Future<void> addBodyweight(double kg, {DateTime? date}) async => weighIns.add(kg);
}

class FakeCalorieRepository extends CalorieRepository {
  FakeCalorieRepository() : super(unusedApi);

  final entries = <FoodEntry>[
    FoodEntry(id: 'f1', name: 'Oats', macros: const Macros(kcal: 380, protein: 14, carbs: 62, fat: 7), loggedAt: DateTime.now()),
  ];

  @override
  Future<CalorieDay> day(String date, String tz) async {
    final consumed = entries.fold<Macros>(
      const Macros(),
      (s, e) => Macros(
        kcal: s.kcal + e.macros.kcal,
        protein: s.protein + e.macros.protein,
        carbs: s.carbs + e.macros.carbs,
        fat: s.fat + e.macros.fat,
      ),
    );
    return CalorieDay(
      date: date,
      entries: List.of(entries),
      consumed: consumed,
      targetKcal: 1850,
      burnedKcal: 310,
      burnedWorkouts: const [BurnedWorkout(id: 'w1', name: 'Upper', kcal: 310, durationSec: 3300)],
      remainingKcal: (1850 - consumed.kcal + 310).round(),
    );
  }

  @override
  Future<CalorieDay> addEntry({
    required String date,
    required String tz,
    required String name,
    required double kcal,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
  }) async {
    entries.add(FoodEntry(id: 'f${entries.length + 1}', name: name, macros: Macros(kcal: kcal, protein: protein, carbs: carbs, fat: fat), loggedAt: DateTime.now()));
    return day(date, tz);
  }

  @override
  Future<void> deleteEntry(String id) async => entries.removeWhere((e) => e.id == id);

  @override
  Future<CalorieTarget> target() async => const CalorieTarget(
    goal: 'cut',
    effectiveTargetKcal: 1850,
    bmr: 1400,
    tdee: 2310,
    targets: {
      'cut': GoalTarget(kcal: 1850, proteinG: 136, fatG: 51, carbsG: 207),
      'maintain': GoalTarget(kcal: 2310, proteinG: 112, fatG: 64, carbsG: 322),
      'bulk': GoalTarget(kcal: 2541, proteinG: 112, fatG: 71, carbsG: 361),
    },
  );
}

/// Unit used by [testUser].
const testUnit = WeightUnit.kg;
