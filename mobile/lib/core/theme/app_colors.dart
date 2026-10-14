import 'package:flutter/material.dart';

/// Semantic colour palette, exposed as a [ThemeExtension] so widgets read
/// `context.colors.x` and light/dark switch (and animate) automatically.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.backgroundElevated,
    required this.surface,
    required this.surfaceHigh,
    required this.glassFill,
    required this.glassBorder,
    required this.glassHighlight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accentStart,
    required this.accentEnd,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.divider,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.scrim,
    required this.chartGrid,
    required this.heatmapEmpty,
    required this.shadow,
  });

  final Color background;
  final Color backgroundElevated;
  final Color surface;
  final Color surfaceHigh;
  final Color glassFill;
  final Color glassBorder;
  final Color glassHighlight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accentStart;
  final Color accentEnd;
  final Color onAccent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color divider;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color scrim;
  final Color chartGrid;
  final Color heatmapEmpty;
  final Color shadow;

  /// The single energetic brand gradient (electric orange → magenta).
  LinearGradient get accentGradient => LinearGradient(
    colors: [accentStart, accentEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Mid-point of the accent gradient, for single-colour accents (icons, lines).
  Color get accent => Color.lerp(accentStart, accentEnd, 0.35)!;

  /// Soft coloured shadow under accent surfaces.
  Color get accentGlow => accentEnd.withValues(alpha: 0.35);

  /// Translucent accent wash for selected backgrounds.
  Color get accentSoft => accent.withValues(alpha: 0.15);

  static const dark = AppColors(
    background: Color(0xFF0A0A0E),
    backgroundElevated: Color(0xFF111117),
    surface: Color(0xFF15151C),
    surfaceHigh: Color(0xFF1E1E27),
    glassFill: Color(0x14FFFFFF),
    glassBorder: Color(0x1FFFFFFF),
    glassHighlight: Color(0x0DFFFFFF),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFFA6A6B2),
    textMuted: Color(0xFF9393A0),
    accentStart: Color(0xFFF25C05),
    accentEnd: Color(0xFFFF2E88),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFFB4D6D),
    divider: Color(0x14FFFFFF),
    shimmerBase: Color(0xFF17171E),
    shimmerHighlight: Color(0xFF26262F),
    scrim: Color(0xB3000000),
    chartGrid: Color(0x12FFFFFF),
    heatmapEmpty: Color(0xFF1A1A22),
    shadow: Color(0x66000000),
  );

  static const light = AppColors(
    background: Color(0xFFF4F4F7),
    backgroundElevated: Color(0xFFFAFAFC),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEDEDF2),
    glassFill: Color(0xB3FFFFFF),
    glassBorder: Color(0x14000000),
    glassHighlight: Color(0x80FFFFFF),
    textPrimary: Color(0xFF0E0E12),
    textSecondary: Color(0xFF52525E),
    textMuted: Color(0xFF696975),
    accentStart: Color(0xFFF25C05),
    accentEnd: Color(0xFFE01E78),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF059669),
    warning: Color(0xFFB45309),
    danger: Color(0xFFDC2647),
    divider: Color(0x14000000),
    shimmerBase: Color(0xFFE8E8EE),
    shimmerHighlight: Color(0xFFF7F7FA),
    scrim: Color(0x66000000),
    chartGrid: Color(0x14000000),
    heatmapEmpty: Color(0xFFE6E6EC),
    shadow: Color(0x1A000000),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: l(background, other.background),
      backgroundElevated: l(backgroundElevated, other.backgroundElevated),
      surface: l(surface, other.surface),
      surfaceHigh: l(surfaceHigh, other.surfaceHigh),
      glassFill: l(glassFill, other.glassFill),
      glassBorder: l(glassBorder, other.glassBorder),
      glassHighlight: l(glassHighlight, other.glassHighlight),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      accentStart: l(accentStart, other.accentStart),
      accentEnd: l(accentEnd, other.accentEnd),
      onAccent: l(onAccent, other.onAccent),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      divider: l(divider, other.divider),
      shimmerBase: l(shimmerBase, other.shimmerBase),
      shimmerHighlight: l(shimmerHighlight, other.shimmerHighlight),
      scrim: l(scrim, other.scrim),
      chartGrid: l(chartGrid, other.chartGrid),
      heatmapEmpty: l(heatmapEmpty, other.heatmapEmpty),
      shadow: l(shadow, other.shadow),
    );
  }
}

/// Rank tier colours. Used **only** for ranks (badges, rings, tier labels).
@immutable
class TierColors {
  const TierColors(this.primary, this.secondary, this.glow);

  final Color primary;
  final Color secondary;
  final Color glow;

  LinearGradient get gradient => LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const bronze = TierColors(Color(0xFFE09A5F), Color(0xFF8A4B22), Color(0x66E09A5F));
  static const silver = TierColors(Color(0xFFE3E8EF), Color(0xFF8D97A6), Color(0x66C9D1DC));
  static const gold = TierColors(Color(0xFFFFD75E), Color(0xFFC98A0B), Color(0x80FFD75E));
  static const platinum = TierColors(Color(0xFF7FF5E1), Color(0xFF14A38B), Color(0x807FF5E1));
  static const diamond = TierColors(Color(0xFF8CC8FF), Color(0xFF3A63F0), Color(0x808CC8FF));
  static const elite = TierColors(Color(0xFFC9A6FF), Color(0xFF7438E8), Color(0x80C9A6FF));
  static const legend = TierColors(Color(0xFFFF6B6B), Color(0xFFFFC23D), Color(0x99FF8A5C));

  /// Colours for unranked lifts.
  static const unranked = TierColors(Color(0xFF5A5A66), Color(0xFF34343E), Color(0x00000000));

  static const ordered = [bronze, silver, gold, platinum, diamond, elite, legend];

  /// Badge shading shared by every tier (cut-gem facets, bevel, numeral).
  static const facetLight = Color(0x2EFFFFFF);
  static const facetShadow = Color(0x24000000);
  static const bevel = Color(0x47FFFFFF);
  static const numeral = Color(0xFFFFFFFF);

  /// Tier colours by index (0 = Bronze … 6 = Legend); null/out of range = unranked.
  static TierColors of(int? tierIndex) {
    if (tierIndex == null || tierIndex < 0 || tierIndex >= ordered.length) return unranked;
    return ordered[tierIndex];
  }
}

/// Opacity levels applied to otherwise-themed content.
abstract final class AppOpacity {
  static const double disabled = 0.45;
  static const double muted = 0.6;
  static const double subtle = 0.25;
  static const double faint = 0.08;
  static const double navGlass = 0.82;

  /// Backdrop behind full-screen celebrations.
  static const double overlay = 0.94;
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
