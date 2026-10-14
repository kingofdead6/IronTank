import 'package:flutter/widgets.dart';

/// Spacing scale (logical pixels). Generous by design.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double huge = 64;

  /// Horizontal padding of every screen.
  static const double screen = 20;

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: screen);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);

  /// Space reserved below scrolling content for the floating bottom nav.
  static const double bottomNavClearance = 112;
}

/// Corner radii.
abstract final class AppRadii {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Fixed component dimensions shared across features.
abstract final class AppSizes {
  static const double glassBlur = 18;
  static const double borderWidth = 1;
  static const double spinnerStroke = 2.4;
  static const double shadowBlur = 24;
  static const double shadowOffset = 8;
  static const double iconSm = 16;
  static const double iconMd = 22;
  static const double iconLg = 28;
  static const double iconXl = 40;
  static const double buttonHeight = 56;
  static const double buttonHeightSm = 40;
  static const double minTapTarget = 48;
  static const double bottomNavHeight = 72;
  static const double avatar = 44;
  static const double avatarLg = 88;
  static const double chipHeight = 36;
  static const double ringStroke = 12;
  static const double ringStrokeSm = 6;
  static const double timerRingSize = 260;
  static const double rankBadgeLg = 160;
  static const double rankBadgeMd = 96;
  static const double rankBadgeSm = 56;
  static const double exerciseThumb = 56;
  static const double chartHeight = 200;
  static const double chartHeightSm = 140;
  static const double heatmapCell = 14;
  static const double heatmapGap = 3;
  static const double sheetHandleWidth = 40;
  static const double sheetHandleHeight = 4;
  static const double maxContentWidth = 560;
}
