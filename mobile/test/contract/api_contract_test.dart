// End-to-end contract test: the app's real repositories and auth stack against
// a running backend. Skipped unless an API URL is supplied:
//
//   cd backend && PORT=4100 npm run dev:memory
//   cd mobile && flutter test test/contract --dart-define=API_URL=http://localhost:4100/api/v1
@TestOn('vm')
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrank/core/config/app_config.dart';
import 'package:ironrank/core/storage/local_store.dart';
import 'package:ironrank/core/storage/token_storage.dart';
import 'package:ironrank/features/auth/data/auth_repository.dart';
import 'package:ironrank/features/auth/data/user.dart';
import 'package:ironrank/features/exercises/data/exercise.dart';
import 'package:ironrank/features/exercises/data/exercise_repository.dart';
import 'package:ironrank/features/programs/data/program.dart';
import 'package:ironrank/features/programs/data/program_repository.dart';
import 'package:ironrank/features/workout/data/workout_models.dart';
import 'package:ironrank/features/workout/data/workout_repository.dart';

import '../helpers/harness.dart';

const apiUrl = String.fromEnvironment('API_URL');

void main() {
  late ProviderContainer c;
  late MemoryTokenStorage tokens;

  setUpAll(() async {
    tokens = MemoryTokenStorage();
    final LocalStore store = await testStore();
    c = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: apiUrl, connectTimeout: Duration(seconds: 5), receiveTimeout: Duration(seconds: 20)),
        ),
        localStoreProvider.overrideWithValue(store),
        tokenStorageProvider.overrideWithValue(tokens),
      ],
    );
  });

  tearDownAll(() => c.dispose());

  test('full user journey parses every response', () async {
    final auth = c.read(authRepositoryProvider);
    final email = 'contract_${DateTime.now().millisecondsSinceEpoch}@test.dev';

    // Auth + profile.
    var user = await auth.register(email: email, password: 'Sup3rSecret!', username: 'contract');
    expect(user.onboardingComplete, isFalse);
    user = await auth.updateProfile(
      ProfileUpdate(sex: Sex.male, birthDate: DateTime(1995, 3, 1), heightCm: 180, bodyweightKg: 80, goal: Goal.cut, onboardingComplete: true),
    );
    expect(user.bodyweightKg, 80);
    expect(user.goal, Goal.cut);

    // Silent refresh: break the access token, keep the refresh token.
    final current = (await tokens.read())!;
    await tokens.save(AuthTokens(accessToken: '${current.accessToken}broken', refreshToken: current.refreshToken));
    final me = await auth.fetchMe();
    expect(me.email, email);
    expect((await tokens.read())!.refreshToken, isNot(current.refreshToken), reason: 'refresh token rotated');

    // Exercises.
    final exercises = c.read(exerciseRepositoryProvider);
    final options = await exercises.filterOptions();
    expect(options.muscles, contains('chest'));
    final page = await exercises.list(const ExerciseFilters(query: 'barbell bench press - medium'));
    final bench = page.items.firstWhere((e) => e.liftKey == 'bench_press');
    expect(bench.images, isNotEmpty);
    final chestBarbell = await exercises.list(const ExerciseFilters(muscles: {'chest'}, equipment: {'barbell'}));
    expect(chestBarbell.items.every((e) => e.equipment == 'barbell'), isTrue);

    // Programs.
    final programs = c.read(programRepositoryProvider);
    final templates = await programs.list(ProgramScope.templates);
    expect(templates.map((p) => p.templateKey), containsAll(['ppl', 'upper-lower', 'full-body-3x', 'strength-5x5']));
    final activated = await programs.activate(templates.firstWhere((p) => p.templateKey == 'strength-5x5').id);
    expect(activated.isActive, isTrue);
    final active = await programs.active();
    expect(active.nextDay!.name, 'Workout A');
    expect(active.nextDay!.exercises.first.exercise.name, isNotEmpty);

    // Workouts: two sessions so the second sets real PRs.
    final workouts = c.read(workoutRepositoryProvider);
    Future<SaveWorkoutResponse> log(double kg, int daysAgo) {
      final start = DateTime.now().subtract(Duration(days: daysAgo, hours: 1));
      final w = ActiveWorkout(
        clientId: newLocalId(),
        name: 'Workout A',
        startedAt: start,
        programId: activated.id,
        dayId: active.nextDay!.id,
        exercises: [
          WorkoutExercise(
            id: newLocalId(),
            exercise: ExerciseSummary.fromExercise(bench),
            sets: [
              for (var i = 0; i < 3; i++)
                WorkoutSet(id: newLocalId(), weightKg: kg, reps: 5, completed: true, completedAt: start.add(Duration(minutes: 5 * i))),
            ],
          ),
        ],
      );
      return workouts.save(w.toFinishApi(start.add(const Duration(minutes: 50))));
    }

    final first = await log(80, 3);
    expect(first.newRecords, isEmpty, reason: 'first session sets baselines only');
    expect(first.caloriesKcal, greaterThan(0));
    // 80 kg × 5 → e1RM 93.3 ÷ 80 kg bodyweight = 1.17 → first-ever bench rank: Platinum.
    expect(first.rankChanges.map((r) => (r.key, r.to)), contains(('bench_press', 'Platinum')));
    final second = await log(90, 1);
    expect(second.newRecords.map((r) => r.type), containsAll(['maxWeight', 'e1rm', 'maxVolumeSet']));
    // 90 kg × 5 → 1.31: still Platinum, so no rank change this time.
    expect(second.rankChanges.where((r) => r.key == 'bench_press'), isEmpty);

    final previous = await workouts.previous([bench.id]);
    expect(previous[bench.id]!.first.weightKg, 90);

    final history = await workouts.history();
    expect(history.items, hasLength(2));
    final detail = await workouts.get(history.items.first.id);
    expect(detail.exercises.single.sets, hasLength(3));

    // Exercise records & trend.
    final records = await exercises.records(bench.id);
    expect(records.bests.maxWeight!.value, 90);
    final trend = await exercises.history(bench.id);
    expect(trend.map((p) => p.bestE1rm), [93.3, 105.0]);
  }, skip: apiUrl.isEmpty ? 'Set --dart-define=API_URL to run against a live backend' : null);
}
