abstract final class AppConfig {
  static const String _configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );
  static const bool previewMode = bool.fromEnvironment('PREVIEW_MODE');

  static String get apiBaseUrl =>
      _configuredApiBaseUrl.replaceFirst(RegExp(r'/$'), '');
}
