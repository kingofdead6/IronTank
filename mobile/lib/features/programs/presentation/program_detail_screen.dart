import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/staggered.dart';
import '../../exercises/presentation/widgets/exercise_image.dart';
import '../application/program_providers.dart';
import '../data/program.dart';
import '../data/program_repository.dart';

class ProgramDetailScreen extends ConsumerStatefulWidget {
  const ProgramDetailScreen({super.key, required this.programId});

  final String programId;

  @override
  ConsumerState<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends ConsumerState<ProgramDetailScreen> {
  bool _busy = false;

  ProgramRepository get _repo => ref.read(programRepositoryProvider);

  /// Runs a mutation with a busy flag and error snackbar.
  Future<T?> _run<T>(Future<T> Function() action) async {
    setState(() => _busy = true);
    try {
      return await action();
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activate(Program p) async {
    final activated = await _run(() => _repo.activate(p.id));
    if (activated == null || !mounted) return;
    invalidatePrograms(ref.invalidate);
    await Haptics.celebrate();
    if (!mounted) return;
    showAppSnack(context, '${activated.name} is now your active program');
    // Activating a template creates a personal copy; show that copy.
    if (activated.id != p.id) context.pushReplacement(Routes.program(activated.id));
  }

  Future<void> _deactivate() async {
    await _run(_repo.deactivate);
    invalidatePrograms(ref.invalidate);
  }

  Future<void> _clone(Program p) async {
    final copy = await _run(() => _repo.clone(p.id));
    if (copy == null || !mounted) return;
    invalidatePrograms(ref.invalidate);
    context.pushReplacement(Routes.program(copy.id));
  }

  Future<void> _delete(Program p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete program?'),
        content: Text('"${p.name}" will be deleted. Your workout history is kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => _repo.delete(p.id));
    invalidatePrograms(ref.invalidate);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(programDetailProvider(widget.programId));
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        actions: [
          if (async.value case final p? when !p.isTemplate)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) => switch (v) {
                'edit' => context.push(Routes.programBuilderEdit(p.id)),
                'copy' => _clone(p),
                _ => _delete(p),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'copy', child: Text('Duplicate')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: async.when(
            loading: () => const SkeletonList(count: 4, itemHeight: AppSizes.chartHeightSm),
            error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(programDetailProvider(widget.programId))),
            data: (p) => _content(p),
          ),
        ),
      ),
    );
  }

  Widget _content(Program p) {
    final c = context.colors;
    final children = <Widget>[
      Text(p.name, style: context.text.displaySmall),
      if (p.description.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(p.description, style: context.text.bodyLarge?.copyWith(color: c.textSecondary)),
      ],
      const SizedBox(height: AppSpacing.lg),
      Row(
        children: [
          _Meta(icon: Icons.calendar_month_rounded, label: Fmt.count(p.weeks, 'week')),
          _Meta(icon: Icons.view_day_rounded, label: Fmt.count(p.days.length, 'day')),
          _Meta(icon: Icons.fitness_center_rounded, label: Fmt.count(p.exerciseCount, 'exercise')),
        ],
      ),
      const SizedBox(height: AppSpacing.xl),
      for (var i = 0; i < p.days.length; i++) ...[
        _DayCard(index: i, day: p.days[i]),
        const SizedBox(height: AppSpacing.md),
      ],
    ];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xl),
            children: [for (var i = 0; i < children.length; i++) children[i].staggered(i)],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.lg),
          child: p.isActive
              ? GradientButton(
                  label: 'Active program · Stop',
                  icon: Icons.check_circle_rounded,
                  variant: GradientButtonVariant.outlined,
                  loading: _busy,
                  onPressed: _deactivate,
                )
              : Row(
                  children: [
                    if (p.isTemplate) ...[
                      Expanded(
                        child: GradientButton(
                          label: 'Copy',
                          icon: Icons.copy_rounded,
                          variant: GradientButtonVariant.outlined,
                          onPressed: _busy ? null : () => _clone(p),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      flex: 2,
                      child: GradientButton(
                        label: 'Activate',
                        icon: Icons.bolt_rounded,
                        loading: _busy,
                        onPressed: () => _activate(p),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      children: [
        Icon(icon, size: AppSizes.iconSm, color: context.colors.accent),
        const SizedBox(width: AppSpacing.xs),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: context.text.labelMedium)),
      ],
    ),
  );
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.index, required this.day});

  final int index;
  final ProgramDay day;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSizes.iconLg,
                height: AppSizes.iconLg,
                alignment: Alignment.center,
                decoration: BoxDecoration(gradient: c.accentGradient, shape: BoxShape.circle),
                child: Text('${index + 1}', style: context.text.labelMedium?.copyWith(color: c.onAccent)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(day.name, style: context.text.titleMedium)),
              Text('${day.totalSets} sets', style: context.text.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final e in day.exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  ExerciseThumb(url: e.exercise.image, size: AppSizes.avatar),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(e.exercise.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyLarge)),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(e.prescription, style: context.numbers.small),
                      Text(
                        '${e.restSeconds}s rest${e.targetRpe == null ? '' : ' · RPE ${e.targetRpe!.toStringAsFixed(e.targetRpe! % 1 == 0 ? 0 : 1)}'}',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
