/// Application configuration. The API base URL is provided at build/run time via
/// --dart-define=API_BASE_URL=... (course requirement: config via String.fromEnvironment).
/// Default targets the host machine from the Android emulator (10.0.2.2 == host localhost).
class AppConfig {
  static String get serverBase => const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://10.0.2.2:5000',
      );

  static String get apiBase => '$serverBase/api/';
}
