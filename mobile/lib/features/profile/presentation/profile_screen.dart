import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/staggered.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/user.dart';
import '../../programs/presentation/widgets/program_exercise_sheet.dart' show restOptions;
import '../application/settings_controller.dart';

/// Profile tab: who you are, training preferences, app settings, account.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _update(BuildContext context, WidgetRef ref, ProfileUpdate update) async {
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(update);
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Workouts waiting to sync on this device will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok ?? false) await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final settings = ref.watch(settingsProvider);
    final settingsCtrl = ref.read(settingsProvider.notifier);
    if (user == null) return const SizedBox.shrink();
    final c = context.colors;
    final age = user.birthDate == null ? null : DateTime.now().difference(user.birthDate!).inDays ~/ 365;

    final items = <Widget>[
      Text('Profile', style: context.text.displaySmall),
      const SizedBox(height: AppSpacing.xl),
      GlassCard(
        onTap: () => context.push(Routes.editProfile),
        semanticLabel: 'Edit profile',
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: AppSizes.avatarLg * 0.75,
                  height: AppSizes.avatarLg * 0.75,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: c.accentGradient),
                  child: Text(user.initials, style: context.text.headlineMedium?.copyWith(color: c.onAccent)),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.username, style: context.text.titleLarge),
                      Text(user.email, style: context.text.bodySmall, overflow: TextOverflow.ellipsis),
                      if (user.createdAt != null) Text('Lifting since ${Fmt.fullDate(user.createdAt!)}', style: context.text.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.edit_rounded, color: c.textMuted, size: AppSizes.iconMd),
              ],
            ),
            const Divider(),
            Row(
              children: [
                _Fact(label: 'Weight', value: user.bodyweightKg == null ? '—' : Units.weight(user.bodyweightKg!, user.unit)),
                _Fact(
                  label: 'Height',
                  value: user.heightCm == null
                      ? '—'
                      : user.unit == WeightUnit.kg
                      ? '${user.heightCm!.round()} cm'
                      : '${Units.cmToInches(user.heightCm!).round() ~/ 12}\' ${Units.cmToInches(user.heightCm!).round() % 12}"',
                ),
                _Fact(label: 'Age', value: age?.toString() ?? '—'),
                _Fact(label: 'Goal', value: user.goal.label.split(' ').last),
              ],
            ),
          ],
        ),
      ),
      const SectionHeader(title: 'Training'),
      GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Units', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<WeightUnit>(
              segments: const [
                ButtonSegment(value: WeightUnit.kg, label: Text('Kilograms')),
                ButtonSegment(value: WeightUnit.lb, label: Text('Pounds')),
              ],
              selected: {user.unit},
              onSelectionChanged: (s) => _update(context, ref, ProfileUpdate(unit: s.first)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Default rest timer', style: context.text.titleSmall),
            Text('Used for exercises added outside a program', style: context.text.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final s in restOptions)
                  ChoiceChip(
                    label: Text(s < 60 ? '${s}s' : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}'),
                    selected: user.restTimerDefaultSec == s,
                    onSelected: (_) => _update(context, ref, ProfileUpdate(restTimerDefaultSec: s)),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      _LinkTile(icon: Icons.view_agenda_rounded, label: 'Programs', onTap: () => context.push(Routes.programs)),
      const SizedBox(height: AppSpacing.sm),
      _LinkTile(icon: Icons.military_tech_rounded, label: 'Ranks', onTap: () => context.push(Routes.ranks)),
      const SizedBox(height: AppSpacing.sm),
      _LinkTile(icon: Icons.restaurant_rounded, label: 'Calories', onTap: () => context.push(Routes.calories)),
      const SectionHeader(title: 'App'),
      GlassCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('Auto')),
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Dark')),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => settingsCtrl.setThemeMode(s.first),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.vibration_rounded),
              title: const Text('Haptic feedback'),
              value: settings.hapticsEnabled,
              onChanged: settingsCtrl.setHaptics,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Rest timer sound'),
              value: settings.timerSoundEnabled,
              onChanged: settingsCtrl.setTimerSound,
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Licenses'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showLicensePage(context: context, applicationName: 'IronRank'),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      GradientButton(
        label: 'Sign out',
        icon: Icons.logout_rounded,
        variant: GradientButtonVariant.outlined,
        onPressed: () => _logout(context, ref),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        'Calorie figures are estimates. IronRank is not medical advice.',
        textAlign: TextAlign.center,
        style: context.text.bodySmall,
      ),
    ];

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xl, AppSpacing.screen, AppSpacing.bottomNavClearance),
            children: [for (var i = 0; i < items.length; i++) items[i].staggered(i)],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        FittedBox(child: Text(value, style: context.numbers.small)),
        Text(label.toUpperCase(), style: context.text.labelSmall),
      ],
    ),
  );
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassCard(
      onTap: onTap,
      semanticLabel: label,
      child: Row(
        children: [
          Icon(icon, color: c.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: context.text.titleSmall)),
          Icon(Icons.chevron_right_rounded, color: c.textMuted),
        ],
      ),
    );
  }
}
