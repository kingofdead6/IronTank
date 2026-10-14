import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import '../../../core/storage/local_store.dart';
import 'program.dart';

enum ProgramScope { mine, templates }

class ProgramRepository {
  ProgramRepository(this._api, this._store);

  final ApiClient _api;
  final LocalStore _store;

  static const _activeCacheKey = 'activeProgram';

  Program _program(Map<String, dynamic> res) => Program.fromJson(res['program'] as Map<String, dynamic>);

  Future<List<Program>> list(ProgramScope scope) async {
    final page = Paginated.fromJson(
      await _api.get('/programs', query: {'scope': scope.name, 'limit': 100}),
      Program.fromJson,
    );
    return page.items;
  }

  Future<Program> get(String id) async => _program(await _api.get('/programs/$id'));

  Future<Program> create({required String name, required String description, required int weeks, required List<ProgramDay> days}) async =>
      _program(
        await _api.post(
          '/programs',
          body: {'name': name, 'description': description, 'weeks': weeks, 'days': days.map((d) => d.toApi()).toList()},
        ),
      );

  Future<Program> update(String id, {required String name, required String description, required int weeks, required List<ProgramDay> days}) async =>
      _program(
        await _api.patch(
          '/programs/$id',
          body: {'name': name, 'description': description, 'weeks': weeks, 'days': days.map((d) => d.toApi()).toList()},
        ),
      );

  Future<void> delete(String id) => _api.delete('/programs/$id');

  Future<Program> clone(String id) async => _program(await _api.post('/programs/$id/clone'));

  Future<Program> activate(String id) async => _program(await _api.post('/programs/$id/activate'));

  Future<void> deactivate() => _api.delete('/programs/active');

  /// Active program + next day; falls back to the last cached copy offline.
  Future<ActiveProgram> active() async {
    try {
      final res = await _api.get('/programs/active');
      await _store.writeJson(_activeCacheKey, res);
      return ActiveProgram.fromJson(res);
    } on Exception {
      final cached = _store.readJson(_activeCacheKey);
      if (cached != null) return ActiveProgram.fromJson(cached);
      rethrow;
    }
  }
}

final programRepositoryProvider = Provider<ProgramRepository>(
  (ref) => ProgramRepository(ref.watch(apiClientProvider), ref.watch(localStoreProvider)),
);
