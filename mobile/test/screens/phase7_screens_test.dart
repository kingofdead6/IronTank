import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrank/core/notifications/notification_service.dart';
import 'package:ironrank/core/storage/local_store.dart';
import 'package:ironrank/core/widgets/gradient_button.dart';
import 'package:ironrank/core/widgets/training_heatmap.dart';
import 'package:ironrank/features/auth/application/auth_controller.dart';
import 'package:ironrank/features/auth/data/user.dart';
import 'package:ironrank/core/utils/units.dart';
import 'package:ironrank/features/calories/data/calorie_repository.dart';
import 'package:ironrank/features/calories/presentation/calories_screen.dart';
import 'package:ironrank/features/exercises/data/exercise_repository.dart';
import 'package:ironrank/features/home/presentation/home_screen.dart';
import 'package:ironrank/features/profile/presentation/edit_profile_screen.dart';
import 'package:ironrank/features/profile/presentation/profile_screen.dart';
import 'package:ironrank/features/programs/data/program_repository.dart';
import 'package:ironrank/features/progress/data/progress_models.dart';
import 'package:ironrank/features/progress/data/progress_repository.dart';
import 'package:ironrank/features/progress/presentation/progress_screen.dart';
import 'package:ironrank/features/ranks/application/rank_seen_store.dart';
import 'package:ironrank/features/ranks/presentation/ranks_screen.dart';
import 'package:ironrank/features/workout/data/workout_repository.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';
import '../helpers/progress_fakes.dart';
import '../helpers/workout_fakes.dart';

void main() {
  late LocalStore store;
  late FakeProgressRepository progress;
  late FakeCalorieRepository calories;

  setUp(() async {
    store = await testStore();
    progress = FakeProgressRepository(store);
    calories = FakeCalorieRepository();
  });

  List<dynamic> overrides() => [
    authControllerProvider.overrideWith(FakeAuthController.new),
    progressRepositoryProvider.overrideWithValue(progress),
    calorieRepositoryProvider.overrideWithValue(calories),
    exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository()),
    programRepositoryProvider.overrideWithValue(FakeProgramRepository(store)),
    workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository(store)),
    notificationServiceProvider.overrideWithValue(FakeNotifications()),
  ];

  testWidgets('home dashboard shows streak, rank, today, volume, calories and PRs', (tester) async {
    await pumpScreen(tester, const HomeScreen(), overrides: overrides());
    await pumpFrames(tester, frames: 40);
    expect(find.text('Nadia'), findsOneWidget);
    expect(find.text('Platinum'), findsOneWidget);
    expect(find.text('Upper'), findsOneWidget); // next program day
    await snapshot(find.byType(HomeScreen), 'home');

    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await pumpFrames(tester);
    expect(find.text('Latest PRs'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
  });

  testWidgets('progress tab renders every chart', (tester) async {
    await pumpScreen(tester, const ProgressScreen(), overrides: overrides());
    await pumpFrames(tester, frames: 40);
    expect(find.text('Weekly volume'), findsOneWidget);
    await snapshot(find.byType(ProgressScreen), 'progress');

    await tester.drag(find.byType(ListView).first, const Offset(0, -1400));
    await pumpFrames(tester, frames: 30);
    expect(find.byType(TrainingHeatmap), findsOneWidget);
    expect(find.text('Muscle distribution'), findsOneWidget);
    await snapshot(find.byType(ProgressScreen), 'progress_lower');
  });

  testWidgets('ranks screen lists lifts and celebrates a tier gained since last visit', (tester) async {
    // Last visit: bench was Gold (2); now it is Platinum (3).
    await RankSeenStore(store).save({'overall': 3, 'bench_press': 2, 'squat': 4, 'deadlift': 3});
    await pumpScreen(tester, const RanksScreen(), overrides: overrides(), store: store);
    await pumpFrames(tester, frames: 60);

    expect(find.text('LEVEL UP'), findsOneWidget);
    expect(find.text('Bench Press: Gold → Platinum'), findsOneWidget);
    await snapshot(find.byType(MaterialApp), 'level_up');

    await tester.tap(find.widgetWithText(GradientButton, 'Awesome'));
    await pumpFrames(tester);
    expect(find.text('LEVEL UP'), findsNothing);
    expect(find.text('Bench Press'), findsWidgets);
    await snapshot(find.byType(RanksScreen), 'ranks');

    // The new tiers are now remembered: no celebration next time.
    expect(RankSeenStore(store).read()!['bench_press'], 3);
  });

  testWidgets('calories screen shows the ring and logs food via quick add', (tester) async {
    await pumpScreen(tester, const CaloriesScreen(), overrides: overrides());
    await pumpFrames(tester, frames: 40);
    expect(find.text('kcal left'), findsOneWidget);
    expect(find.text('Oats'), findsOneWidget);
    await snapshot(find.byType(CaloriesScreen), 'calories');

    await tester.tap(find.text('Add food'));
    await pumpFrames(tester);
    await tester.tap(find.textContaining('Protein shake'));
    await pumpFrames(tester);
    expect(calories.entries.map((e) => e.name), contains('Protein shake'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await pumpFrames(tester);
    expect(find.text('Protein shake'), findsOneWidget);
  });

  testWidgets('profile switches units and theme; edit profile renders', (tester) async {
    await pumpScreen(tester, const ProfileScreen(), overrides: overrides());
    await pumpFrames(tester, frames: 30);
    expect(find.text('62 kg'), findsOneWidget);
    await snapshot(find.byType(ProfileScreen), 'profile');

    await tester.tap(find.text('Pounds'));
    await pumpFrames(tester);
    expect(find.text('136.7 lb'), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byType(ProfileScreen)));
    expect(container.read(currentUserProvider)!.unit, WeightUnit.lb);

    await pumpScreen(tester, const EditProfileScreen(), overrides: overrides());
    await pumpFrames(tester, frames: 30);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Birth date'), findsOneWidget);
    expect(find.text('Height'.toUpperCase()), findsOneWidget);
  });

  test('level-ups are computed against the stored snapshot', () async {
    final seenStore = RankSeenStore(await testStore());
    await seenStore.clear();
    final ranks = Ranks.fromJson(ranksJson(benchTier: 4));
    expect(seenStore.levelUps(ranks), isEmpty, reason: 'first visit has no baseline');
    await seenStore.save({'overall': 2, 'bench_press': 3});
    final ups = seenStore.levelUps(ranks);
    expect(ups.map((u) => u.label), ['Overall', 'Bench Press']);
    expect(ups.first.fromIndex, 2);
  });

  test('profile update merges into the signed-in user', () async {
    final container = ProviderContainer(overrides: [authControllerProvider.overrideWith(FakeAuthController.new)]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.notifier).updateProfile(const ProfileUpdate(goal: Goal.bulk));
    expect(container.read(currentUserProvider)!.goal, Goal.bulk);
  });
}
