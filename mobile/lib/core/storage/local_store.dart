import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Minimal string key/value bucket. Backed by a Hive box in the app and by a
/// plain map in tests (Hive's file I/O can't complete inside widget tests'
/// fake-async zone).
abstract interface class KeyValueBucket {
  String? get(String key);
  Iterable<String> get keys;
  Future<void> put(String key, String value);
  Future<void> delete(String key);
  Future<void> clear();
}

class _HiveBucket implements KeyValueBucket {
  _HiveBucket(this._box);

  final Box<String> _box;

  @override
  String? get(String key) => _box.get(key);
  @override
  Iterable<String> get keys => _box.keys.whereType<String>();
  @override
  Future<void> put(String key, String value) => _box.put(key, value);
  @override
  Future<void> delete(String key) => _box.delete(key);
  @override
  Future<void> clear() => _box.clear();
}

class _MemoryBucket implements KeyValueBucket {
  final _data = <String, String>{};

  @override
  String? get(String key) => _data[key];
  @override
  Iterable<String> get keys => _data.keys.toList();
  @override
  Future<void> put(String key, String value) async => _data[key] = value;
  @override
  Future<void> delete(String key) async => _data.remove(key);
  @override
  Future<void> clear() async => _data.clear();
}

/// Local persistence: device settings, an API response cache and the active
/// workout. Values are JSON strings, so models need no generated adapters.
class LocalStore {
  LocalStore._(this._settings, this._cache, this._workout);

  /// Volatile store for tests.
  factory LocalStore.memory() => LocalStore._(_MemoryBucket(), _MemoryBucket(), _MemoryBucket());

  static const _settingsBox = 'settings';
  static const _cacheBox = 'cache';
  static const _workoutBox = 'active_workout';

  final KeyValueBucket _settings;
  final KeyValueBucket _cache;
  final KeyValueBucket _workout;

  /// Opens the Hive boxes in the app documents directory, or in [path] (tests).
  static Future<LocalStore> open({String? path}) async {
    if (path != null) {
      Hive.init(path);
    } else {
      await Hive.initFlutter('ironrank');
    }
    final boxes = await Future.wait([
      Hive.openBox<String>(_settingsBox),
      Hive.openBox<String>(_cacheBox),
      Hive.openBox<String>(_workoutBox),
    ]);
    return LocalStore._(_HiveBucket(boxes[0]), _HiveBucket(boxes[1]), _HiveBucket(boxes[2]));
  }

  // ---- Settings (small key/value preferences) -----------------------------

  String? getSetting(String key) => _settings.get(key);
  Future<void> setSetting(String key, String? value) =>
      value == null ? _settings.delete(key) : _settings.put(key, value);

  bool getBool(String key, {bool fallback = false}) => switch (_settings.get(key)) {
    'true' => true,
    'false' => false,
    _ => fallback,
  };
  Future<void> setBool(String key, bool value) => _settings.put(key, value.toString());

  // ---- JSON cache (last known API responses for offline display) ----------

  Map<String, dynamic>? readJson(String key) {
    final raw = _cache.get(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  Future<void> writeJson(String key, Map<String, dynamic> value) => _cache.put(key, jsonEncode(value));
  Future<void> deleteJson(String key) => _cache.delete(key);

  // ---- Active workout (survives app restarts) -----------------------------

  static const _activeKey = 'session';
  static const _pendingPrefix = 'pending:';

  Map<String, dynamic>? readActiveWorkout() {
    final raw = _workout.get(_activeKey);
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> writeActiveWorkout(Map<String, dynamic> session) => _workout.put(_activeKey, jsonEncode(session));
  Future<void> clearActiveWorkout() => _workout.delete(_activeKey);

  /// Finished workouts waiting to be uploaded (offline), keyed by clientId.
  List<Map<String, dynamic>> pendingWorkouts() => _workout.keys
      .where((k) => k.startsWith(_pendingPrefix))
      .map((k) => jsonDecode(_workout.get(k)!) as Map<String, dynamic>)
      .toList();

  Future<void> addPendingWorkout(String clientId, Map<String, dynamic> payload) =>
      _workout.put('$_pendingPrefix$clientId', jsonEncode(payload));
  Future<void> removePendingWorkout(String clientId) => _workout.delete('$_pendingPrefix$clientId');

  /// Wipes user-specific data on logout (keeps device settings like theme).
  Future<void> clearUserData() async {
    await _cache.clear();
    await _workout.clear();
  }
}

/// Overridden in `main()` with the opened store.
final localStoreProvider = Provider<LocalStore>(
  (ref) => throw UnimplementedError('localStoreProvider must be overridden in main()'),
);
