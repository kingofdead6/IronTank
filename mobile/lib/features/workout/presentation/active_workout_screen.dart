import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/staggered.dart';
import '../../auth/application/auth_controller.dart';
import '../../exercises/presentation/exercise_picker_sheet.dart';
import '../../programs/data/program.dart';
import '../application/active_workout_controller.dart';
import '../data/workout_models.dart';
import 'widgets/exercise_log_card.dart';
import 'widgets/rest_timer_panel.dart';

/// The live logging screen. Closing it (chevron/back) keeps the workout
/// running; it resumes from the Workout tab or the mini bar.
class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  bool _finishing = false;

  ActiveWorkoutController get _ctrl => ref.read(activeWorkoutProvider.notifier);

  Future<void> _addExercises() async {
    final picked = await showExercisePicker(context);
    if (picked == null || picked.isEmpty) return;
    await _ctrl.addExercises(picked.map(ExerciseSummary.fromExercise).toList());
  }

  Future<void> _rename(ActiveWorkout w) async {
    final controller = TextEditingController(text: w.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workout name'),
        content: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name != null) _ctrl.rename(name);
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirm,
    bool destructive = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep going')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirm, style: destructive ? TextStyle(color: context.colors.danger) : null),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _discard() async {
    final ok = await _confirm(
      title: 'Discard workout?',
      message: 'Everything logged in this session will be deleted.',
      confirm: 'Discard',
      destructive: true,
    );
    if (!ok) return;
    await _ctrl.discard();
    if (mounted) context.go(Routes.workout);
  }

  Future<void> _finish(ActiveWorkout w) async {
    if (w.completedSets == 0) {
      await Haptics.warning();
      final discard = await _confirm(
        title: 'No sets completed',
        message: 'Tick off at least one set to save this workout, or discard it.',
        confirm: 'Discard workout',
        destructive: true,
      );
      if (discard) {
        await _ctrl.discard();
        if (mounted) context.go(Routes.workout);
      }
      return;
    }
    final unfinished = w.totalSets - w.completedSets;
    if (unfinished > 0) {
      final ok = await _confirm(
        title: 'Finish workout?',
        message: '${Fmt.count(unfinished, 'unfinished set')} will not be saved.',
        confirm: 'Finish',
      );
      if (!ok) return;
    }

    setState(() => _finishing = true);
    try {
      final result = await _ctrl.finish();
      if (!mounted) return;
      context.go(Routes.workoutSummary, extra: result);
      if (result.newRecords.isNotEmpty) await context.push(Routes.prCelebration, extra: result);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workout = ref.watch(activeWorkoutProvider);
    final unit = ref.watch(currentUserProvider)?.unit ?? WeightUnit.kg;

    if (workout == null) {
      // Finished or discarded elsewhere (e.g. another tab).
      return const Scaffold(
        body: AppBackground(
          child: Center(
            child: EmptyState(icon: Icons.check_circle_outline_rounded, title: 'No workout in progress'),
          ),
        ),
      );
    }

    final restExercise = workout.rest == null
        ? null
        : workout.exercises.where((e) => e.id == workout.rest!.exerciseId).firstOrNull;

    return Scaffold(
      body: AppBackground(
        child: Stack(
          children: [
            CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: AppSizes.timerRingSize,
                  backgroundColor: context.colors.background,
                  leading: IconButton(
                    tooltip: 'Minimise',
                    onPressed: () => context.canPop() ? context.pop() : context.go(Routes.workout),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                  title: GestureDetector(
                    onTap: () => _rename(workout),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: Text(workout.name, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(Icons.edit_rounded, size: AppSizes.iconSm, color: context.colors.textMuted),
                      ],
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.md),
                      child: GradientButton(
                        label: 'Finish',
                        compact: true,
                        expand: false,
                        loading: _finishing,
                        onPressed: () => _finish(workout),
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: SafeArea(
                      child: _SessionHeader(workout: workout, unit: unit),
                    ),
                  ),
                ),
                if (workout.exercises.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.add_circle_outline_rounded,
                      title: 'Empty workout',
                      message: 'Add your first exercise to start logging sets.',
                      actionLabel: 'Add exercises',
                      onAction: _addExercises,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                    sliver: SliverReorderableList(
                      itemCount: workout.exercises.length,
                      onReorderStart: (_) => Haptics.tap(),
                      onReorderItem: _ctrl.moveExercise,
                      proxyDecorator: (child, _, _) => Material(color: Colors.transparent, child: child),
                      itemBuilder: (context, i) {
                        final e = workout.exercises[i];
                        return Padding(
                          key: ValueKey(e.id),
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          // Long-press the card to drag it to a new position.
                          child: ReorderableDelayedDragStartListener(
                            index: i,
                            child: ExerciseLogCard(exercise: e, index: i, unit: unit).staggered(i),
                          ),
                        );
                      },
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.sm,
                    AppSpacing.screen,
                    AppSpacing.huge * 2,
                  ),
                  sliver: SliverList.list(
                    children: [
                      if (workout.exercises.isNotEmpty)
                        GradientButton(
                          label: 'Add exercises',
                          icon: Icons.add_rounded,
                          variant: GradientButtonVariant.outlined,
                          onPressed: _addExercises,
                        ),
                      const SizedBox(height: AppSpacing.md),
                      GradientButton(
                        label: 'Discard workout',
                        icon: Icons.delete_outline_rounded,
                        variant: GradientButtonVariant.ghost,
                        onPressed: _discard,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Floating rest timer.
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.md,
              child: AnimatedSwitcher(
                duration: AppMotion.slow,
                switchInCurve: AppMotion.overshoot,
                switchOutCurve: AppMotion.exit,
                transitionBuilder: (child, a) => SlideTransition(
                  position: Tween(begin: const Offset(0, AppMotion.panelSlide), end: Offset.zero).animate(a),
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: workout.rest == null
                    ? const SizedBox.shrink(key: ValueKey('no-rest'))
                    : RestTimerPanel(
                        key: const ValueKey('rest'),
                        rest: workout.rest!,
                        nextLabel: restExercise == null ? 'Next set' : 'Next: ${restExercise.exercise.name}',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big session clock, pause toggle and live totals.
class _SessionHeader extends ConsumerWidget {
  const _SessionHeader({required this.workout, required this.unit});

  final ActiveWorkout workout;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final now = nowFrom(ref.watch(clockProvider));
    final elapsed = workout.activeDuration(now);
    final ctrl = ref.read(activeWorkoutProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        kToolbarHeight + AppSpacing.sm,
        AppSpacing.screen,
        AppSpacing.md,
      ),
      // Scales down instead of overflowing with large accessibility text sizes.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width - AppSpacing.screen * 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Semantics(
                    label: 'Workout time ${Fmt.duration(elapsed)}${workout.isPaused ? ', paused' : ''}',
                    excludeSemantics: true,
                    child: AnimatedOpacity(
                      duration: AppMotion.medium,
                      opacity: workout.isPaused ? AppOpacity.muted : 1,
                      child: FittedBox(child: Text(Fmt.clock(elapsed), style: context.numbers.timer)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  IconButton.filledTonal(
                    tooltip: workout.isPaused ? 'Resume timer' : 'Pause timer',
                    onPressed: ctrl.togglePause,
                    icon: AnimatedSwitcher(
                      duration: AppMotion.fast,
                      child: Icon(
                        workout.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        key: ValueKey(workout.isPaused),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _Chip(icon: Icons.check_circle_rounded, label: '${workout.completedSets}/${workout.totalSets} sets'),
                  const SizedBox(width: AppSpacing.sm),
                  _Chip(
                    icon: Icons.stacked_bar_chart_rounded,
                    label: '${Units.volume(workout.volumeKg, unit)} ${unit.label}',
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _Chip(icon: Icons.fitness_center_rounded, label: Fmt.count(workout.exercises.length, 'exercise')),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Overall progress through planned sets.
              ClipRRect(
                borderRadius: AppRadii.pillAll,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: workout.totalSets == 0 ? 0 : workout.completedSets / workout.totalSets),
                  duration: AppMotion.slow,
                  curve: AppMotion.emphasized,
                  builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: AppSpacing.xs, color: c.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: GlassCard(
        blur: false,
        borderRadius: AppRadii.mdAll,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: AppSizes.iconSm, color: c.accent),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(label, overflow: TextOverflow.ellipsis, style: context.text.labelMedium),
            ),
          ],
        ),
      ),
    );
  }
}
