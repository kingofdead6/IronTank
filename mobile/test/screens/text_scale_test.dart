import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrank/core/notifications/notification_service.dart';
import 'package:ironrank/features/auth/application/auth_controller.dart';
import 'package:ironrank/features/auth/presentation/login_screen.dart';
import 'package:ironrank/features/auth/presentation/profile_setup_screen.dart';
import 'package:ironrank/features/calories/data/calorie_repository.dart';
import 'package:ironrank/features/calories/presentation/calories_screen.dart';
import 'package:ironrank/features/exercises/data/exercise_repository.dart';
import 'package:ironrank/features/exercises/presentation/exercise_detail_screen.dart';
import 'package:ironrank/features/exercises/presentation/exercise_library_screen.dart';
import 'package:ironrank/features/home/presentation/home_screen.dart';
import 'package:ironrank/features/profile/presentation/profile_screen.dart';
import 'package:ironrank/features/programs/data/program_repository.dart';
import 'package:ironrank/features/programs/presentation/program_builder_screen.dart';
import 'package:ironrank/features/progress/data/progress_repository.dart';
import 'package:ironrank/features/progress/presentation/progress_screen.dart';
import 'package:ironrank/features/ranks/presentation/ranks_screen.dart';
import 'package:ironrank/features/workout/application/active_workout_controller.dart';
import 'package:ironrank/features/workout/data/workout_models.dart';
import 'package:ironrank/features/workout/data/workout_repository.dart';
import 'package:ironrank/features/workout/presentation/active_workout_screen.dart';
import 'package:ironrank/features/workout/presentation/workout_hub_screen.dart';
import 'package:ironrank/features/workout/presentation/workout_summary_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';
import '../helpers/progress_fakes.dart';
import '../helpers/workout_fakes.dart';

/// Every main screen must lay out without overflow at a large accessibility
/// text size (any RenderFlex overflow fails the test).
void main() {
  const scale = 1.6;

  Future<List<dynamic>> overrides() async {
    final store = await testStore();
    return [
      authControllerProvider.overrideWith(FakeAuthController.new),
      progressRepositoryProvider.overrideWithValue(FakeProgressRepository(store)),
      calorieRepositoryProvider.overrideWithValue(FakeCalorieRepository()),
      exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository()),
      programRepositoryProvider.overrideWithValue(FakeProgramRepository(store)),
      workoutRepositoryProvider.overrideWithValue(
        FakeWorkoutRepository(store)..previousValues = {squat.id: const [PreviousSet(weightKg: 100, reps: 5)]},
      ),
      notificationServiceProvider.overrideWithValue(FakeNotifications()),
    ];
  }

  final screens = <String, Widget>{
    'login': const LoginScreen(),
    'profile setup': const ProfileSetupScreen(),
    'home': const HomeScreen(),
    'exercise library': const ExerciseLibraryScreen(),
    'exercise detail': const ExerciseDetailScreen(exerciseId: 'ex-bench', initial: bench),
    'program builder': const ProgramBuilderScreen(programId: 'mine-1'),
    'workout hub': const WorkoutHubScreen(),
    'progress': const ProgressScreen(),
    'ranks': const RanksScreen(),
    'calories': const CaloriesScreen(),
    'profile': const ProfileScreen(),
    'summary': const WorkoutSummaryScreen(
      result: WorkoutResult(name: 'Push', duration: Duration(minutes: 58), volumeKg: 8450, completedSets: 18, exerciseCount: 5, caloriesKcal: 412),
    ),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} at ${scale}x text', (tester) async {
      await pumpScreen(tester, entry.value, overrides: await overrides(), textScale: scale);
      await pumpFrames(tester, frames: 40);
      await snapshot(find.byType(MaterialApp), 'scale_${entry.key.replaceAll(' ', '_')}');
    });
  }

  testWidgets('active workout at ${scale}x text', (tester) async {
    await pumpScreen(tester, const ActiveWorkoutScreen(), overrides: await overrides(), textScale: scale);
    final container = ProviderScope.containerOf(tester.element(find.byType(ActiveWorkoutScreen)));
    await tester.runAsync(() => container.read(activeWorkoutProvider.notifier).start(day: fiveByFive.days.first));
    await pumpFrames(tester, frames: 40);
    await tester.tap(find.bySemanticsLabel('Complete set').first);
    await pumpFrames(tester, frames: 20);
    await snapshot(find.byType(MaterialApp), 'scale_active_workout');
    container.read(activeWorkoutProvider.notifier).skipRest();
    await pumpFrames(tester);
  });
}
