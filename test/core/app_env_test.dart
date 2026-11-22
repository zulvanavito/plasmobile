import 'package:flutter_test/flutter_test.dart';
import 'package:plasmobile/core/config/app_env.dart';

void main() {
  group('AppEnv', () {
    test('exposes expected default mock values', () {
      expect(AppEnv.useMock, isTrue);
      expect(AppEnv.apiBaseUrl, 'http://10.0.2.2:3000/api');
      expect(AppEnv.hasSupabaseConfig, isFalse);
    });

    test('missingLiveConfigKeys reports missing or blank required live keys', () {
      expect(
        AppEnv.missingLiveConfigKeys(
          apiBaseUrlOverride: '',
          supabaseUrlOverride: '   ',
          supabaseAnonKeyOverride: '',
        ),
        <String>['API_BASE_URL', 'SUPABASE_URL', 'SUPABASE_ANON_KEY'],
      );

      expect(
        AppEnv.missingLiveConfigKeys(
          apiBaseUrlOverride: 'https://api.plas.ac.id/api',
          supabaseUrlOverride: 'https://proj.supabase.co',
          supabaseAnonKeyOverride: '',
        ),
        <String>['SUPABASE_ANON_KEY'],
      );
    });

    test('missingLiveConfigKeys returns empty list when required keys are set', () {
      final missing = AppEnv.missingLiveConfigKeys(
        apiBaseUrlOverride: 'http://10.0.2.2:3000/api',
        supabaseUrlOverride: 'https://proj.supabase.co',
        supabaseAnonKeyOverride: 'anon-key-value',
      );

      expect(missing, isEmpty);
    });
  });
}
