import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/choice_card.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/staggered.dart';
import '../../../core/widgets/value_stepper.dart';
import '../application/auth_controller.dart';
import '../data/user.dart';

/// Four-step profile setup after registration. Everything here feeds strength
/// standards (sex, bodyweight) and calorie targets (age, height, activity, goal).
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _pages = PageController();
  int _step = 0;
  bool _saving = false;

  Sex? _sex;
  DateTime _birthDate = DateTime(DateTime.now().year - 25, 1, 1);
  WeightUnit _unit = WeightUnit.kg;
  double _heightCm = 175;
  double _weightKg = 75;
  Goal _goal = Goal.maintain;
  ActivityLevel _activity = ActivityLevel.moderate;

  static const _stepCount = 4;
  static const _minHeightCm = 120.0;
  static const _maxHeightCm = 230.0;
  static const _minWeightKg = 30.0;
  static const _maxWeightKg = 250.0;

  bool get _canContinue => _step != 0 || _sex != null;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int step) {
    setState(() => _step = step);
    _pages.animateToPage(step, duration: AppMotion.slow, curve: AppMotion.emphasized);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
        ProfileUpdate(
          sex: _sex,
          birthDate: _birthDate,
          heightCm: double.parse(_heightCm.toStringAsFixed(1)),
          bodyweightKg: double.parse(_weightKg.toStringAsFixed(1)),
          unit: _unit,
          goal: _goal,
          activityLevel: _activity,
          onboardingComplete: true,
        ),
      );
      await Haptics.celebrate();
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = ref.watch(currentUserProvider)?.username ?? '';
    final last = _step == _stepCount - 1;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_step - 1);
      },
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.screen, 0),
                  child: Row(
                    children: [
                      AnimatedOpacity(
                        duration: AppMotion.fast,
                        opacity: _step > 0 ? 1 : 0,
                        child: IconButton(
                          tooltip: 'Back',
                          onPressed: _step > 0 ? () => _go(_step - 1) : null,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      Expanded(child: _ProgressBar(value: (_step + 1) / _stepCount)),
                      const SizedBox(width: AppSpacing.md),
                      Text('${_step + 1}/$_stepCount', style: context.numbers.small.copyWith(color: c.textSecondary)),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _StepLayout(
                        title: name.isEmpty ? 'Welcome!' : 'Welcome, $name!',
                        subtitle: 'Strength standards differ by sex. This keeps your ranks fair.',
                        children: [
                          for (final s in Sex.values)
                            ChoiceCard(
                              title: s.label,
                              icon: s == Sex.male ? Icons.male_rounded : Icons.female_rounded,
                              selected: _sex == s,
                              onTap: () => setState(() => _sex = s),
                            ),
                        ],
                      ),
                      _StepLayout(
                        title: 'When were you born?',
                        subtitle: 'Used for your calorie target. Never shown to anyone.',
                        children: [
                          GlassCard(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                            child: SizedBox(
                              height: AppSizes.chartHeight,
                              child: CupertinoTheme(
                                data: CupertinoThemeData(
                                  brightness: Theme.of(context).brightness,
                                  textTheme: CupertinoTextThemeData(dateTimePickerTextStyle: context.text.titleLarge),
                                ),
                                child: CupertinoDatePicker(
                                  mode: CupertinoDatePickerMode.date,
                                  initialDateTime: _birthDate,
                                  minimumDate: DateTime(1920),
                                  maximumDate: DateTime(DateTime.now().year - 13, 12, 31),
                                  onDateTimeChanged: (d) => _birthDate = d,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      _StepLayout(
                        title: 'Your body',
                        subtitle: 'Ranks compare what you lift to what you weigh.',
                        children: [
                          SegmentedButton<WeightUnit>(
                            segments: const [
                              ButtonSegment(value: WeightUnit.kg, label: Text('Metric (kg)')),
                              ButtonSegment(value: WeightUnit.lb, label: Text('Imperial (lb)')),
                            ],
                            selected: {_unit},
                            onSelectionChanged: (s) => setState(() => _unit = s.first),
                          ),
                          _unit == WeightUnit.kg
                              ? ValueStepper(
                                  label: 'Height',
                                  value: _heightCm,
                                  min: _minHeightCm,
                                  max: _maxHeightCm,
                                  step: 1,
                                  unit: 'cm',
                                  onChanged: (v) => setState(() => _heightCm = v),
                                )
                              : ValueStepper(
                                  label: 'Height',
                                  value: Units.cmToInches(_heightCm).roundToDouble(),
                                  min: Units.cmToInches(_minHeightCm).ceilToDouble(),
                                  max: Units.cmToInches(_maxHeightCm).floorToDouble(),
                                  step: 1,
                                  unit: 'in',
                                  caption: _feetInches(_heightCm),
                                  onChanged: (v) => setState(() => _heightCm = Units.inchesToCm(v)),
                                ),
                          ValueStepper(
                            label: 'Bodyweight',
                            value: double.parse(Units.fromKg(_weightKg, _unit).toStringAsFixed(1)),
                            min: Units.fromKg(_minWeightKg, _unit).roundToDouble(),
                            max: Units.fromKg(_maxWeightKg, _unit).roundToDouble(),
                            step: 0.5,
                            decimals: 1,
                            unit: _unit.label,
                            onChanged: (v) => setState(() => _weightKg = Units.toKg(v, _unit)),
                          ),
                        ],
                      ),
                      _StepLayout(
                        title: "What's the goal?",
                        subtitle: 'Sets your daily calorie target. You can change it any time.',
                        children: [
                          for (final g in Goal.values)
                            ChoiceCard(
                              title: g.label,
                              subtitle: g.description,
                              icon: switch (g) {
                                Goal.cut => Icons.local_fire_department_rounded,
                                Goal.maintain => Icons.balance_rounded,
                                Goal.bulk => Icons.trending_up_rounded,
                              },
                              selected: _goal == g,
                              onTap: () => setState(() => _goal = g),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.md),
                            child: Text('ACTIVITY LEVEL', style: context.text.labelSmall),
                          ),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final a in ActivityLevel.values)
                                Tooltip(
                                  message: a.description,
                                  child: ChoiceChip(
                                    label: Text(a.label),
                                    selected: _activity == a,
                                    onSelected: (_) => setState(() => _activity = a),
                                  ),
                                ),
                            ],
                          ),
                          Text(_activity.description, style: context.text.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.lg),
                  child: GradientButton(
                    label: last ? "Let's lift" : 'Continue',
                    icon: last ? Icons.bolt_rounded : Icons.arrow_forward_rounded,
                    loading: _saving,
                    onPressed: _canContinue ? (last ? _finish : () => _go(_step + 1)) : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _feetInches(double cm) {
    final total = Units.cmToInches(cm).round();
    return "${total ~/ 12}' ${total % 12}\"";
  }
}

class _StepLayout extends StatelessWidget {
  const _StepLayout({required this.title, required this.subtitle, required this.children});

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      Text(title, style: context.text.displaySmall),
      Text(subtitle, style: context.text.bodyLarge?.copyWith(color: context.colors.textSecondary)),
      const SizedBox(height: AppSpacing.sm),
      ...children,
    ];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xl, AppSpacing.screen, AppSpacing.xl),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) => items[i].staggered(i),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Setup progress',
      value: '${(value * 100).round()} percent',
      child: ClipRRect(
        borderRadius: AppRadii.pillAll,
        child: SizedBox(
          height: AppSpacing.sm,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: c.glassFill)),
              TweenAnimationBuilder<double>(
                tween: Tween(end: value),
                duration: AppMotion.slow,
                curve: AppMotion.emphasized,
                builder: (_, v, _) => FractionallySizedBox(
                  widthFactor: v,
                  heightFactor: 1,
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(decoration: BoxDecoration(gradient: c.accentGradient)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
