import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Named haptic patterns for the moments that matter. Light taps use the
/// system haptic engine; longer celebratory patterns use the vibration motor.
abstract final class Haptics {
  static bool enabled = true;
  static bool? _hasVibrator;

  static Future<bool> _canVibrate() async => _hasVibrator ??= await Vibration.hasVibrator();

  /// Any tap on an interactive surface.
  static Future<void> tap() async {
    if (enabled) await HapticFeedback.selectionClick();
  }

  /// A set ticked off.
  static Future<void> setComplete() async {
    if (enabled) await HapticFeedback.mediumImpact();
  }

  /// Rest timer finished: two firm pulses.
  static Future<void> timerDone() async {
    if (!enabled) return;
    if (await _canVibrate()) {
      await Vibration.vibrate(pattern: const [0, 180, 120, 260], intensities: const [0, 200, 0, 255]);
    } else {
      await HapticFeedback.heavyImpact();
    }
  }

  /// New personal record or rank-up: a rising triple burst.
  static Future<void> celebrate() async {
    if (!enabled) return;
    if (await _canVibrate()) {
      await Vibration.vibrate(pattern: const [0, 60, 60, 90, 60, 320], intensities: const [0, 120, 0, 190, 0, 255]);
    } else {
      await HapticFeedback.heavyImpact();
    }
  }

  /// Validation error / destructive confirmation.
  static Future<void> warning() async {
    if (enabled) await HapticFeedback.heavyImpact();
  }
}
