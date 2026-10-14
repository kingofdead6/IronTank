import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runtime configuration read from `assets/config/app_config.json`.
///
/// Defaults to the deployed API. For a local backend, override at build time:
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1`
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.connectTimeout,
    required this.receiveTimeout,
  });

  /// Production API (Render). Used if the config asset is missing.
  static const defaultApiBaseUrl = 'https://irontank.onrender.com/api/v1';
  static const _assetPath = 'assets/config/app_config.json';
  static const _dartDefineUrl = String.fromEnvironment('API_BASE_URL');

  final String apiBaseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  static Future<AppConfig> load() async {
    Map<String, dynamic> json = const {};
    try {
      json = jsonDecode(await rootBundle.loadString(_assetPath)) as Map<String, dynamic>;
    } on Exception {
      // Missing/invalid file: fall back to defaults below.
    }
    final fromFile = json['apiBaseUrl'] as String?;
    return AppConfig(
      apiBaseUrl: _dartDefineUrl.isNotEmpty ? _dartDefineUrl : (fromFile ?? defaultApiBaseUrl),
      // Render's free tier sleeps when idle; the first request can take ~60 s to wake it.
      connectTimeout: Duration(seconds: (json['connectTimeoutSeconds'] as num?)?.toInt() ?? 30),
      receiveTimeout: Duration(seconds: (json['receiveTimeoutSeconds'] as num?)?.toInt() ?? 75),
    );
  }
}

/// Overridden in `main()` with the loaded config.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden in main()'),
);
