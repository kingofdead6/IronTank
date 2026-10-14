import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrank/core/notifications/notification_service.dart';
import 'package:ironrank/core/widgets/gradient_button.dart';
import 'package:ironrank/features/programs/data/program_repository.dart';
import 'package:ironrank/features/workout/application/active_workout_controller.dart';
import 'package:ironrank/features/workout/data/workout_models.dart';
import 'package:ironrank/features/workout/data/workout_repository.dart';
import 'package:ironrank/features/workout/presentation/active_workout_screen.dart';
import 'package:ironrank/features/workout/presentation/pr_celebration_screen.dart';
import 'package:ironrank/features/workout/presentation/widgets/rest_timer_panel.dart';
import 'package:ironrank/features/workout/presentation/workout_hub_screen.dart';
import 'package:ironrank/features/workout/presentation/workout_summary_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';
import '../helpers/workout_fakes.dart';

void main() {
  late FakeWorkoutRepository workouts;
  late FakeProgramRepository programs;

  setUp(() async {
    final store = await testStore();
    await store.clearUserData();
    workouts = FakeWorkoutRepository(store)..previousValues = {squat.id: const [PreviousSet(weightKg: 100, reps: 5)]};
    programs = FakeProgramRepository(store);
  });

  List<dynamic> overrides() => [
    workoutRepositoryProvider.overrideWithValue(workouts),
    programRepositoryProvider.overrideWithValue(programs),
    notificationServiceProvider.overrideWithValue(FakeNotifications()),
  ];

  const result = WorkoutResult(
    name: 'Push',
    duration: Duration(minutes: 58),
    volumeKg: 8450,
    completedSets: 18,
    exerciseCount: 5,
    caloriesKcal: 412,
    sessionId: 's1',
    newRecords: [
      NewRecord(exerciseId: 'ex-bench', exerciseName: 'Bench Press', type: 'e1rm', value: 120, previousValue: 115, weight: 105, reps: 4),
      NewRecord(exerciseId: 'ex-bench', exerciseName: 'Bench Press', type: 'maxRepsAtWeight', value: 8, previousValue: 6, weight: 100, reps: 8),
    ],
    rankChanges: [RankChange(key: 'bench_press', name: 'Bench Press', from: 'Gold', to: 'Platinum', up: true)],
  );

  testWidgets('hub shows the next program day and history', (tester) async {
    await pumpScreen(tester, const WorkoutHubScreen(), overrides: overrides());
    await pumpFrames(tester);
    expect(find.text('Upper'), findsOneWidget); // active program's next day
    expect(find.widgetWithText(GradientButton, 'Start Upper'), findsOneWidget);
    expect(find.text('No workouts yet'), findsOneWidget);
    await snapshot(find.byType(WorkoutHubScreen), 'workout_hub');
  });

  testWidgets('active workout logs a set and shows the rest timer', (tester) async {
    await pumpScreen(tester, const ActiveWorkoutScreen(), overrides: overrides());
    final container = ProviderScope.containerOf(tester.element(find.byType(ActiveWorkoutScreen)));
    await tester.runAsync(() => container.read(activeWorkoutProvider.notifier).start(day: fiveByFive.days.first));
    await pumpFrames(tester);

    expect(find.text('Barbell Squat'), findsOneWidget);
    expect(find.text('100 × 5'), findsWidgets); // previous-session ghost
    await snapshot(find.byType(ActiveWorkoutScreen), 'active_workout');

    // Tick the first squat set: ghost values fill it and the rest timer appears.
    await tester.tap(find.bySemanticsLabel('Complete set').first);
    await pumpFrames(tester);
    expect(container.read(activeWorkoutProvider)!.completedSets, 1);
    expect(find.byType(RestTimerPanel), findsOneWidget);
    await snapshot(find.byType(ActiveWorkoutScreen), 'active_workout_rest');

    container.read(activeWorkoutProvider.notifier).skipRest();
    await pumpFrames(tester);
    expect(find.byType(RestTimerPanel), findsNothing);
  });

  testWidgets('summary shows stats, PRs and rank-ups', (tester) async {
    await pumpScreen(tester, const WorkoutSummaryScreen(result: result), overrides: overrides());
    await pumpFrames(tester, frames: 40);
    expect(find.text('Workout complete'), findsOneWidget);
    expect(find.text('New personal records'), findsOneWidget);
    await snapshot(find.byType(WorkoutSummaryScreen), 'workout_summary');
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await pumpFrames(tester);
    expect(find.text('Gold → Platinum'), findsOneWidget);
  });

  testWidgets('PR celebration plays and pages through records', (tester) async {
    await pumpScreen(tester, const PrCelebrationScreen(result: result), overrides: overrides());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200))); // let Lottie load
    await pumpFrames(tester, frames: 40);
    expect(find.text('2 NEW PERSONAL RECORDS'), findsOneWidget);
    expect(find.text('Estimated 1RM'.toUpperCase()), findsOneWidget);
    await snapshot(find.byType(PrCelebrationScreen), 'pr_celebration');

    await tester.tap(find.widgetWithText(GradientButton, 'Next record'));
    await pumpFrames(tester, frames: 40);
    expect(find.text('MOST REPS'), findsOneWidget);
    expect(find.widgetWithText(GradientButton, 'Continue'), findsOneWidget);
  });
}
