import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// Public browser configuration; authentication/authorization stays in the backend.
class RuntimeConfig {
  const RuntimeConfig({
    required this.apiBaseUrl,
    required this.googleClientId,
    required this.previewMode,
  });

  factory RuntimeConfig.fromJson(Map<String, dynamic> json) {
    if (json['apiBaseUrl'] is! String ||
        json['googleClientId'] is! String ||
        json['previewMode'] is! bool) {
      throw const FormatException('Invalid runtime configuration');
    }
    return RuntimeConfig(
      apiBaseUrl: json['apiBaseUrl'] as String,
      googleClientId: json['googleClientId'] as String,
      previewMode: json['previewMode'] as bool,
    );
  }

  final String apiBaseUrl;
  final String googleClientId;
  final bool previewMode;
}

abstract final class AppConfig {
  static RuntimeConfig? _runtime;

  /// Only CI web builds require a runtime config. APKs and flutter run keep
  /// their existing --dart-define values. Missing/invalid config fails closed.
  static Future<void> initialize() async {
    if (!kIsWeb || !const bool.fromEnvironment('RUNTIME_CONFIG')) return;
    final response = await http.get(
      Uri.base.resolve('runtime-config/config.json'),
      headers: {'Cache-Control': 'no-cache'},
    );
    if (response.statusCode != 200) {
      throw StateError('Runtime configuration unavailable');
    }
    _runtime = RuntimeConfig.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static String get apiBaseUrl =>
      (_runtime?.apiBaseUrl ??
              const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: 'http://localhost:8080',
              ))
          .replaceFirst(RegExp(r'/$'), '');

  static String get googleClientId =>
      _runtime?.googleClientId ??
      const String.fromEnvironment('GOOGLE_CLIENT_ID');

  static bool get previewMode =>
      _runtime?.previewMode ?? const bool.fromEnvironment('PREVIEW_MODE');
}
