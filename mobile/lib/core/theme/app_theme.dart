import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'motion.dart';

/// Builds the light and dark [ThemeData] from the design tokens.
abstract final class AppTheme {
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);
  static ThemeData light() => _build(AppColors.light, Brightness.light);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final text = AppTypography.textTheme(c);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accentStart,
      onPrimary: c.onAccent,
      secondary: c.accentEnd,
      onSecondary: c.onAccent,
      error: c.danger,
      onError: c.onAccent,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerHighest: c.surfaceHigh,
      // Tonal buttons/chips use containers: keep them on the glass palette.
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.textPrimary,
      secondaryContainer: c.surfaceHigh,
      onSecondaryContainer: c.textPrimary,
      tertiary: c.accentEnd,
      onTertiary: c.onAccent,
      outline: c.glassBorder,
      outlineVariant: c.divider,
      shadow: c.shadow,
      scrim: c.scrim,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: AppRadii.mdAll,
      borderSide: BorderSide(color: c.glassBorder, width: AppSizes.borderWidth),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      extensions: [c, AppNumberStyles.build(c)],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        foregroundColor: c.textPrimary,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.glassFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.accent, width: AppSizes.borderWidth * 1.5)),
        errorBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.danger)),
        focusedErrorBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.danger, width: AppSizes.borderWidth * 1.5)),
        labelStyle: text.bodyMedium,
        hintStyle: text.bodyMedium?.copyWith(color: c.textMuted),
        prefixIconColor: c.textSecondary,
        suffixIconColor: c.textSecondary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.glassFill,
        selectedColor: c.accentStart,
        side: BorderSide(color: c.glassBorder),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.pillAll),
        labelStyle: text.labelMedium,
        secondaryLabelStyle: text.labelMedium?.copyWith(color: c.onAccent),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        showCheckmark: false,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.backgroundElevated,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.textMuted,
        dragHandleSize: const Size(AppSizes.sheetHandleWidth, AppSizes.sheetHandleHeight),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.backgroundElevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surfaceHigh,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.textPrimary),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        elevation: 0,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          textStyle: text.labelLarge,
          minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        inactiveTrackColor: c.glassFill,
        thumbColor: c.onAccent,
        overlayColor: c.accent.withValues(alpha: 0.15),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onAccent : c.textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.glassFill),
        trackOutlineColor: WidgetStateProperty.all(c.glassBorder),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent, linearTrackColor: c.glassFill),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accentStart,
        foregroundColor: c.onAccent,
        elevation: 0,
        highlightElevation: 0,
        shape: const StadiumBorder(),
        extendedTextStyle: text.labelLarge,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accentSoft : c.glassFill),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.textPrimary : c.textSecondary),
          iconColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.textMuted),
          side: WidgetStateProperty.all(BorderSide(color: c.glassBorder)),
          textStyle: WidgetStateProperty.all(text.labelMedium),
          minimumSize: WidgetStateProperty.all(const Size(0, AppSizes.buttonHeightSm)),
        ),
      ),
      badgeTheme: BadgeThemeData(backgroundColor: c.accentEnd, textColor: c.onAccent),
      popupMenuTheme: PopupMenuThemeData(
        color: c.backgroundElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll, side: BorderSide(color: c.glassBorder)),
        textStyle: text.bodyLarge,
      ),
      dividerTheme: DividerThemeData(color: c.divider, thickness: AppSizes.borderWidth, space: AppSpacing.xl),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: AppRadii.smAll),
        textStyle: text.bodySmall?.copyWith(color: c.textPrimary),
        waitDuration: AppMotion.slow,
      ),
    );
  }
}
