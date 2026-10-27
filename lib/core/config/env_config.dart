/// Runtime configuration pulled from `--dart-define-from-file`.
///
/// Credentials are never hardcoded here. Run with:
///   flutter run --dart-define-from-file=env/dev.json
/// See env/dev.json.example for the expected keys.
class EnvConfig {
  const EnvConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
