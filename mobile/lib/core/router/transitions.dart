import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/motion.dart';

/// The app's one page transition: incoming page fades in while sliding a
/// little from the right; the outgoing page fades back slightly.
CustomTransitionPage<T> fadeSlidePage<T>(GoRouterState state, Widget child, {bool fullscreenDialog = false}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    name: state.name,
    arguments: state.extra,
    fullscreenDialog: fullscreenDialog,
    transitionDuration: AppMotion.page,
    reverseTransitionDuration: AppMotion.page,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) {
      final enter = CurvedAnimation(parent: animation, curve: AppMotion.emphasized, reverseCurve: AppMotion.exit);
      final behind = CurvedAnimation(parent: secondary, curve: AppMotion.standard);
      return FadeTransition(
        opacity: Tween<double>(begin: 1, end: AppMotion.pageBehindOpacity).animate(behind),
        child: FadeTransition(
          opacity: enter,
          child: SlideTransition(
            position: Tween(
              begin: Offset(fullscreenDialog ? 0 : AppMotion.pageSlide, fullscreenDialog ? AppMotion.pageSlide : 0),
              end: Offset.zero,
            ).animate(enter),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Cross-fade used when switching bottom-nav tabs.
CustomTransitionPage<T> fadePage<T>(GoRouterState state, Widget child) => CustomTransitionPage<T>(
  key: state.pageKey,
  transitionDuration: AppMotion.medium,
  child: child,
  transitionsBuilder: (context, animation, _, child) =>
      FadeTransition(opacity: CurvedAnimation(parent: animation, curve: AppMotion.standard), child: child),
);
