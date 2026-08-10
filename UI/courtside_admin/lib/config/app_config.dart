/// Application configuration. The API base URL is provided at build/run time via
/// --dart-define=API_BASE_URL=... (course requirement: config via String.fromEnvironment).
/// Default targets the API running on the same machine as the desktop app.
class AppConfig {
  static String get serverBase => const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:5000',
      );

  static String get apiBase => '$serverBase/api/';
}
