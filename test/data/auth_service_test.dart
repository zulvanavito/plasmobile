import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/network/dio_client.dart';
import 'package:plasmobile/data/services/auth_service.dart';

void main() {
  group('MockAuthService', () {
    late MockAuthService authService;

    setUp(() {
      authService = MockAuthService();
    });

    tearDown(() {
      authService.dispose();
    });

    test('starts with null currentUser and null access token', () async {
      expect(authService.currentUser, isNull);
      expect(await authService.getAccessToken(), isNull);
    });

    test('rejects invalid email or short password with PlasApiException', () async {
      await expectLater(
        () => authService.signInWithEmail(
          email: 'invalid-email',
          password: 'password123',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.validationError)
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );

      await expectLater(
        () => authService.signUpWithEmail(
          email: 'budi@plas.ac.id',
          password: '123',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.validationError)
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('signUp, signOut, signInWithEmail, and signInWithGoogle emit states',
        () async {
      final emitted = <AuthSessionUser?>[];
      final sub = authService.authStateChanges().listen(emitted.add);

      final signedUp = await authService.signUpWithEmail(
        email: 'budi@plas.ac.id',
        password: 'secret123',
        displayName: 'Budi Santoso',
      );
      expect(signedUp.email, 'budi@plas.ac.id');
      expect(signedUp.displayName, 'Budi Santoso');
      expect(authService.currentUser, signedUp);
      expect(await authService.getAccessToken(), 'mock-jwt-token');

      await authService.signOut();
      expect(authService.currentUser, isNull);
      expect(await authService.getAccessToken(), isNull);

      final signedIn = await authService.signInWithEmail(
        email: 'budi@plas.ac.id',
        password: 'secret123',
      );
      expect(signedIn.email, 'budi@plas.ac.id');
      expect(authService.currentUser, signedIn);

      final googleUser = await authService.signInWithGoogle();
      expect(googleUser.userId, 'mock-google-001');
      expect(authService.currentUser, googleUser);

      await pumpEventQueue();
      expect(emitted, <AuthSessionUser?>[
        signedUp,
        null,
        signedIn,
        googleUser,
      ]);

      await sub.cancel();
    });

    test('accessTokenProvider delegates to authServiceProvider', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final auth = container.read(authServiceProvider);
      final getToken = container.read(accessTokenProvider);

      expect(await getToken(), isNull);
      await auth.signInWithGoogle();
      expect(await getToken(), 'mock-google-jwt-token');
    });
  });
}
