import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrank/core/widgets/gradient_button.dart';
import 'package:ironrank/features/exercises/data/exercise_repository.dart';
import 'package:ironrank/features/exercises/presentation/exercise_detail_screen.dart';
import 'package:ironrank/features/exercises/presentation/exercise_library_screen.dart';
import 'package:ironrank/features/exercises/presentation/widgets/exercise_card.dart';
import 'package:ironrank/features/programs/data/program_repository.dart';
import 'package:ironrank/features/programs/presentation/program_builder_screen.dart';
import 'package:ironrank/features/programs/presentation/program_detail_screen.dart';
import 'package:ironrank/features/programs/presentation/programs_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';

void main() {
  late FakeExerciseRepository exercises;
  late FakeProgramRepository programs;

  setUp(() async {
    exercises = FakeExerciseRepository();
    programs = FakeProgramRepository(await testStore());
  });

  List<dynamic> overrides() => [
    exerciseRepositoryProvider.overrideWithValue(exercises),
    programRepositoryProvider.overrideWithValue(programs),
  ];

  group('exercise library', () {
    testWidgets('shows the grid and filters by search and muscle chips', (tester) async {
      await pumpScreen(tester, const ExerciseLibraryScreen(), overrides: overrides());
      await pumpFrames(tester);
      expect(find.byType(ExerciseCard), findsNWidgets(4));
      expect(find.text('4 exercises'), findsOneWidget);
      await snapshot(find.byType(ExerciseLibraryScreen), 'library');

      await tester.enterText(find.byType(TextField), 'squat');
      await pumpFrames(tester);
      expect(find.byType(ExerciseCard), findsOneWidget);
      expect(exercises.lastFilters?.query, 'squat');

      await tester.enterText(find.byType(TextField), '');
      await pumpFrames(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Lats'));
      await pumpFrames(tester);
      expect(exercises.lastFilters?.muscles, {'lats'});
      expect(find.byType(ExerciseCard), findsOneWidget);
    });

    testWidgets('detail shows records, trend chart and instructions', (tester) async {
      await pumpScreen(tester, const ExerciseDetailScreen(exerciseId: 'ex-bench', initial: bench), overrides: overrides());
      await pumpFrames(tester, frames: 40);
      expect(find.text('Barbell Bench Press - Medium Grip'), findsOneWidget);
      expect(find.text('My records'), findsOneWidget);
      expect(find.text('EST. 1RM'), findsOneWidget);
      await snapshot(find.byType(ExerciseDetailScreen), 'exercise_detail');

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await pumpFrames(tester);
      expect(find.text('Estimated 1RM'), findsOneWidget);
      expect(find.text('How to do it'), findsOneWidget);
    });
  });

  group('programs', () {
    testWidgets('lists my programs and templates', (tester) async {
      await pumpScreen(tester, const ProgramsScreen(), overrides: overrides());
      await pumpFrames(tester);
      expect(find.text('My Split'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      await snapshot(find.byType(ProgramsScreen), 'programs');

      await tester.tap(find.text('Templates'));
      await pumpFrames(tester);
      expect(find.text('5x5 Strength'), findsOneWidget);
    });

    testWidgets('detail shows days and the activate action', (tester) async {
      await pumpScreen(tester, const ProgramDetailScreen(programId: 'tpl-5x5'), overrides: overrides());
      await pumpFrames(tester);
      expect(find.text('Workout A'), findsOneWidget);
      expect(find.text('5 × 5–8'), findsWidgets);
      expect(find.widgetWithText(GradientButton, 'Activate'), findsOneWidget);
      await snapshot(find.byType(ProgramDetailScreen), 'program_detail');
    });

    testWidgets('builder edits days and saves', (tester) async {
      await pumpScreen(tester, const ProgramBuilderScreen(programId: 'mine-1'), overrides: overrides());
      await pumpFrames(tester);
      expect(find.text('Upper'), findsWidgets);
      expect(find.text('Dumbbell Bicep Curl'), findsOneWidget);
      await snapshot(find.byType(ProgramBuilderScreen), 'program_builder');

      // Add a day, which becomes selected and is empty.
      await tester.tap(find.widgetWithText(ActionChip, 'Day'));
      await pumpFrames(tester);
      expect(find.text('No exercises on Day 2'), findsOneWidget);

      // Remove the curl from day 1 by swiping.
      await tester.tap(find.textContaining('Upper ·'));
      await pumpFrames(tester);
      await tester.drag(find.text('Dumbbell Bicep Curl'), const Offset(-500, 0));
      await pumpFrames(tester);
      expect(find.text('Dumbbell Bicep Curl'), findsNothing);
    });

    testWidgets('new program cannot be saved until it has a name and exercises', (tester) async {
      await pumpScreen(tester, const ProgramBuilderScreen(), overrides: overrides());
      await pumpFrames(tester);
      final save = tester.widget<GradientButton>(find.widgetWithText(GradientButton, 'Save program'));
      expect(save.onPressed, isNull);
    });
  });
}
