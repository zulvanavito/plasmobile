import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plasmobile/app.dart';
import 'package:plasmobile/core/config/app_env.dart';
import 'package:plasmobile/core/sync/pending_sync_queue.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: PlasColors.bgSurface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  final prefs = await SharedPreferences.getInstance();

  if (!AppEnv.useMock) {
    final missingKeys = AppEnv.missingLiveConfigKeys();
    if (missingKeys.isNotEmpty) {
      throw StateError(
        'Konfigurasi live belum lengkap saat USE_MOCK=false. '
        'Tambahkan --dart-define atau --dart-define-from-file=env.live.json untuk key: '
        '${missingKeys.join(', ')}.',
      );
    }
    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      anonKey: AppEnv.supabaseAnonKey,
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const PlasApp(),
    ),
  );
}
