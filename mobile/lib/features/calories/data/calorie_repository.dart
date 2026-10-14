import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'calorie_models.dart';

class CalorieRepository {
  CalorieRepository(this._api);

  final ApiClient _api;

  Future<CalorieDay> day(String date, String tz) async =>
      CalorieDay.fromJson(await _api.get('/calories', query: {'date': date, 'tz': tz}));

  Future<CalorieDay> addEntry({
    required String date,
    required String tz,
    required String name,
    required double kcal,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
  }) async => CalorieDay.fromJson(
    await _api.post(
      '/calories/entries',
      body: {'date': date, 'tz': tz, 'name': name, 'kcal': kcal, 'protein': protein, 'carbs': carbs, 'fat': fat},
    ),
  );

  Future<void> deleteEntry(String id) => _api.delete('/calories/entries/$id');

  Future<CalorieTarget> target() async => CalorieTarget.fromJson(await _api.get('/calories/target'));

  /// Sets a manual target ([clearCustom] restores the TDEE recommendation) and/or a goal.
  Future<CalorieTarget> setTarget({int? targetKcal, bool clearCustom = false, String? goal, String? date}) async =>
      CalorieTarget.fromJson(
        await _api.put(
          '/calories/target',
          body: {
            if (clearCustom) 'targetKcal': null else 'targetKcal': ?targetKcal,
            'goal': ?goal,
            'date': ?date,
          },
        ),
      );
}

final calorieRepositoryProvider = Provider<CalorieRepository>((ref) => CalorieRepository(ref.watch(apiClientProvider)));
