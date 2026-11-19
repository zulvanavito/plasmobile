import 'package:flutter_test/flutter_test.dart';
import 'package:plasmobile/core/router/app_router.dart';
import 'package:plasmobile/core/router/app_routes.dart';

void main() {
  group('computeAuthRedirect (4-stage auth & onboarding guard)', () {
    const locations = [
      AppRoutes.splash,
      AppRoutes.auth,
      AppRoutes.onboardingIdentity,
      AppRoutes.onboardingClass,
      AppRoutes.learn,
    ];

    test('loading keeps only /splash', () {
      for (final loc in locations) {
        expect(
          computeAuthRedirect(AuthGateStatus.loading, loc),
          loc == AppRoutes.splash ? null : AppRoutes.splash,
        );
      }
    });

    test('unauthenticated keeps only /auth', () {
      for (final loc in locations) {
        expect(
          computeAuthRedirect(AuthGateStatus.unauthenticated, loc),
          loc == AppRoutes.auth ? null : AppRoutes.auth,
        );
      }
    });

    test('needsIdentity keeps only /onboarding/identity', () {
      for (final loc in locations) {
        expect(
          computeAuthRedirect(AuthGateStatus.needsIdentity, loc),
          loc == AppRoutes.onboardingIdentity
              ? null
              : AppRoutes.onboardingIdentity,
        );
      }
    });

    test('needsClass keeps only /onboarding/class', () {
      for (final loc in locations) {
        expect(
          computeAuthRedirect(AuthGateStatus.needsClass, loc),
          loc == AppRoutes.onboardingClass ? null : AppRoutes.onboardingClass,
        );
      }
    });

    test('authenticated redirects auth/onboarding routes to /learn and allows app routes', () {
      expect(computeAuthRedirect(AuthGateStatus.authenticated, AppRoutes.splash), AppRoutes.learn);
      expect(computeAuthRedirect(AuthGateStatus.authenticated, AppRoutes.auth), AppRoutes.learn);
      expect(
        computeAuthRedirect(AuthGateStatus.authenticated, AppRoutes.onboardingIdentity),
        AppRoutes.learn,
      );
      expect(
        computeAuthRedirect(AuthGateStatus.authenticated, AppRoutes.onboardingClass),
        AppRoutes.learn,
      );
      expect(computeAuthRedirect(AuthGateStatus.authenticated, AppRoutes.learn), isNull);
      expect(
        computeAuthRedirect(AuthGateStatus.authenticated, AppRoutes.materialDetail('m1')),
        isNull,
      );
    });
  });
}
