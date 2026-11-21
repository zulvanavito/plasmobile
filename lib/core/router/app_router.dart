import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plasmobile/core/router/app_routes.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/features/auth/presentation/auth_screen.dart';
import 'package:plasmobile/features/auth/presentation/onboarding_class_screen.dart';
import 'package:plasmobile/features/auth/presentation/onboarding_identity_screen.dart';
import 'package:plasmobile/features/auth/presentation/splash_screen.dart';
import 'package:plasmobile/features/learn/presentation/learn_home_screen.dart';
import 'package:plasmobile/features/learn/presentation/material_detail_screen.dart';
import 'package:plasmobile/features/learn/presentation/submaterial_read_screen.dart';
import 'package:plasmobile/shared/widgets/plas_bottom_nav.dart';

enum AuthGateStatus {
  loading,
  unauthenticated,
  needsIdentity,
  needsClass,
  authenticated,
}

final authGateStatusProvider = StateProvider<AuthGateStatus>(
  (ref) => AuthGateStatus.loading,
);

String? computeAuthRedirect(AuthGateStatus status, String location) {
  switch (status) {
    case AuthGateStatus.loading:
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case AuthGateStatus.unauthenticated:
      return location == AppRoutes.auth ? null : AppRoutes.auth;
    case AuthGateStatus.needsIdentity:
      return location == AppRoutes.onboardingIdentity
          ? null
          : AppRoutes.onboardingIdentity;
    case AuthGateStatus.needsClass:
      return location == AppRoutes.onboardingClass
          ? null
          : AppRoutes.onboardingClass;
    case AuthGateStatus.authenticated:
      const authOnlyRoutes = {
        '/',
        AppRoutes.splash,
        AppRoutes.auth,
        AppRoutes.onboardingIdentity,
        AppRoutes.onboardingClass,
      };
      if (authOnlyRoutes.contains(location)) {
        return AppRoutes.learn;
      }
      return null;
  }
}

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen<AuthGateStatus>(authGateStatusProvider, (_, _) {
    refreshNotifier.refresh();
  });

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final status = ref.read(authGateStatusProvider);
      return computeAuthRedirect(status, state.matchedLocation);
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingIdentity,
        builder: (context, state) => const OnboardingIdentityScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingClass,
        builder: (context, state) => const OnboardingClassScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _AppShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.learn,
                builder: (context, state) => const LearnHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (context, state) => const _StagePlaceholderScreen(
                  code: 'M14',
                  title: 'Riwayat Latihan & Tes',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const _StagePlaceholderScreen(
                  code: 'M15',
                  title: 'Profil & Kelas Mahasiswa',
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/materials/:materialId',
        builder: (context, state) => MaterialDetailScreen(
          materialId: state.pathParameters['materialId']!,
        ),
      ),
      GoRoute(
        path: '/sub-materials/:submaterialId',
        builder: (context, state) => SubMaterialReadScreen(
          submaterialId: state.pathParameters['submaterialId']!,
        ),
      ),
      GoRoute(
        path: '/exercises/:exerciseId/session',
        builder: (context, state) => _StagePlaceholderScreen(
          code: 'M08',
          title: 'Sesi Latihan (${state.pathParameters['exerciseId']})',
        ),
      ),
      GoRoute(
        path: '/exercise-attempts/:attemptId/review',
        builder: (context, state) => _StagePlaceholderScreen(
          code: 'M13',
          title: 'Review Latihan (${state.pathParameters['attemptId']})',
        ),
      ),
      GoRoute(
        path: '/tests/:testId/session',
        builder: (context, state) => _StagePlaceholderScreen(
          code: 'M10',
          title: 'Sesi Pre/Post-Test (${state.pathParameters['testId']})',
        ),
      ),
      GoRoute(
        path: '/test-attempts/:attemptId/result',
        builder: (context, state) => _StagePlaceholderScreen(
          code: 'M12',
          title: 'Hasil Evaluasi (${state.pathParameters['attemptId']})',
        ),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refreshNotifier.dispose();
  });

  return router;
});

class _AppShellScaffold extends StatelessWidget {
  const _AppShellScaffold({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: PlasBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

class _StagePlaceholderScreen extends StatelessWidget {
  const _StagePlaceholderScreen({
    required this.code,
    required this.title,
  });

  final String code;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PlasColors.bgCanvas,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(PlasSpacing.space6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PlasSpacing.space3,
                    vertical: PlasSpacing.space1,
                  ),
                  decoration: BoxDecoration(
                    color: PlasColors.brandTint,
                    borderRadius: BorderRadius.circular(PlasRadii.sm),
                  ),
                  child: Text(code, style: PlasTypography.codeMeta),
                ),
                const SizedBox(height: PlasSpacing.space3),
                Text(
                  title,
                  style: PlasTypography.heading,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: PlasSpacing.space2),
                Text(
                  'Tahap 4: Layar ini belum diimplementasikan.',
                  style: PlasTypography.body,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
