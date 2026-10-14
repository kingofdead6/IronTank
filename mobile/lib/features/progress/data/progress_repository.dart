import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/local_store.dart';
import '../../exercises/data/exercise.dart';
import 'progress_models.dart';

/// Read side of training history: stats, ranks, PRs, bodyweight.
/// Last good responses are cached so the dashboard opens offline.
class ProgressRepository {
  ProgressRepository(this._api, this._store);

  final ApiClient _api;
  final LocalStore _store;

  /// Fetches JSON, caching it; falls back to the cache when the request fails.
  Future<Map<String, dynamic>> _cached(String key, Future<Map<String, dynamic>> Function() fetch) async {
    try {
      final json = await fetch();
      await _store.writeJson(key, json);
      return json;
    } on Exception {
      final cached = _store.readJson(key);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<StatsOverview> overview({required int weeks, required String tz}) async => StatsOverview.fromJson(
    await _cached('overview:$weeks', () => _api.get('/stats/overview', query: {'weeks': weeks, 'tz': tz})),
  );

  Future<Ranks> ranks() async => Ranks.fromJson(await _cached('ranks', () => _api.get('/ranks')));

  /// Latest celebrated PRs across all exercises.
  Future<List<RecordEvent>> latestRecords({int limit = 10}) async {
    final res = await _cached('prs', () => _api.get('/prs', query: {'limit': limit}));
    return (res['data'] as List<dynamic>).map((e) => RecordEvent.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Bodyweight entries, oldest first (for charts).
  Future<List<BodyweightEntry>> bodyweight({int limit = 100}) async {
    final res = await _api.get('/users/me/bodyweight', query: {'limit': limit});
    return (res['data'] as List<dynamic>)
        .map((e) => BodyweightEntry.fromJson(e as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
  }

  Future<void> addBodyweight(double kg, {DateTime? date}) =>
      _api.post('/users/me/bodyweight', body: {'kg': double.parse(kg.toStringAsFixed(2)), 'date': ?date?.toUtc().toIso8601String()});

  Future<void> deleteBodyweight(String id) => _api.delete('/users/me/bodyweight/$id');
}

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(ref.watch(apiClientProvider), ref.watch(localStoreProvider)),
);
