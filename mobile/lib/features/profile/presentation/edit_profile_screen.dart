import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/staggered.dart';
import '../../../core/widgets/value_stepper.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/user.dart';
import '../../progress/application/progress_providers.dart';

/// Edit every profile field that feeds ranks and calorie targets.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final User _user = ref.read(currentUserProvider)!;
  late final _username = TextEditingController(text: _user.username);
  late Sex? _sex = _user.sex;
  late DateTime? _birthDate = _user.birthDate;
  late double _heightCm = _user.heightCm ?? 175;
  late double _weightKg = _user.bodyweightKg ?? 75;
  late ActivityLevel _activity = _user.activityLevel;
  late Goal _goal = _user.goal;
  bool _saving = false;

  WeightUnit get _unit => _user.unit;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 13, 12, 31),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final name = _username.text.trim();
    if (name.length < 2) {
      showAppSnack(context, 'Username needs at least 2 characters', error: true);
      return;
    }
    setState(() => _saving = true);
    final weight = double.parse(_weightKg.toStringAsFixed(1));
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
        ProfileUpdate(
          username: name,
          sex: _sex,
          birthDate: _birthDate,
          heightCm: double.parse(_heightCm.toStringAsFixed(1)),
          bodyweightKg: weight == _user.bodyweightKg ? null : weight,
          activityLevel: _activity,
          goal: _goal,
        ),
      );
      // A changed bodyweight adds a history point.
      ref.read(bodyweightRevisionProvider.notifier).bump();
      if (mounted) {
        showAppSnack(context, 'Profile saved');
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      AppTextField(label: 'Username', controller: _username, icon: Icons.person_outline_rounded),
      Text('SEX', style: context.text.labelSmall),
      SegmentedButton<Sex>(
        segments: [for (final s in Sex.values) ButtonSegment(value: s, label: Text(s.label))],
        selected: {?_sex},
        emptySelectionAllowed: true,
        onSelectionChanged: (s) => setState(() => _sex = s.isEmpty ? _sex : s.first),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.cake_outlined),
        title: const Text('Birth date'),
        subtitle: Text(_birthDate == null ? 'Not set' : Fmt.fullDate(_birthDate!)),
        trailing: const Icon(Icons.edit_calendar_rounded),
        onTap: _pickBirthDate,
      ),
      if (_unit == WeightUnit.kg)
        ValueStepper(label: 'Height', value: _heightCm.roundToDouble(), min: 120, max: 230, step: 1, unit: 'cm', onChanged: (v) => setState(() => _heightCm = v))
      else
        ValueStepper(
          label: 'Height',
          value: Units.cmToInches(_heightCm).roundToDouble(),
          min: 48,
          max: 90,
          step: 1,
          unit: 'in',
          onChanged: (v) => setState(() => _heightCm = Units.inchesToCm(v)),
        ),
      ValueStepper(
        label: 'Bodyweight',
        value: double.parse(Units.fromKg(_weightKg, _unit).toStringAsFixed(1)),
        min: Units.fromKg(30, _unit).roundToDouble(),
        max: Units.fromKg(250, _unit).roundToDouble(),
        step: 0.5,
        decimals: 1,
        unit: _unit.label,
        onChanged: (v) => setState(() => _weightKg = Units.toKg(v, _unit)),
      ),
      Text('ACTIVITY LEVEL', style: context.text.labelSmall),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final a in ActivityLevel.values)
            ChoiceChip(label: Text(a.label), selected: _activity == a, onSelected: (_) => setState(() => _activity = a)),
        ],
      ),
      Text(_activity.description, style: context.text.bodySmall),
      Text('GOAL', style: context.text.labelSmall),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final g in Goal.values) ChoiceChip(label: Text(g.label), selected: _goal == g, onSelected: (_) => setState(() => _goal = g)),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      GradientButton(label: 'Save', icon: Icons.check_rounded, loading: _saving, onPressed: _save),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Edit profile')),
      body: AppBackground(
        child: SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xxl),
            itemCount: fields.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, i) => fields[i].staggered(i),
          ),
        ),
      ),
    );
  }
}
