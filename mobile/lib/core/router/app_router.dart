import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/profile_setup_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/profile/application/settings_controller.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/shell/app_shell.dart';
import 'route_table.dart';
import 'routes.dart';
import 'transitions.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Decides where the user may go based on auth + onboarding state.
String? authRedirect({required AuthState auth, required bool onboardingSeen, required String location}) {
  final isPublic = Routes.public.contains(location);

  if (auth.status == AuthStatus.unknown) return location == Routes.splash ? null : Routes.splash;

  if (!auth.isSignedIn) {
    if (location == Routes.splash) return onboardingSeen ? Routes.login : Routes.onboarding;
    return isPublic ? null : Routes.login;
  }

  if (auth.needsProfileSetup) return location == Routes.setup ? null : Routes.setup;
  if (isPublic || location == Routes.setup) return Routes.home;
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Bridge Riverpod state into GoRouter's refresh mechanism.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.listen(settingsProvider.select((s) => s.onboardingSeen), (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      auth: ref.read(authControllerProvider),
      onboardingSeen: ref.read(settingsProvider).onboardingSeen,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: Routes.splash, pageBuilder: (c, s) => fadePage(s, const SplashScreen())),
      GoRoute(path: Routes.onboarding, pageBuilder: (c, s) => fadePage(s, const OnboardingScreen())),
      GoRoute(path: Routes.login, pageBuilder: (c, s) => fadeSlidePage(s, const LoginScreen())),
      GoRoute(path: Routes.register, pageBuilder: (c, s) => fadeSlidePage(s, const RegisterScreen())),
      GoRoute(path: Routes.setup, pageBuilder: (c, s) => fadeSlidePage(s, const ProfileSetupScreen())),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, pageBuilder: (c, s) => fadePage(s, const HomeScreen()))],
          ),
          ...tabBranches(),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.profile, pageBuilder: (c, s) => fadePage(s, const ProfileScreen()))],
          ),
        ],
      ),
      ...featureRoutes(_rootKey),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
