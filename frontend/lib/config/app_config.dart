abstract final class AppConfig {
  static const String _configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static String get apiBaseUrl =>
      _configuredApiBaseUrl.replaceFirst(RegExp(r'/$'), '');
}
