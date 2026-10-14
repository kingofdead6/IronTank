import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Numeric display styles (Space Grotesk, tabular figures) for weights, timers
/// and stats. Body/UI text comes from the Material [TextTheme] (Inter Tight).
@immutable
class AppNumberStyles extends ThemeExtension<AppNumberStyles> {
  const AppNumberStyles({
    required this.hero,
    required this.timer,
    required this.large,
    required this.medium,
    required this.small,
    required this.unit,
  });

  /// Giant numbers: PR celebration, rank ratios.
  final TextStyle hero;

  /// Session/rest timers.
  final TextStyle timer;

  /// Stat tiles, set weights.
  final TextStyle large;
  final TextStyle medium;
  final TextStyle small;

  /// Unit suffix next to a number ("kg", "kcal").
  final TextStyle unit;

  static AppNumberStyles build(AppColors c) {
    const figures = [FontFeature.tabularFigures()];
    TextStyle base(double size, FontWeight w, double spacing, Color color) => GoogleFonts.spaceGrotesk(
      fontSize: size,
      fontWeight: w,
      letterSpacing: spacing,
      height: 1.0,
      color: color,
      fontFeatures: figures,
    );
    return AppNumberStyles(
      hero: base(88, FontWeight.w700, -3, c.textPrimary),
      timer: base(64, FontWeight.w700, -2, c.textPrimary),
      large: base(34, FontWeight.w700, -1, c.textPrimary),
      medium: base(22, FontWeight.w600, -0.5, c.textPrimary),
      small: base(16, FontWeight.w600, -0.2, c.textPrimary),
      unit: base(14, FontWeight.w500, 0, c.textSecondary),
    );
  }

  @override
  AppNumberStyles copyWith() => this;

  @override
  AppNumberStyles lerp(ThemeExtension<AppNumberStyles>? other, double t) {
    if (other is! AppNumberStyles) return this;
    return AppNumberStyles(
      hero: TextStyle.lerp(hero, other.hero, t)!,
      timer: TextStyle.lerp(timer, other.timer, t)!,
      large: TextStyle.lerp(large, other.large, t)!,
      medium: TextStyle.lerp(medium, other.medium, t)!,
      small: TextStyle.lerp(small, other.small, t)!,
      unit: TextStyle.lerp(unit, other.unit, t)!,
    );
  }
}

abstract final class AppTypography {
  /// UI text theme in Inter Tight with tightened display sizes.
  ///
  /// Built style-by-style (rather than `GoogleFonts.interTightTextTheme`) so the
  /// result is Flutter's own [TextTheme] type.
  static TextTheme textTheme(AppColors c) {
    TextStyle s(double size, FontWeight weight, {double spacing = 0, double height = 1.3, Color? color}) =>
        GoogleFonts.interTight(
          fontSize: size,
          fontWeight: weight,
          letterSpacing: spacing,
          height: height,
          color: color ?? c.textPrimary,
        );

    return TextTheme(
      displayLarge: s(48, FontWeight.w800, spacing: -1.5, height: 1.05),
      displayMedium: s(38, FontWeight.w800, spacing: -1.2, height: 1.1),
      displaySmall: s(32, FontWeight.w800, spacing: -1, height: 1.1),
      headlineLarge: s(28, FontWeight.w700, spacing: -0.8, height: 1.15),
      headlineMedium: s(24, FontWeight.w700, spacing: -0.6, height: 1.2),
      headlineSmall: s(20, FontWeight.w700, spacing: -0.4, height: 1.25),
      titleLarge: s(18, FontWeight.w700, spacing: -0.3),
      titleMedium: s(16, FontWeight.w600, spacing: -0.2),
      titleSmall: s(14, FontWeight.w600),
      bodyLarge: s(16, FontWeight.w400, height: 1.45),
      bodyMedium: s(14, FontWeight.w400, height: 1.45, color: c.textSecondary),
      bodySmall: s(12, FontWeight.w400, height: 1.4, color: c.textMuted),
      labelLarge: s(15, FontWeight.w700, spacing: 0.1),
      labelMedium: s(13, FontWeight.w600, spacing: 0.2, color: c.textSecondary),
      labelSmall: s(11, FontWeight.w700, spacing: 1.2, color: c.textMuted),
    );
  }
}

extension AppTypographyX on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;
  AppNumberStyles get numbers => Theme.of(this).extension<AppNumberStyles>()!;
}
