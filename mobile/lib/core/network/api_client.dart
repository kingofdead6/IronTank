import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

/// Fires when the server rejects our refresh token; the auth controller listens
/// and signs the user out.
class SessionExpiredNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void expire() => state++;
}

final sessionExpiredProvider = NotifierProvider<SessionExpiredNotifier, int>(SessionExpiredNotifier.new);

/// Typed wrapper around Dio that always throws [ApiException] on failure.
class ApiClient {
  ApiClient(this.dio);

  final Dio dio;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => dio.get<dynamic>(path, queryParameters: _clean(query)));

  Future<Map<String, dynamic>> post(String path, {Object? body, bool auth = true}) =>
      _send(() => dio.post<dynamic>(path, data: body, options: _opts(auth)));

  Future<Map<String, dynamic>> put(String path, {Object? body}) =>
      _send(() => dio.put<dynamic>(path, data: body));

  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      _send(() => dio.patch<dynamic>(path, data: body));

  Future<Map<String, dynamic>> delete(String path, {Map<String, dynamic>? query}) =>
      _send(() => dio.delete<dynamic>(path, queryParameters: _clean(query)));

  Options? _opts(bool auth) => auth ? null : Options(extra: {AuthInterceptor.skipAuthFlag: true});

  /// Drops nulls and joins lists so `{muscle: [a, b]}` becomes `muscle=a,b`.
  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final out = <String, dynamic>{};
    query.forEach((k, v) {
      if (v == null) return;
      if (v is Iterable) {
        if (v.isEmpty) return;
        out[k] = v.join(',');
      } else {
        out[k] = v;
      }
    });
    return out;
  }

  Future<Map<String, dynamic>> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final res = await request();
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      return const {};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final tokens = ref.watch(tokenStorageProvider);

  BaseOptions options() => BaseOptions(
    baseUrl: config.apiBaseUrl,
    connectTimeout: config.connectTimeout,
    receiveTimeout: config.receiveTimeout,
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
  );

  final dio = Dio(options());
  final bare = Dio(options());
  dio.interceptors.add(
    AuthInterceptor(
      tokens: tokens,
      refreshDio: bare,
      retryDio: bare,
      onSessionExpired: () => ref.read(sessionExpiredProvider.notifier).expire(),
    ),
  );
  return ApiClient(dio);
});
