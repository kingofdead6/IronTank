import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/calories/presentation/calories_screen.dart';
import '../../features/exercises/data/exercise.dart';
import '../../features/exercises/presentation/custom_exercise_screen.dart';
import '../../features/exercises/presentation/exercise_detail_screen.dart';
import '../../features/exercises/presentation/exercise_library_screen.dart';
import '../../features/programs/presentation/program_builder_screen.dart';
import '../../features/programs/presentation/program_detail_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/programs/presentation/programs_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/ranks/presentation/ranks_screen.dart';
import '../../features/workout/data/workout_models.dart';
import '../../features/workout/presentation/active_workout_screen.dart';
import '../../features/workout/presentation/pr_celebration_screen.dart';
import '../../features/workout/presentation/workout_detail_screen.dart';
import '../../features/workout/presentation/workout_hub_screen.dart';
import '../../features/workout/presentation/workout_summary_screen.dart';
import 'routes.dart';
import 'transitions.dart';

/// Bottom-nav branches between Home and Profile (Exercises, Workout, Progress).
List<StatefulShellBranch> tabBranches() => [
  StatefulShellBranch(
    routes: [GoRoute(path: Routes.exercises, pageBuilder: (c, s) => fadePage(s, const ExerciseLibraryScreen()))],
  ),
  StatefulShellBranch(
    routes: [GoRoute(path: Routes.workout, pageBuilder: (c, s) => fadePage(s, const WorkoutHubScreen()))],
  ),
  StatefulShellBranch(
    routes: [GoRoute(path: Routes.progress, pageBuilder: (c, s) => fadePage(s, const ProgressScreen()))],
  ),
];

/// Full-screen routes pushed above the shell (bottom nav hidden).
/// Literal segments ("new", "builder") must precede their ":id" siblings.
List<RouteBase> featureRoutes(GlobalKey<NavigatorState> rootKey) => [
  GoRoute(
    path: Routes.exerciseNew,
    parentNavigatorKey: rootKey,
    pageBuilder: (c, s) => fadeSlidePage(s, const CustomExerciseScreen(), fullscreenDialog: true),
  ),
  GoRoute(
    path: '/exercises/:id',
    parentNavigatorKey: rootKey,
    pageBuilder: (c, s) => fadeSlidePage(
      s,
      ExerciseDetailScreen(exerciseId: s.pathParameters['id']!, initial: s.extra is Exercise ? s.extra! as Exercise : null),
    ),
  ),
  GoRoute(
    path: Routes.programs,
    parentNavigatorKey: rootKey,
    pageBuilder: (c, s) => fadeSlidePage(s, const ProgramsScreen()),
  ),
  GoRoute(
    path: Routes.programBuilderNew,
    parentNavigatorKey: rootKey,
    pageBuilder: (c, s) => fadeSlidePage(
      s,
      ProgramBuilderScreen(programId: s.uri.queryParameters['id']),
      fullscreenDialog: true,
    ),
  ),
  GoRoute(
    path: Routes.activeWorkout,
    parentNavigatorKey: rootKey,
    pageBuilder: (c, s) => fadeSlidePage(s, const ActiveWorkoutScreen(), fullscreenDialog: true),
  ),
  GoRoute(
    path: Routes.workoutSummary,
    parentNavigatorKey: rootKey,
    redirect: (c, s) => s.extra is WorkoutResult ? null : Routes.workout,
    pageBuilder: (c, s) => fadePage(s, WorkoutSummaryScreen(result: s.extra! as WorkoutResult)),
  ),
  GoRoute(
    path: Routes.prCelebration,
    parentNavigatorKey: rootKey,
    redirect: (c, s) => s.extra is WorkoutResult ? null : Routes.workout,
    pageBuilder: (c, s) => fadePage(s, PrCelebrationScreen(result: s.extra! as WorkoutResult)),
  ),
  GoRoute(
    path: '/workouts/:id',
    parentNavigatorKey: rootKey,
    pageBuilder: (c, s) => fadeSlidePage(s, WorkoutDetailScreen(workoutId: s.pathParameters['id']!)),
  ),
  GoRoute(
    path: Routes.ranks,
    parentNavigatorKey: rootKey,
    pageBuilder: (c, s) => fadeSlidePage(s, const RanksScreen()),
  ),
  GoRoute(
    path: Routes.calories,
    parentNavigatorKey: rootKey,
    pageBuilder: (c, s) => fadeSlidePage(s, const CaloriesScreen()),
  ),
  GoRoute(
    path: Routes.editProfile,
    parentNavigatorKey: rootKey,
    pageBuilder: (c, s) => fadeSlidePage(s, const EditProfileScreen(), fullscreenDialog: true),
  ),
  GoRoute(
    path: '/programs/:id',
    parentNavigatorKey: rootKey,
    pageBuilder: (c, s) => fadeSlidePage(s, ProgramDetailScreen(programId: s.pathParameters['id']!)),
  ),
];
