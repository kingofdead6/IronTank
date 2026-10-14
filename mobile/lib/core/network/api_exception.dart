import 'package:dio/dio.dart';

/// Normalised API failure. The backend always answers errors with
/// `{ error: { code, message, details? } }`; transport failures get synthetic codes.
class ApiException implements Exception {
  const ApiException({required this.code, required this.message, this.statusCode, this.details});

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      return ApiException(
        code: err['code'] as String? ?? 'UNKNOWN',
        message: err['message'] as String? ?? 'Something went wrong',
        statusCode: e.response?.statusCode,
        details: err['details'],
      );
    }
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const ApiException(code: networkCode, message: 'The server took too long to respond'),
      DioExceptionType.connectionError => const ApiException(code: networkCode, message: "Can't reach the server. Check your connection."),
      DioExceptionType.cancel => const ApiException(code: 'CANCELLED', message: 'Request cancelled'),
      _ => ApiException(
        code: 'UNKNOWN',
        message: 'Something went wrong',
        statusCode: e.response?.statusCode,
      ),
    };
  }

  static const networkCode = 'NETWORK_ERROR';

  final String code;
  final String message;
  final int? statusCode;
  final Object? details;

  bool get isNetwork => code == networkCode;
  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;

  /// First validation message for a field path like `body.email`, if any.
  String? fieldError(String path) {
    final d = details;
    if (d is! List) return null;
    for (final item in d) {
      if (item is Map && item['path'] == path) return item['message'] as String?;
    }
    return null;
  }

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}

/// Converts any thrown object into a user-presentable message.
String describeError(Object error) => switch (error) {
  final ApiException e => e.message,
  final DioException e => ApiException.fromDio(e).message,
  _ => 'Something went wrong',
};
