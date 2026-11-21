import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/features/auth/application/session_controller.dart';
import 'package:plasmobile/shared/widgets/owl_bracket_mascot.dart';
import 'package:plasmobile/shared/widgets/plas_state_views.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(sessionControllerProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final bootstrapError = session.bootstrapError;

    return Scaffold(
      backgroundColor: PlasColors.bgCanvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PlasSpacing.space6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: PlasAppLogo(
                      size: 64,
                      semanticLabel: 'Logo PLAS-TypeScript',
                    ),
                  ),
                  const SizedBox(height: PlasSpacing.space4),
                  const Text(
                    'PLAS-TypeScript',
                    style: PlasTypography.display,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: PlasSpacing.space1),
                  const Text(
                    'CS LAB ENV // MOBILE',
                    style: PlasTypography.codeMeta,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: PlasSpacing.space6),
                  if (bootstrapError == null) ...[
                    const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: PlasColors.brandPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: PlasSpacing.space3),
                    const Text(
                      'Memeriksa sesi belajar...',
                      style: PlasTypography.body,
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    PlasErrorView(
                      title: 'Gagal Memeriksa Sesi',
                      message: bootstrapError,
                      actionLabel: 'Coba Lagi',
                      onRetry: session.isBusy
                          ? null
                          : () => ref
                              .read(sessionControllerProvider.notifier)
                              .bootstrap(),
                    ),
                    const SizedBox(height: PlasSpacing.space3),
                    OutlinedButton(
                      onPressed: session.isBusy
                          ? null
                          : () => ref
                              .read(sessionControllerProvider.notifier)
                              .signOut(),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Symbols.logout, size: 20),
                          SizedBox(width: PlasSpacing.space2),
                          Flexible(
                            child: Text(
                              'Keluar',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
