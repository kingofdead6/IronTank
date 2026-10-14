import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/storage/token_storage.dart';
import 'user.dart';

/// Talks to `/auth/*` and `/users/me`, keeps tokens in secure storage and the
/// last known profile in the local cache (so the app opens offline).
class AuthRepository {
  AuthRepository(this._api, this._tokens, this._store);

  final ApiClient _api;
  final TokenStorage _tokens;
  final LocalStore _store;

  static const _userCacheKey = 'me';

  Future<bool> hasSession() async => await _tokens.read() != null;

  User? cachedUser() {
    final json = _store.readJson(_userCacheKey);
    return json == null ? null : User.fromJson(json);
  }

  Future<User> _persistSession(Map<String, dynamic> res) async {
    await _tokens.save(AuthTokens.fromJson(res['tokens'] as Map<String, dynamic>));
    return _cache(User.fromJson(res['user'] as Map<String, dynamic>));
  }

  Future<User> _cache(User user) async {
    await _store.writeJson(_userCacheKey, user.toJson());
    return user;
  }

  Future<User> login({required String email, required String password}) async =>
      _persistSession(await _api.post('/auth/login', body: {'email': email, 'password': password}, auth: false));

  Future<User> register({required String email, required String password, required String username}) async =>
      _persistSession(
        await _api.post(
          '/auth/register',
          body: {'email': email, 'password': password, 'username': username},
          auth: false,
        ),
      );

  Future<String> forgotPassword(String email) async {
    final res = await _api.post('/auth/forgot-password', body: {'email': email}, auth: false);
    return res['message'] as String? ?? 'Check your inbox.';
  }

  Future<User> fetchMe() async {
    final res = await _api.get('/users/me');
    return _cache(User.fromJson(res['user'] as Map<String, dynamic>));
  }

  Future<User> updateProfile(ProfileUpdate update) async {
    final res = await _api.patch('/users/me', body: update.toJson());
    return _cache(User.fromJson(res['user'] as Map<String, dynamic>));
  }

  /// Best-effort server logout; local state is always cleared.
  Future<void> logout() async {
    final tokens = await _tokens.read();
    try {
      if (tokens != null) {
        await _api.post('/auth/logout', body: {'refreshToken': tokens.refreshToken}, auth: false);
      }
    } on Exception {
      // Offline or already revoked: nothing else to do server-side.
    }
    await clearLocal();
  }

  Future<void> clearLocal() async {
    await _tokens.clear();
    await _store.clearUserData();
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider), ref.watch(localStoreProvider)),
);
