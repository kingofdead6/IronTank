import 'package:dio/dio.dart';
import 'package:ironrank/core/network/api_client.dart';
import 'package:ironrank/core/network/paginated.dart';
import 'package:ironrank/core/storage/local_store.dart';
import 'package:ironrank/features/exercises/data/exercise.dart';
import 'package:ironrank/features/exercises/data/exercise_repository.dart';
import 'package:ironrank/features/programs/data/program.dart';
import 'package:ironrank/features/programs/data/program_repository.dart';


/// An ApiClient that is never actually called by the fakes below.
final unusedApi = ApiClient(Dio());

// Images are left empty: cached_network_image needs platform plugins.
const bench = Exercise(
  id: 'ex-bench',
  name: 'Barbell Bench Press - Medium Grip',
  primaryMuscles: ['chest'],
  secondaryMuscles: ['shoulders', 'triceps'],
  equipment: 'barbell',
  liftKey: 'bench_press',
  instructions: ['Lie back on a flat bench.', 'Lower the bar to your chest.', 'Press it back up.'],
);
const squat = Exercise(id: 'ex-squat', name: 'Barbell Squat', primaryMuscles: ['quadriceps'], equipment: 'barbell', liftKey: 'squat');
const pullup = Exercise(id: 'ex-pullup', name: 'Pullups', primaryMuscles: ['lats'], equipment: 'body only', isBodyweight: true);
const curl = Exercise(id: 'ex-curl', name: 'Dumbbell Bicep Curl', primaryMuscles: ['biceps'], equipment: 'dumbbell', isCustom: true);

const fakeExercises = [bench, squat, pullup, curl];

class FakeExerciseRepository extends ExerciseRepository {
  FakeExerciseRepository() : super(unusedApi);

  ExerciseFilters? lastFilters;

  @override
  Future<Paginated<Exercise>> list(ExerciseFilters filters, {int page = 1, int limit = ExerciseRepository.pageSize}) async {
    lastFilters = filters;
    final q = filters.query.toLowerCase();
    final items = fakeExercises
        .where((e) => q.isEmpty || e.name.toLowerCase().contains(q))
        .where((e) => filters.muscles.isEmpty || e.primaryMuscles.any(filters.muscles.contains))
        .toList();
    return Paginated(items: items, page: 1, limit: limit, total: items.length, totalPages: 1);
  }

  @override
  Future<Exercise> get(String id) async => fakeExercises.firstWhere((e) => e.id == id);

  @override
  Future<ExerciseFilterOptions> filterOptions() async => const ExerciseFilterOptions(
    muscles: ['chest', 'lats', 'quadriceps', 'biceps'],
    equipment: ['barbell', 'dumbbell', 'body only'],
    categories: ['strength', 'cardio', 'stretching'],
    levels: ['beginner'],
  );

  @override
  Future<({ExerciseBests bests, List<RecordEvent> history})> records(String id) async => (
    bests: ExerciseBests(
      maxWeight: RecordValue(value: 105, weight: 105, reps: 3, achievedAt: DateTime(2026, 10, 1)),
      e1rm: RecordValue(value: 126.7, weight: 100, reps: 8, achievedAt: DateTime(2026, 10, 8)),
      maxVolumeSet: const RecordValue(value: 800, weight: 100, reps: 8),
    ),
    history: [
      RecordEvent(id: 'r1', type: 'e1rm', value: 126.7, previousValue: 116.7, weight: 100, reps: 8, isBaseline: false, achievedAt: DateTime(2026, 10, 8)),
    ],
  );

  @override
  Future<List<ExerciseHistoryPoint>> history(String id, {int limit = 100}) async => [
    for (var i = 0; i < 6; i++)
      ExerciseHistoryPoint(sessionId: 's$i', date: DateTime(2026, 9, 1 + i * 7), bestE1rm: 100.0 + i * 5, volume: 1500),
  ];
}

ProgramExercise _pe(Exercise e, {int sets = 3}) => ProgramExercise(exercise: ExerciseSummary.fromExercise(e), sets: sets, repMin: 5, repMax: 8);

final fiveByFive = Program(
  id: 'tpl-5x5',
  name: '5x5 Strength',
  description: 'Linear progression.',
  weeks: 12,
  isTemplate: true,
  templateKey: 'strength-5x5',
  days: [
    ProgramDay(id: 'd1', name: 'Workout A', exercises: [_pe(squat, sets: 5), _pe(bench, sets: 5)]),
    ProgramDay(id: 'd2', name: 'Workout B', exercises: [_pe(squat, sets: 5), _pe(pullup)]),
  ],
);

final mySplit = Program(
  id: 'mine-1',
  name: 'My Split',
  isActive: true,
  days: [ProgramDay(id: 'd3', name: 'Upper', exercises: [_pe(bench), _pe(pullup), _pe(curl)])],
);

class FakeProgramRepository extends ProgramRepository {
  FakeProgramRepository(LocalStore store) : super(unusedApi, store);

  final created = <Program>[];

  @override
  Future<List<Program>> list(ProgramScope scope) async => scope == ProgramScope.templates ? [fiveByFive] : [mySplit, ...created];

  @override
  Future<Program> get(String id) async => [fiveByFive, mySplit, ...created].firstWhere((p) => p.id == id);

  @override
  Future<Program> create({required String name, required String description, required int weeks, required List<ProgramDay> days}) async {
    final p = Program(id: 'new-${created.length}', name: name, description: description, weeks: weeks, days: days);
    created.add(p);
    return p;
  }

  @override
  Future<ActiveProgram> active() async => ActiveProgram(program: mySplit, nextDay: mySplit.days.first, nextDayIndex: 0);
}
