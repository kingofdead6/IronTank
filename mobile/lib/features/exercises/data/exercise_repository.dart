import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import 'exercise.dart';

class ExerciseRepository {
  ExerciseRepository(this._api);

  final ApiClient _api;

  static const pageSize = 30;

  Future<Paginated<Exercise>> list(ExerciseFilters filters, {int page = 1, int limit = pageSize}) async =>
      Paginated.fromJson(
        await _api.get('/exercises', query: {...filters.toQuery(), 'page': page, 'limit': limit}),
        Exercise.fromJson,
      );

  Future<Exercise> get(String id) async =>
      Exercise.fromJson((await _api.get('/exercises/$id'))['exercise'] as Map<String, dynamic>);

  Future<ExerciseFilterOptions> filterOptions() async => ExerciseFilterOptions.fromJson(await _api.get('/exercises/filters'));

  Future<Exercise> createCustom(Map<String, dynamic> body) async =>
      Exercise.fromJson((await _api.post('/exercises', body: body))['exercise'] as Map<String, dynamic>);

  Future<Exercise> updateCustom(String id, Map<String, dynamic> body) async =>
      Exercise.fromJson((await _api.patch('/exercises/$id', body: body))['exercise'] as Map<String, dynamic>);

  Future<void> deleteCustom(String id) => _api.delete('/exercises/$id');

  /// Current bests plus the first page of record history.
  Future<({ExerciseBests bests, List<RecordEvent> history})> records(String id) async {
    final res = await _api.get('/prs/$id', query: {'limit': 50});
    final history = res['history'] as Map<String, dynamic>;
    return (
      bests: ExerciseBests.fromJson(res['current'] as Map<String, dynamic>),
      history: (history['data'] as List<dynamic>).map((e) => RecordEvent.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  /// Per-session history (newest first from the API; returned oldest first for charts).
  Future<List<ExerciseHistoryPoint>> history(String id, {int limit = 100}) async {
    final res = await _api.get('/stats/exercise/$id', query: {'limit': limit});
    return (res['data'] as List<dynamic>)
        .map((e) => ExerciseHistoryPoint.fromJson(e as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
  }
}

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) => ExerciseRepository(ref.watch(apiClientProvider)));
