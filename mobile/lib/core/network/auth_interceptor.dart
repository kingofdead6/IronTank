import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Attaches the access token and silently refreshes it on `401 TOKEN_EXPIRED`.
///
/// It extends [QueuedInterceptor], so while one refresh is in flight other
/// failing requests wait and then replay with the new token, instead of each
/// triggering its own refresh (which would trip refresh-token reuse detection).
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.tokens,
    required this.refreshDio,
    required this.retryDio,
    required this.onSessionExpired,
  });

  final TokenStorage tokens;

  /// Bare client (no interceptors) used for the refresh call itself.
  final Dio refreshDio;

  /// Client used to replay the original request.
  final Dio retryDio;

  /// Called when the refresh token is invalid: the user must sign in again.
  final void Function() onSessionExpired;

  static const _retriedFlag = 'auth_retried';
  static const skipAuthFlag = 'skip_auth';

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[skipAuthFlag] != true) {
      final current = await tokens.read();
      if (current != null) options.headers['Authorization'] = 'Bearer ${current.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    final req = err.requestOptions;
    final isAuthFailure = response?.statusCode == 401 && req.extra[skipAuthFlag] != true;
    if (!isAuthFailure || req.extra[_retriedFlag] == true) return handler.next(err);

    final current = await tokens.read();
    if (current == null) return handler.next(err);

    // Another queued request may already have refreshed while this one waited.
    final sentWith = (req.headers['Authorization'] as String?)?.replaceFirst('Bearer ', '');
    if (sentWith != null && sentWith != current.accessToken) {
      return _retry(req, current.accessToken, handler);
    }

    final AuthTokens next;
    try {
      final res = await refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': current.refreshToken},
      );
      next = AuthTokens.fromJson(res.data!['tokens'] as Map<String, dynamic>);
      await tokens.save(next);
    } on DioException catch (refreshError) {
      // Only an explicit rejection ends the session; offline keeps it alive.
      if (refreshError.response?.statusCode == 401) {
        await tokens.clear();
        onSessionExpired();
      }
      return handler.next(err);
    }
    return _retry(req, next.accessToken, handler);
  }

  Future<void> _retry(RequestOptions req, String accessToken, ErrorInterceptorHandler handler) async {
    req.headers['Authorization'] = 'Bearer $accessToken';
    req.extra[_retriedFlag] = true;
    try {
      final response = await retryDio.fetch<dynamic>(req);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
