import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrank/core/widgets/gradient_button.dart';
import 'package:ironrank/features/auth/presentation/login_screen.dart';
import 'package:ironrank/features/auth/presentation/onboarding_screen.dart';
import 'package:ironrank/features/auth/presentation/profile_setup_screen.dart';
import 'package:ironrank/features/auth/presentation/register_screen.dart';

import '../helpers/harness.dart';

/// Renders each auth screen at phone size. Any layout overflow fails the test;
/// goldens (run with --update-goldens) give a visual snapshot for review.
void main() {
  testWidgets('onboarding renders and advances', (tester) async {
    await pumpScreen(tester, const OnboardingScreen());
    await pumpFrames(tester);
    expect(find.text('Log every rep'), findsOneWidget);
    await snapshot(find.byType(OnboardingScreen), 'onboarding');

    await tester.tap(find.widgetWithText(GradientButton, 'Next'));
    await pumpFrames(tester);
    expect(find.text('Smash your PRs'), findsOneWidget);
  });

  testWidgets('login validates input', (tester) async {
    await pumpScreen(tester, const LoginScreen());
    await pumpFrames(tester);
    await snapshot(find.byType(LoginScreen), 'login');

    await tester.tap(find.widgetWithText(GradientButton, 'Sign in'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('register renders', (tester) async {
    await pumpScreen(tester, const RegisterScreen());
    await pumpFrames(tester);
    expect(find.text('Create account'), findsWidgets);
  });

  testWidgets('profile setup walks through all steps', (tester) async {
    await pumpScreen(tester, const ProfileSetupScreen());
    await pumpFrames(tester);
    await snapshot(find.byType(ProfileSetupScreen), 'setup_sex');

    // Continue is disabled until a sex is chosen.
    await tester.tap(find.text('Female'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(GradientButton, 'Continue'));
    await pumpFrames(tester);
    expect(find.text('When were you born?'), findsOneWidget);

    await tester.tap(find.widgetWithText(GradientButton, 'Continue'));
    await pumpFrames(tester);
    expect(find.text('Your body'), findsOneWidget);
    await snapshot(find.byType(ProfileSetupScreen), 'setup_body');

    await tester.tap(find.text('Imperial (lb)'));
    await pumpFrames(tester);
    expect(find.text('in'), findsOneWidget);

    await tester.tap(find.widgetWithText(GradientButton, 'Continue'));
    await pumpFrames(tester);
    expect(find.text("What's the goal?"), findsOneWidget);
    expect(find.widgetWithText(GradientButton, "Let's lift"), findsOneWidget);
    await snapshot(find.byType(ProfileSetupScreen), 'setup_goal');
  });

  testWidgets('light theme renders', (tester) async {
    await pumpScreen(tester, const LoginScreen(), themeMode: ThemeMode.light);
    await pumpFrames(tester);
    await snapshot(find.byType(LoginScreen), 'login_light');
  });
}
