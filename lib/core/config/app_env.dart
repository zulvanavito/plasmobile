abstract final class AppEnv {
  static const bool useMock = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: true,
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api',
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static List<String> missingLiveConfigKeys({
    String? apiBaseUrlOverride,
    String? supabaseUrlOverride,
    String? supabaseAnonKeyOverride,
  }) {
    final effectiveApi = (apiBaseUrlOverride ?? apiBaseUrl).trim();
    final effectiveSupabaseUrl = (supabaseUrlOverride ?? supabaseUrl).trim();
    final effectiveAnonKey =
        (supabaseAnonKeyOverride ?? supabaseAnonKey).trim();
    final missing = <String>[];
    if (effectiveApi.isEmpty) missing.add('API_BASE_URL');
    if (effectiveSupabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (effectiveAnonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
    return List<String>.unmodifiable(missing);
  }
}
