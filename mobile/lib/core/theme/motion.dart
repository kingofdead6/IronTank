import 'package:flutter/animation.dart';

/// Single source of truth for every animation duration, curve and spring in
/// the app. Widgets never hard-code timings; they reference [AppMotion].
abstract final class AppMotion {
  // ---- Durations ----------------------------------------------------------

  /// Micro feedback: button press-in, toggles.
  static const Duration instant = Duration(milliseconds: 90);

  /// Small state changes: chips, icons, colour shifts.
  static const Duration fast = Duration(milliseconds: 160);

  /// Default for most transitions (cards expanding, indicators moving).
  static const Duration medium = Duration(milliseconds: 260);

  /// Larger surfaces: sheets, page routes, hero flights.
  static const Duration slow = Duration(milliseconds: 420);

  /// Expressive moments: rank badges filling, onboarding art.
  static const Duration slower = Duration(milliseconds: 650);

  /// Page route transition (defined once in the router).
  static const Duration page = Duration(milliseconds: 380);

  /// Delay between consecutive items of a staggered list entrance.
  static const Duration stagger = Duration(milliseconds: 45);

  /// Cap so long lists don't wait forever for their last item.
  static const int maxStaggeredItems = 12;

  /// Animated number counters.
  static const Duration counter = Duration(milliseconds: 900);

  /// Charts drawing in on load.
  static const Duration chart = Duration(milliseconds: 800);

  /// One sweep of the skeleton shimmer.
  static const Duration shimmer = Duration(milliseconds: 1400);

  /// Progress rings filling (ranks, calories).
  static const Duration ring = Duration(milliseconds: 1100);

  /// One clock tick; countdown rings interpolate linearly across it.
  static const Duration tick = Duration(seconds: 1);

  /// Full-screen celebrations (PRs, level-ups).
  static const Duration celebration = Duration(milliseconds: 2600);

  /// Onboarding carousel auto-advance.
  static const Duration carouselAutoAdvance = Duration(seconds: 5);

  /// Debounce for search fields.
  static const Duration searchDebounce = Duration(milliseconds: 300);

  /// How long snackbars stay visible.
  static const Duration snackbar = Duration(seconds: 3);

  // ---- Curves -------------------------------------------------------------

  /// Default easing for most movement.
  static const Curve standard = Curves.easeOutCubic;

  /// Material 3 "emphasized" easing for hero-like movement.
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);

  /// Things entering the screen.
  static const Curve enter = Curves.easeOutQuart;

  /// Things leaving the screen.
  static const Curve exit = Curves.easeInCubic;

  /// Playful overshoot for celebratory elements.
  static const Curve overshoot = Curves.easeOutBack;

  /// Elastic pop for badges and level-ups.
  static const Curve elastic = Curves.elasticOut;

  /// Slow in-out pulse for idle "breathing" elements (splash logo, live dots).
  static const Curve breathe = Curves.easeInOut;

  /// Linear progress (timers, shimmer).
  static const Curve linear = Curves.linear;

  // ---- Springs & scales ---------------------------------------------------

  /// Spring used by pressable surfaces when released.
  static const SpringDescription pressSpring = SpringDescription(mass: 1, stiffness: 420, damping: 18);

  /// Scale applied while a pressable surface is held down.
  static const double pressScale = 0.95;

  /// Starting scale for content swapped in by AnimatedSwitcher (labels ↔ spinners).
  static const double switchScale = 0.8;

  /// Scale amplitude of the breathing pulse (±).
  static const double breatheScale = 0.04;

  /// One half-cycle of the breathing pulse.
  static const Duration breatheCycle = Duration(milliseconds: 1300);

  /// Starting scale for elements that pop in (badges, celebration items).
  static const double popScale = 0.6;

  /// Vertical offset (fraction of height) staggered items slide in from.
  static const double entranceSlide = 0.08;

  /// Scale a list item grows to while it is being dragged to reorder.
  static const double dragLiftScale = 1.03;

  /// Vertical offset (in its own heights) floating panels slide in from.
  static const double panelSlide = 1.5;

  /// Repeat rate while a +/- stepper button is held down.
  static const Duration holdRepeat = Duration(milliseconds: 90);

  /// Opacity the outgoing page fades to while a new page covers it.
  static const double pageBehindOpacity = 0.6;

  /// Horizontal offset (fraction of width) page routes slide in from.
  static const double pageSlide = 0.06;

  /// Delay for item [index] of a staggered list, capped at [maxStaggeredItems].
  static Duration staggerDelay(int index) =>
      stagger * (index < maxStaggeredItems ? index : maxStaggeredItems);
}

/// Physics for the PR-celebration confetti cannons.
abstract final class ConfettiTuning {
  /// Chance per frame of emitting a burst while the cannon runs.
  static const double emissionFrequency = 0.06;
  static const int particlesPerBurst = 14;
  static const double minBlastForce = 10;
  static const double maxBlastForce = 28;
  static const double gravity = 0.25;
}
