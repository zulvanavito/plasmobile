import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plasmobile/core/router/app_router.dart';
import 'package:plasmobile/core/theme/plas_theme.dart';

class PlasApp extends ConsumerWidget {
  const PlasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'PLAS-TypeScript',
      debugShowCheckedModeBanner: false,
      theme: buildPlasTheme(),
      routerConfig: router,
    );
  }
}
