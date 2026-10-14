import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../exercises/data/exercise.dart';
import '../data/program.dart';
import '../data/program_repository.dart';
import 'program_providers.dart';

/// Editable program draft held by the builder.
class ProgramDraft {
  const ProgramDraft({
    this.id,
    this.name = '',
    this.description = '',
    this.weeks = 8,
    this.days = const [ProgramDay(name: 'Day 1')],
    this.dirty = false,
  });

  factory ProgramDraft.fromProgram(Program p) => ProgramDraft(
    id: p.isTemplate ? null : p.id,
    name: p.name,
    description: p.description,
    weeks: p.weeks,
    days: p.days.isEmpty ? const [ProgramDay(name: 'Day 1')] : p.days,
  );

  /// null when creating a new program.
  final String? id;
  final String name;
  final String description;
  final int weeks;
  final List<ProgramDay> days;

  /// True once the user changed something (used to confirm discarding).
  final bool dirty;

  bool get isNew => id == null;
  bool get canSave => name.trim().isNotEmpty && days.any((d) => d.exercises.isNotEmpty);

  ProgramDraft copyWith({String? name, String? description, int? weeks, List<ProgramDay>? days}) => ProgramDraft(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    weeks: weeks ?? this.weeks,
    days: days ?? this.days,
    dirty: true,
  );
}

/// Builder state machine. The family argument is the program id to edit
/// (empty string = new program).
class ProgramBuilderController extends AsyncNotifier<ProgramDraft> {
  ProgramBuilderController(this.programId);

  final String programId;

  static const maxDays = 14;

  ProgramRepository get _repo => ref.read(programRepositoryProvider);

  @override
  Future<ProgramDraft> build() async {
    if (programId.isEmpty) return const ProgramDraft();
    return ProgramDraft.fromProgram(await _repo.get(programId));
  }

  ProgramDraft get _draft => state.requireValue;

  void _set(ProgramDraft draft) => state = AsyncData(draft);

  void _updateDay(int day, ProgramDay Function(ProgramDay) change) {
    final days = [..._draft.days];
    days[day] = change(days[day]);
    _set(_draft.copyWith(days: days));
  }

  void setName(String v) => _set(_draft.copyWith(name: v));
  void setDescription(String v) => _set(_draft.copyWith(description: v));
  void setWeeks(int v) => _set(_draft.copyWith(weeks: v));

  /// Adds a day and returns its index.
  int addDay() {
    if (_draft.days.length >= maxDays) return _draft.days.length - 1;
    _set(_draft.copyWith(days: [..._draft.days, ProgramDay(name: 'Day ${_draft.days.length + 1}')]));
    return _draft.days.length - 1;
  }

  void renameDay(int day, String name) => _updateDay(day, (d) => d.copyWith(name: name));

  void removeDay(int day) {
    if (_draft.days.length <= 1) return;
    _set(_draft.copyWith(days: [..._draft.days]..removeAt(day)));
  }

  void duplicateDay(int day) {
    if (_draft.days.length >= maxDays) return;
    final src = _draft.days[day];
    final copy = ProgramDay(name: '${src.name} (copy)', exercises: src.exercises.map((e) => e.copyWith()).toList());
    _set(_draft.copyWith(days: [..._draft.days]..insert(day + 1, copy)));
  }

  /// [newIndex] is the final position, as reported by onReorderItem.
  void reorderDays(int oldIndex, int newIndex) {
    final days = [..._draft.days];
    days.insert(newIndex, days.removeAt(oldIndex));
    _set(_draft.copyWith(days: days));
  }

  void addExercises(int day, List<Exercise> exercises) => _updateDay(
    day,
    (d) => d.copyWith(
      exercises: [
        ...d.exercises,
        for (final e in exercises)
          ProgramExercise(
            exercise: ExerciseSummary.fromExercise(e),
            // Sensible defaults: compound barbell work gets more rest.
            restSeconds: e.equipment == 'barbell' ? 150 : 90,
            repMin: e.category == 'strength' ? 8 : 10,
            repMax: e.category == 'strength' ? 12 : 15,
          ),
      ],
    ),
  );

  void updateExercise(int day, int index, ProgramExercise updated) =>
      _updateDay(day, (d) => d.copyWith(exercises: [...d.exercises]..[index] = updated));

  void removeExercise(int day, int index) => _updateDay(day, (d) => d.copyWith(exercises: [...d.exercises]..removeAt(index)));

  void insertExercise(int day, int index, ProgramExercise exercise) =>
      _updateDay(day, (d) => d.copyWith(exercises: [...d.exercises]..insert(index, exercise)));

  /// [newIndex] is the final position, as reported by onReorderItem.
  void reorderExercise(int day, int oldIndex, int newIndex) => _updateDay(day, (d) {
    final list = [...d.exercises];
    list.insert(newIndex, list.removeAt(oldIndex));
    return d.copyWith(exercises: list);
  });

  /// Persists the draft (empty days are dropped) and returns the saved program.
  Future<Program> save() async {
    final d = _draft;
    final days = d.days.where((day) => day.exercises.isNotEmpty).toList();
    final saved = d.isNew
        ? await _repo.create(name: d.name.trim(), description: d.description.trim(), weeks: d.weeks, days: days)
        : await _repo.update(d.id!, name: d.name.trim(), description: d.description.trim(), weeks: d.weeks, days: days);
    invalidatePrograms(ref.invalidate);
    return saved;
  }
}

final programBuilderProvider = AsyncNotifierProvider.autoDispose.family<ProgramBuilderController, ProgramDraft, String>(
  ProgramBuilderController.new,
);
