import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/time_zone.dart';
import '../../../core/widgets/animated_counter.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/staggered.dart';
import '../../../core/widgets/timer_ring.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/user.dart';
import '../application/calorie_providers.dart';
import '../data/calorie_models.dart';
import '../data/calorie_repository.dart';

/// Daily calories: ring (consumed vs target), macros, burned, entries, quick add.
class CaloriesScreen extends ConsumerStatefulWidget {
  const CaloriesScreen({super.key});

  @override
  ConsumerState<CaloriesScreen> createState() => _CaloriesScreenState();
}

class _CaloriesScreenState extends ConsumerState<CaloriesScreen> {
  DateTime _day = DateTime.now();

  String get _key => Fmt.isoDay(_day);
  bool get _isToday => _key == todayKey();

  void _shiftDay(int delta) => setState(() => _day = _day.add(Duration(days: delta)));

  Future<void> _quickAdd() async {
    final entry = await showModalBottomSheet<_NewEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _QuickAddSheet(),
    );
    if (entry == null) return;
    try {
      final tz = await ref.read(timeZoneProvider.future);
      await ref.read(calorieRepositoryProvider).addEntry(
        date: _key,
        tz: tz,
        name: entry.name,
        kcal: entry.kcal,
        protein: entry.protein,
        carbs: entry.carbs,
        fat: entry.fat,
      );
      ref.read(calorieRevisionProvider.notifier).bump();
      await Haptics.setComplete();
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    }
  }

  Future<void> _delete(FoodEntry e) async {
    try {
      await ref.read(calorieRepositoryProvider).deleteEntry(e.id);
      ref.read(calorieRevisionProvider.notifier).bump();
    } on ApiException catch (err) {
      if (mounted) showAppSnack(context, err.message, error: true);
      ref.read(calorieRevisionProvider.notifier).bump();
    }
  }

  Future<void> _editTarget(CalorieTarget target) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TargetSheet(target: target, date: _key),
    );
    if (updated ?? false) ref.read(calorieRevisionProvider.notifier).bump();
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(calorieDayProvider(_key));
    final target = ref.watch(calorieTargetProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Calories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _quickAdd,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add food'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(calorieDayProvider(_key).future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.huge * 1.5),
              children: [
                _DayNavigator(day: _day, isToday: _isToday, onShift: _shiftDay),
                const SizedBox(height: AppSpacing.md),
                ...day.when(
                  loading: () => [const SkeletonList(count: 3, itemHeight: AppSizes.chartHeight, padding: EdgeInsets.zero)],
                  error: (e, _) => [ErrorState(error: e, onRetry: () => ref.invalidate(calorieDayProvider(_key)))],
                  data: (d) => _content(d, target.value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(CalorieDay d, CalorieTarget? target) {
    final c = context.colors;
    final items = <Widget>[
      _RingCard(day: d),
      if (d.targetKcal == null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: GlassCard(
            onTap: () => context.push(Routes.editProfile),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: c.warning),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text('Complete your profile to get a calorie target.', style: context.text.bodyMedium)),
                Icon(Icons.chevron_right_rounded, color: c.textMuted),
              ],
            ),
          ),
        ),
      const SectionHeader(title: 'Macros'),
      _MacroBars(consumed: d.consumed, goal: target?.goalTarget),
      if (d.burnedWorkouts.isNotEmpty) ...[
        const SectionHeader(title: 'Burned in workouts'),
        GlassCard(
          child: Column(
            children: [
              for (final w in d.burnedWorkouts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded, color: c.accent, size: AppSizes.iconMd),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: Text('${w.name} · ${Fmt.duration(Duration(seconds: w.durationSec))}', style: context.text.bodyLarge)),
                      Text('${w.kcal} kcal', style: context.numbers.small),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.xs),
              Text('Estimated from exercise type, your bodyweight and active time.', style: context.text.bodySmall),
            ],
          ),
        ),
      ],
      SectionHeader(title: 'Food log', actionLabel: target == null ? null : 'Target', onAction: target == null ? null : () => _editTarget(target)),
      if (d.entries.isEmpty)
        GlassCard(
          child: EmptyState(
            compact: true,
            icon: Icons.restaurant_rounded,
            title: _isToday ? 'Nothing logged today' : 'Nothing logged',
            message: 'Tap "Add food" to log a meal or snack.',
          ),
        )
      else
        for (final e in d.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Dismissible(
              key: ValueKey(e.id),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => _delete(e),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AppSpacing.xl),
                decoration: BoxDecoration(color: c.danger.withValues(alpha: AppOpacity.subtle), borderRadius: AppRadii.lgAll),
                child: Icon(Icons.delete_rounded, color: c.danger),
              ),
              child: _EntryTile(entry: e),
            ),
          ),
    ];
    return [for (var i = 0; i < items.length; i++) items[i].staggered(i)];
  }
}

class _DayNavigator extends StatelessWidget {
  const _DayNavigator({required this.day, required this.isToday, required this.onShift});

  final DateTime day;
  final bool isToday;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(tooltip: 'Previous day', onPressed: () => onShift(-1), icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(
          child: AnimatedSwitcher(
            duration: AppMotion.fast,
            child: Text(
              isToday ? 'Today' : Fmt.relativeDay(day) == 'Yesterday' ? 'Yesterday' : Fmt.weekdayDayMonth(day),
              key: ValueKey(day.day),
              textAlign: TextAlign.center,
              style: context.text.titleLarge,
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Next day',
          onPressed: isToday ? null : () => onShift(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _RingCard extends StatelessWidget {
  const _RingCard({required this.day});

  final CalorieDay day;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final target = day.targetKcal;
    // Workout calories add to the day's budget.
    final budget = (target ?? 0) + day.burnedKcal;
    final progress = budget <= 0 ? 0.0 : day.consumed.kcal / budget;
    final over = progress > 1;
    final remaining = day.remainingKcal ?? 0;

    return GlassCard(
      child: Column(
        children: [
          TimerRing(
            progress: progress.clamp(0.0, 1.0),
            size: AppSizes.timerRingSize * 0.8,
            animationDuration: AppMotion.ring,
            curve: AppMotion.emphasized,
            gradient: over ? [c.warning, c.danger] : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedCounter(
                  value: target == null ? day.consumed.kcal : remaining.abs(),
                  style: context.numbers.large,
                  semanticsSuffix: 'kilocalories',
                ),
                Text(
                  target == null ? 'kcal eaten' : (remaining >= 0 ? 'kcal left' : 'kcal over'),
                  style: context.text.bodyMedium?.copyWith(color: remaining < 0 ? c.danger : null),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _RingStat(label: 'Target', value: target == null ? '—' : Fmt.integer(target)),
              _RingStat(label: 'Eaten', value: Fmt.integer(day.consumed.kcal)),
              _RingStat(label: 'Burned', value: '+${Fmt.integer(day.burnedKcal)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingStat extends StatelessWidget {
  const _RingStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: context.numbers.medium),
        Text(label.toUpperCase(), style: context.text.labelSmall),
      ],
    ),
  );
}

class _MacroBars extends StatelessWidget {
  const _MacroBars({required this.consumed, required this.goal});

  final Macros consumed;
  final GoalTarget? goal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget bar(String label, double value, int? target, Color color) {
      final ratio = target == null || target == 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: context.text.titleSmall)),
                Text(
                  target == null ? '${Fmt.integer(value)} g' : '${Fmt.integer(value)} / $target g',
                  style: context.numbers.small,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: AppRadii.pillAll,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio),
                duration: AppMotion.ring,
                curve: AppMotion.emphasized,
                builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: AppSpacing.sm, color: color, backgroundColor: c.glassFill),
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      child: Column(
        children: [
          bar('Protein', consumed.protein, goal?.proteinG, c.accentEnd),
          bar('Carbs', consumed.carbs, goal?.carbsG, c.accentStart),
          bar('Fat', consumed.fat, goal?.fatG, c.warning),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final FoodEntry entry;

  @override
  Widget build(BuildContext context) {
    final m = entry.macros;
    return GlassCard(
      blur: false,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, style: context.text.titleSmall),
                Text(
                  'P ${Fmt.integer(m.protein)} · C ${Fmt.integer(m.carbs)} · F ${Fmt.integer(m.fat)} · ${Fmt.time(entry.loggedAt)}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          Text('${Fmt.integer(m.kcal)} kcal', style: context.numbers.small),
        ],
      ),
    );
  }
}

// ---- Quick add ---------------------------------------------------------------

class _NewEntry {
  const _NewEntry(this.name, this.kcal, this.protein, this.carbs, this.fat);

  final String name;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
}

/// Common foods for one-tap logging.
const _presets = [
  _NewEntry('Protein shake', 150, 30, 4, 2),
  _NewEntry('Chicken breast (150 g)', 248, 46, 0, 5),
  _NewEntry('Rice (1 cup cooked)', 205, 4, 45, 0.4),
  _NewEntry('Oats (80 g)', 300, 10, 54, 5),
  _NewEntry('Eggs (3)', 216, 18, 1, 15),
  _NewEntry('Banana', 105, 1, 27, 0.4),
  _NewEntry('Greek yogurt (200 g)', 146, 20, 8, 4),
];

class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet();

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  /// Calories from macros when kcal is left blank (4/4/9 kcal per gram).
  double get _kcalValue {
    final typed = double.tryParse(_kcal.text.replaceAll(',', '.'));
    return typed ?? (_num(_protein) * 4 + _num(_carbs) * 4 + _num(_fat) * 9);
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, _NewEntry(_name.text.trim(), _kcalValue, _num(_protein), _num(_carbs), _num(_fat)));
  }

  @override
  Widget build(BuildContext context) {
    final numeric = [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,5}([.,]\d?)?'))];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.lg),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add food', style: context.text.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              Text('QUICK ADD', style: context.text.labelSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final p in _presets)
                    ActionChip(
                      label: Text('${p.name} · ${p.kcal.round()}'),
                      onPressed: () => Navigator.pop(context, p),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('CUSTOM', style: context.text.labelSmall),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Name',
                controller: _name,
                icon: Icons.restaurant_rounded,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Name it (e.g. "Lunch")' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Calories (kcal)',
                hint: 'Leave empty to calculate from macros',
                controller: _kcal,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: numeric,
                icon: Icons.local_fire_department_rounded,
                validator: (_) => _kcalValue <= 0 ? 'Enter calories or macros' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  for (final (label, ctrl) in [('Protein g', _protein), ('Carbs g', _carbs), ('Fat g', _fat)]) ...[
                    Expanded(
                      child: AppTextField(
                        label: label,
                        controller: ctrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: numeric,
                      ),
                    ),
                    if (label != 'Fat g') const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              GradientButton(label: 'Add', icon: Icons.check_rounded, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Target settings ---------------------------------------------------------

class _TargetSheet extends ConsumerStatefulWidget {
  const _TargetSheet({required this.target, required this.date});

  final CalorieTarget target;
  final String date;

  @override
  ConsumerState<_TargetSheet> createState() => _TargetSheetState();
}

class _TargetSheetState extends ConsumerState<_TargetSheet> {
  late Goal _goal = Goal.fromApi(widget.target.goal);
  late bool _manual = widget.target.customTargetKcal != null;
  late final _kcal = TextEditingController(text: widget.target.customTargetKcal?.toString() ?? widget.target.effectiveTargetKcal?.toString() ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _kcal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final kcal = int.tryParse(_kcal.text);
    if (_manual && (kcal == null || kcal < 800 || kcal > 10000)) {
      showAppSnack(context, 'Enter a target between 800 and 10,000 kcal', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(calorieRepositoryProvider).setTarget(
        goal: _goal.name,
        targetKcal: _manual ? kcal : null,
        clearCustom: !_manual,
        date: widget.date,
      );
      // The goal lives on the profile too.
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.target;
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Daily target', style: context.text.headlineSmall),
            if (t.tdee != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Maintenance ≈ ${Fmt.integer(t.tdee!)} kcal (BMR ${Fmt.integer(t.bmr!)} × activity, Mifflin-St Jeor)',
                style: context.text.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            for (final g in Goal.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: GlassCard(
                  highlighted: _goal == g && !_manual,
                  onTap: () => setState(() {
                    _goal = g;
                    _manual = false;
                  }),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [Text(g.label, style: context.text.titleSmall), Text(g.description, style: context.text.bodySmall)],
                        ),
                      ),
                      Text(
                        t.targets[g.name] == null ? '—' : '${Fmt.integer(t.targets[g.name]!.kcal)} kcal',
                        style: context.numbers.small.copyWith(color: _goal == g ? c.accent : null),
                      ),
                    ],
                  ),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Set my own target'),
              value: _manual,
              onChanged: (v) => setState(() => _manual = v),
            ),
            AnimatedSize(
              duration: AppMotion.medium,
              child: _manual
                  ? AppTextField(
                      label: 'Target (kcal)',
                      controller: _kcal,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      icon: Icons.flag_rounded,
                    )
                  : const SizedBox(width: double.infinity),
            ),
            if (t.profileIncomplete) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Add your ${t.missing.join(', ')} in your profile for automatic targets.', style: context.text.bodySmall?.copyWith(color: c.warning)),
            ],
            const SizedBox(height: AppSpacing.xl),
            GradientButton(label: 'Save target', icon: Icons.check_rounded, loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
