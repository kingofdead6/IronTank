/// Route paths in one place so navigation calls never use string literals.
abstract final class Routes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const setup = '/setup';

  // Bottom-nav tabs.
  static const home = '/home';
  static const exercises = '/exercises';
  static const workout = '/workout';
  static const progress = '/progress';
  static const profile = '/profile';

  // Exercises.
  static String exercise(String id) => '/exercises/$id';
  static const exerciseNew = '/exercises/new';

  // Programs.
  static const programs = '/programs';
  static String program(String id) => '/programs/$id';
  static const programBuilderNew = '/programs/builder';
  static String programBuilderEdit(String id) => '$programBuilderNew?id=$id';

  // Workout flow.
  static const activeWorkout = '/active-workout';
  static const workoutSummary = '/workout-summary';
  static const prCelebration = '/pr-celebration';
  static String workoutDetail(String id) => '/workouts/$id';

  // Other screens.
  static const ranks = '/ranks';
  static const calories = '/calories';
  static const editProfile = '/profile/edit';

  /// Routes reachable without signing in.
  static const public = {splash, onboarding, login, register};
}
