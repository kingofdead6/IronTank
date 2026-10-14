import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrank/core/network/api_exception.dart';
import 'package:ironrank/core/router/app_router.dart';
import 'package:ironrank/core/router/routes.dart';
import 'package:ironrank/core/utils/formatters.dart';
import 'package:ironrank/core/utils/units.dart';
import 'package:ironrank/features/auth/application/auth_controller.dart';
import 'package:ironrank/features/auth/data/user.dart';

void main() {
  group('Units', () {
    test('converts kg ↔ lb', () {
      expect(Units.fromKg(100, WeightUnit.lb), closeTo(220.46, 0.01));
      expect(Units.toKg(225, WeightUnit.lb), closeTo(102.06, 0.01));
      expect(Units.fromKg(100, WeightUnit.kg), 100);
    });

    test('formats numbers without trailing zeros', () {
      expect(Units.formatNumber(102.5), '102.5');
      expect(Units.formatNumber(100.0), '100');
      expect(Units.weight(100, WeightUnit.kg), '100 kg');
      expect(Units.weight(100, WeightUnit.lb), '220.5 lb');
    });

    test('compacts large volumes', () {
      expect(Units.volume(12450, WeightUnit.kg), '12.5k');
      expect(Units.volume(950, WeightUnit.kg), '950');
    });
  });

  group('Fmt', () {
    test('formats timers', () {
      expect(Fmt.clock(const Duration(seconds: 65)), '1:05');
      expect(Fmt.clock(const Duration(hours: 1, minutes: 2, seconds: 5)), '1:02:05');
      expect(Fmt.duration(const Duration(minutes: 65)), '1h 05m');
    });

    test('relative days', () {
      final now = DateTime(2026, 10, 13, 12);
      expect(Fmt.relativeDay(DateTime(2026, 10, 13, 8), now: now), 'Today');
      expect(Fmt.relativeDay(DateTime(2026, 10, 12, 23), now: now), 'Yesterday');
      expect(Fmt.relativeDay(DateTime(2026, 10, 10), now: now), '3 days ago');
    });
  });

  group('ApiException', () {
    test('parses the backend error envelope', () {
      final e = ApiException.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 422,
            data: {
              'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'Request validation failed',
                'details': [
                  {'path': 'body.email', 'message': 'Invalid email'},
                ],
              },
            },
          ),
        ),
      );
      expect(e.code, 'VALIDATION_ERROR');
      expect(e.statusCode, 422);
      expect(e.fieldError('body.email'), 'Invalid email');
      expect(e.fieldError('body.password'), isNull);
    });

    test('maps connection failures to NETWORK_ERROR', () {
      final e = ApiException.fromDio(
        DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError),
      );
      expect(e.isNetwork, isTrue);
    });
  });

  group('authRedirect', () {
    const user = User(id: '1', email: 'a@b.dev', username: 'a', onboardingComplete: true);
    const fresh = User(id: '1', email: 'a@b.dev', username: 'a');

    test('holds on splash while the session is restored', () {
      expect(authRedirect(auth: const AuthState.unknown(), onboardingSeen: true, location: Routes.home), Routes.splash);
    });

    test('sends new visitors to onboarding, returning ones to login', () {
      const out = AuthState.signedOut();
      expect(authRedirect(auth: out, onboardingSeen: false, location: Routes.splash), Routes.onboarding);
      expect(authRedirect(auth: out, onboardingSeen: true, location: Routes.splash), Routes.login);
      expect(authRedirect(auth: out, onboardingSeen: true, location: Routes.home), Routes.login);
      expect(authRedirect(auth: out, onboardingSeen: true, location: Routes.register), isNull);
    });

    test('forces profile setup until onboarding is complete', () {
      expect(authRedirect(auth: const AuthState.signedIn(fresh), onboardingSeen: true, location: Routes.home), Routes.setup);
      expect(authRedirect(auth: const AuthState.signedIn(fresh), onboardingSeen: true, location: Routes.setup), isNull);
    });

    test('keeps signed-in users out of auth screens', () {
      expect(authRedirect(auth: const AuthState.signedIn(user), onboardingSeen: true, location: Routes.login), Routes.home);
      expect(authRedirect(auth: const AuthState.signedIn(user), onboardingSeen: true, location: Routes.setup), Routes.home);
      expect(authRedirect(auth: const AuthState.signedIn(user), onboardingSeen: true, location: Routes.ranks), isNull);
    });
  });

  group('User', () {
    test('round-trips JSON and maps enums', () {
      final u = User.fromJson({
        'id': 'x',
        'email': 'e@x.dev',
        'username': 'lifter',
        'sex': 'female',
        'unit': 'lb',
        'activityLevel': 'very_active',
        'goal': 'bulk',
        'bodyweightKg': 61.5,
        'onboardingComplete': true,
      });
      expect(u.sex, Sex.female);
      expect(u.unit, WeightUnit.lb);
      expect(u.activityLevel, ActivityLevel.veryActive);
      expect(User.fromJson(u.toJson()).activityLevel.apiValue, 'very_active');
    });

    test('ProfileUpdate omits null fields', () {
      final json = const ProfileUpdate(goal: Goal.cut, bodyweightKg: 80).toJson();
      expect(json, {'goal': 'cut', 'bodyweightKg': 80.0});
    });
  });
}
