import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../../../core/utils/haptics.dart';

/// Device-level preferences (not synced to the server).
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.hapticsEnabled,
    required this.timerSoundEnabled,
    required this.onboardingSeen,
  });

  final ThemeMode themeMode;
  final bool hapticsEnabled;
  final bool timerSoundEnabled;
  final bool onboardingSeen;

  AppSettings copyWith({ThemeMode? themeMode, bool? hapticsEnabled, bool? timerSoundEnabled, bool? onboardingSeen}) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        timerSoundEnabled: timerSoundEnabled ?? this.timerSoundEnabled,
        onboardingSeen: onboardingSeen ?? this.onboardingSeen,
      );
}

class SettingsController extends Notifier<AppSettings> {
  static const _themeKey = 'themeMode';
  static const _hapticsKey = 'haptics';
  static const _soundKey = 'timerSound';
  static const _onboardingKey = 'onboardingSeen';

  LocalStore get _store => ref.read(localStoreProvider);

  @override
  AppSettings build() {
    final store = ref.watch(localStoreProvider);
    final settings = AppSettings(
      // Dark-first: dark unless the user picked otherwise.
      themeMode: ThemeMode.values.asNameMap()[store.getSetting(_themeKey)] ?? ThemeMode.dark,
      hapticsEnabled: store.getBool(_hapticsKey, fallback: true),
      timerSoundEnabled: store.getBool(_soundKey, fallback: true),
      onboardingSeen: store.getBool(_onboardingKey),
    );
    Haptics.enabled = settings.hapticsEnabled;
    return settings;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _store.setSetting(_themeKey, mode.name);
  }

  Future<void> setHaptics(bool enabled) async {
    Haptics.enabled = enabled;
    state = state.copyWith(hapticsEnabled: enabled);
    await _store.setBool(_hapticsKey, enabled);
  }

  Future<void> setTimerSound(bool enabled) async {
    state = state.copyWith(timerSoundEnabled: enabled);
    await _store.setBool(_soundKey, enabled);
  }

  Future<void> markOnboardingSeen() async {
    state = state.copyWith(onboardingSeen: true);
    await _store.setBool(_onboardingKey, true);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
