import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrank/core/config/app_config.dart';
import 'package:ironrank/core/notifications/notification_service.dart';
import 'package:ironrank/core/storage/local_store.dart';
import 'package:ironrank/core/storage/token_storage.dart';
import 'package:ironrank/features/programs/data/program.dart';
import 'package:ironrank/features/programs/data/program_repository.dart';
import 'package:ironrank/features/workout/application/active_workout_controller.dart';
import 'package:ironrank/features/workout/data/workout_models.dart';
import 'package:ironrank/features/workout/data/workout_repository.dart';

import 'helpers/fakes.dart';
import 'helpers/harness.dart';
import 'helpers/workout_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStore store;
  late FakeWorkoutRepository repo;
  late FakeNotifications notifications;
  late ProviderContainer container;

  ActiveWorkoutController ctrl() => container.read(activeWorkoutProvider.notifier);
  ActiveWorkout workout() => container.read(activeWorkoutProvider)!;

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(testConfig),
      localStoreProvider.overrideWithValue(store),
      tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
      workoutRepositoryProvider.overrideWithValue(repo),
      programRepositoryProvider.overrideWithValue(FakeProgramRepository(store)),
      notificationServiceProvider.overrideWithValue(notifications),
    ],
  );

  setUp(() async {
    store = await testStore();
    await store.clearUserData();
    repo = FakeWorkoutRepository(store);
    notifications = FakeNotifications();
    container = makeContainer();
  });

  tearDown(() => container.dispose());

  final day = fiveByFive.days.first; // squat 5 sets, bench 5 sets

  test('starts from a program day with planned sets and previous values', () async {
    repo.previousValues = {
      squat.id: const [PreviousSet(weightKg: 100, reps: 5)],
    };
    await ctrl().start(day: day, programId: fiveByFive.id);

    final w = workout();
    expect(w.name, 'Workout A');
    expect(w.programId, fiveByFive.id);
    expect(w.exercises.map((e) => e.sets.length), [5, 5]);
    expect(w.exercises.first.previous.single.weightKg, 100);
    expect(w.exercises.first.targetReps, '5–8');
  });

  test('ticking a set uses ghost values, starts rest and schedules the alarm', () async {
    repo.previousValues = {squat.id: const [PreviousSet(weightKg: 100, reps: 5)]};
    await ctrl().start(day: day);
    final ex = workout().exercises.first;

    expect(ctrl().toggleSet(ex.id, ex.sets.first.id), isTrue);
    final set = workout().exercises.first.sets.first;
    expect(set.completed, isTrue);
    expect(set.weightKg, 100);
    expect(set.reps, 5);
    expect(workout().rest, isNotNull);
    expect(workout().rest!.totalSeconds, ex.restSeconds);
    expect(notifications.scheduledAt, isNotNull);
  });

  test('refuses to complete a set with no reps anywhere', () async {
    await ctrl().start(day: day);
    final ex = workout().exercises.first;
    expect(ctrl().toggleSet(ex.id, ex.sets.first.id), isFalse);
    expect(workout().exercises.first.sets.first.completed, isFalse);
  });

  test('records rest taken between sets and adjusts / skips rest', () async {
    await ctrl().start(day: day);
    final ex = workout().exercises.first;
    ctrl()
      ..setWeight(ex.id, ex.sets[0].id, 100)
      ..setReps(ex.id, ex.sets[0].id, 5)
      ..setReps(ex.id, ex.sets[1].id, 5);
    ctrl().toggleSet(ex.id, ex.sets[0].id);

    final before = workout().rest!.endsAt;
    ctrl().adjustRest(15);
    expect(workout().rest!.endsAt.difference(before).inSeconds, 15);

    ctrl().toggleSet(ex.id, ex.sets[1].id);
    expect(workout().exercises.first.sets[0].restTaken, isNotNull);

    ctrl().skipRest();
    expect(workout().rest, isNull);
    expect(notifications.cancels, greaterThan(0));
  });

  test('adds sets by duplicating the last one and removes sets', () async {
    await ctrl().start(day: day);
    final ex = workout().exercises.first;
    ctrl()
      ..setWeight(ex.id, ex.sets.last.id, 80)
      ..setReps(ex.id, ex.sets.last.id, 8)
      ..addSet(ex.id);
    final sets = workout().exercises.first.sets;
    expect(sets.length, 6);
    expect(sets.last.weightKg, 80);
    expect(sets.last.completed, isFalse);

    ctrl().removeSet(ex.id, sets.last.id);
    expect(workout().exercises.first.sets.length, 5);
  });

  test('finishing sends only completed sets and clears the workout', () async {
    await ctrl().start(day: day);
    final squatEx = workout().exercises.first;
    ctrl()
      ..setWeight(squatEx.id, squatEx.sets[0].id, 100)
      ..setReps(squatEx.id, squatEx.sets[0].id, 5);
    ctrl().toggleSet(squatEx.id, squatEx.sets[0].id);

    final result = await ctrl().finish();
    expect(container.read(activeWorkoutProvider), isNull);
    expect(repo.local, isNull);
    expect(result.synced, isTrue);
    expect(result.caloriesKcal, 321);

    final body = repo.saved.single;
    final exercises = body['exercises'] as List<dynamic>;
    expect(exercises, hasLength(1)); // bench had no completed sets
    final sets = (exercises.single as Map<String, dynamic>)['sets'] as List<dynamic>;
    expect(sets, hasLength(1));
    expect(sets.single, containsPair('weight', 100.0));
    expect(body['clientId'], isNotEmpty);
    expect(body['endedAt'], isNotNull);
  });

  test('finishing offline queues the workout for later sync', () async {
    await ctrl().start(day: day);
    final ex = workout().exercises.first;
    ctrl().setReps(ex.id, ex.sets[0].id, 5);
    ctrl().toggleSet(ex.id, ex.sets[0].id);

    repo.offline = true;
    final result = await ctrl().finish();
    expect(result.synced, isFalse);
    expect(repo.pendingCount, 1);

    repo.offline = false;
    expect(await ctrl().syncPending(), 1);
    expect(repo.pendingCount, 0);
    expect(repo.saved, hasLength(1));
  });

  test('survives an app restart: state is restored from local storage', () async {
    await ctrl().start(day: day);
    final ex = workout().exercises.first;
    ctrl().setReps(ex.id, ex.sets[0].id, 7);
    final clientId = workout().clientId;

    container.dispose();
    container = makeContainer();
    final restored = container.read(activeWorkoutProvider);
    expect(restored, isNotNull);
    expect(restored!.clientId, clientId);
    expect(restored.exercises.first.sets.first.reps, 7);
  });

  test('the real repository round-trips the active workout through Hive', () async {
    final real = WorkoutRepository(unusedApi, await hiveTestStore());
    final w = ActiveWorkout(
      clientId: 'abc-123',
      name: 'Legs',
      startedAt: DateTime(2026, 10, 14, 18),
      exercises: exercisesFromDay(day),
      rest: RestTimer(endsAt: DateTime(2026, 10, 14, 18, 5), totalSeconds: 90, exerciseId: 'x'),
    );
    await real.saveLocal(w);
    final back = real.loadLocal()!;
    expect(back.clientId, 'abc-123');
    expect(back.exercises.map((e) => e.sets.length), [5, 5]);
    expect(back.rest!.totalSeconds, 90);
    await real.clearLocal();
    expect(real.loadLocal(), isNull);
  });

  test('pausing excludes paused time from the active duration', () async {
    await ctrl().start(name: 'Quick');
    ctrl().togglePause();
    final paused = workout();
    expect(paused.isPaused, isTrue);
    final later = paused.pausedAt!.add(const Duration(minutes: 10));
    // While paused, the clock doesn't advance.
    expect(paused.activeDuration(later), paused.activeDuration(paused.pausedAt!));
    ctrl().togglePause();
    expect(workout().isPaused, isFalse);
  });

  test('swap keeps set count but clears values; remove + insert restores', () async {
    await ctrl().start(day: day);
    final ex = workout().exercises.first;
    ctrl().setReps(ex.id, ex.sets[0].id, 5);
    await ctrl().swapExercise(ex.id, ExerciseSummary.fromExercise(pullup));
    final swapped = workout().exercises.first;
    expect(swapped.exercise.id, pullup.id);
    expect(swapped.sets.length, 5);
    expect(swapped.sets.first.reps, isNull);

    ctrl().removeExercise(swapped.id);
    expect(workout().exercises, hasLength(1));
    ctrl().insertExercise(0, swapped);
    expect(workout().exercises.first.id, swapped.id);
  });
}
