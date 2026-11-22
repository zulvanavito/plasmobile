import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/app.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/router/app_router.dart';
import 'package:plasmobile/core/router/app_routes.dart';
import 'package:plasmobile/core/sync/pending_sync_queue.dart';
import 'package:plasmobile/core/theme/plas_theme.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/data/dto/material_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/data/dto/student_profile_dto.dart';
import 'package:plasmobile/data/repositories/mock_plas_repository.dart';
import 'package:plasmobile/data/repositories/mock_seed_data.dart';
import 'package:plasmobile/data/repositories/plas_repository.dart';
import 'package:plasmobile/data/services/auth_service.dart';
import 'package:plasmobile/features/auth/application/session_controller.dart';
import 'package:plasmobile/features/auth/presentation/auth_screen.dart';
import 'package:plasmobile/features/auth/presentation/onboarding_class_screen.dart';
import 'package:plasmobile/features/auth/presentation/onboarding_identity_screen.dart';
import 'package:plasmobile/features/auth/presentation/splash_screen.dart';
import 'package:plasmobile/features/learn/presentation/learn_home_screen.dart';
import 'package:plasmobile/features/shared/providers/plas_providers.dart';
import 'package:plasmobile/shared/widgets/plas_state_views.dart';
import 'package:plasmobile/shared/widgets/plas_status_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAuthService implements AuthService {
  _TestAuthService({AuthSessionUser? initialUser}) : _currentUser = initialUser;

  final StreamController<AuthSessionUser?> _controller =
      StreamController<AuthSessionUser?>.broadcast();
  AuthSessionUser? _currentUser;

  String? lastSignUpDisplayName;
  PlasApiException? nextGoogleError;
  PlasApiException? nextEmailError;

  @override
  AuthSessionUser? get currentUser => _currentUser;

  @override
  Stream<AuthSessionUser?> authStateChanges() => _controller.stream;

  @override
  Future<String?> getAccessToken() async => _currentUser?.accessToken;

  @override
  Future<AuthSessionUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (nextEmailError != null) {
      final err = nextEmailError!;
      nextEmailError = null;
      throw err;
    }
    final normalized = email.trim();
    if (!normalized.contains('@') || !normalized.contains('.')) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.validationError,
        statusCode: 400,
        serverMessage: 'Format email tidak valid.',
      );
    }
    if (password.length < 6) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.validationError,
        statusCode: 400,
        serverMessage: 'Password minimal 6 karakter.',
      );
    }
    final user = AuthSessionUser(
      userId: 'test-student-001',
      email: normalized,
      displayName: 'Mahasiswa Uji',
      accessToken: 'test-jwt-token',
    );
    _setUser(user);
    return user;
  }

  @override
  Future<AuthSessionUser> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (nextEmailError != null) {
      final err = nextEmailError!;
      nextEmailError = null;
      throw err;
    }
    lastSignUpDisplayName = displayName;
    final normalized = email.trim();
    if (!normalized.contains('@') || !normalized.contains('.')) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.validationError,
        statusCode: 400,
        serverMessage: 'Format email tidak valid.',
      );
    }
    if (password.length < 6) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.validationError,
        statusCode: 400,
        serverMessage: 'Password minimal 6 karakter.',
      );
    }
    final user = AuthSessionUser(
      userId: 'test-student-001',
      email: normalized,
      displayName: displayName,
      accessToken: 'test-jwt-token',
    );
    _setUser(user);
    return user;
  }

  @override
  Future<AuthSessionUser> signInWithGoogle() async {
    if (nextGoogleError != null) {
      final err = nextGoogleError!;
      nextGoogleError = null;
      throw err;
    }
    const user = AuthSessionUser(
      userId: 'test-google-001',
      email: 'google.mhs@plas.ac.id',
      displayName: 'Mahasiswa Google',
      accessToken: 'test-google-jwt',
    );
    _setUser(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _setUser(null);
  }

  void simulateRemoteSignOut() {
    _setUser(null);
  }

  void _setUser(AuthSessionUser? user) {
    _currentUser = user;
    if (!_controller.isClosed) {
      _controller.add(user);
    }
  }

  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}

class _TestPlasRepository extends MockPlasRepository {
  _TestPlasRepository({super.initialProfile});

  PlasApiException? nextGetMeError;
  Completer<StudentProfileDto>? nextGetMeCompleter;
  PlasApiException? nextCreateProfileError;
  PlasApiException? nextClassesError;
  PlasApiException? nextUpdateClassError;
  final List<String?> updatedClassIds = <String?>[];
  int getMaterialsCalls = 0;

  @override
  Future<StudentProfileDto> getMe() async {
    if (nextGetMeCompleter != null) {
      final completer = nextGetMeCompleter!;
      nextGetMeCompleter = null;
      return completer.future;
    }
    if (nextGetMeError != null) {
      final error = nextGetMeError!;
      nextGetMeError = null;
      throw error;
    }
    return super.getMe();
  }

  @override
  Future<StudentProfileDto> createProfile(CreateProfileRequest request) async {
    if (nextCreateProfileError != null) {
      final error = nextCreateProfileError!;
      nextCreateProfileError = null;
      throw error;
    }
    return super.createProfile(request);
  }

  @override
  Future<List<ClassInfoDto>> getClasses() async {
    if (nextClassesError != null) {
      final error = nextClassesError!;
      nextClassesError = null;
      throw error;
    }
    return super.getClasses();
  }

  @override
  Future<StudentProfileDto> updateClass(String? kelasId) async {
    updatedClassIds.add(kelasId);
    if (nextUpdateClassError != null) {
      final error = nextUpdateClassError!;
      nextUpdateClassError = null;
      throw error;
    }
    return super.updateClass(kelasId);
  }

  @override
  Future<List<MaterialSummaryDto>> getMaterials() async {
    getMaterialsCalls++;
    return super.getMaterials();
  }
}

Widget _buildApp({
  required SharedPreferences prefs,
  required _TestAuthService authService,
  required _TestPlasRepository repository,
  MediaQueryData? mediaQuery,
  Key? scopeKey,
}) {
  return ProviderScope(
    key: scopeKey ?? UniqueKey(),
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authServiceProvider.overrideWithValue(authService),
      plasRepositoryProvider.overrideWithValue(repository),
    ],
    child: mediaQuery == null
        ? const PlasApp()
        : MediaQuery(
            data: mediaQuery,
            child: const PlasApp(),
          ),
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> _enterVisibleText(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.enterText(finder, text);
}

void _assertNoEmDashInTexts(WidgetTester tester) {
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    final text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
    expect(text, isNot(contains('\u2014')));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('AppRoutes.exerciseSession', () {
    test('omits query string when submaterialId is omitted or empty', () {
      expect(
        AppRoutes.exerciseSession('ex-01'),
        '/exercises/ex-01/session',
      );
      expect(
        AppRoutes.exerciseSession('ex-01', submaterialId: ''),
        '/exercises/ex-01/session',
      );
    });

    test('appends submaterialId query parameter when provided', () {
      expect(
        AppRoutes.exerciseSession('ex-01', submaterialId: 'sub-01'),
        '/exercises/ex-01/session?submaterialId=sub-01',
      );
    });
  });

  group('Shared providers & pending sync queue helper', () {
    testWidgets(
      'retryPendingSyncQueue replays items, resets syncing state, and invalidates learning providers',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(
          initialUser: const AuthSessionUser(
            userId: 'u1',
            email: 'andi@plas.ac.id',
            accessToken: 'jwt',
          ),
        );
        addTearDown(authService.dispose);
        final repository = _TestPlasRepository(
          initialProfile: const StudentProfileDto(
            mahasiswaId: 'mhs-01',
            nama: 'Andi Fajar',
            nim: '2415091001',
            preTestSubmitted: false,
            remainingAiQuota: 10,
          ),
        );

        final attempt = await repository.createExerciseAttempt(
          exerciseId: 'ex-01',
          creationRequestId: 'req-attempt-1',
        );

        late WidgetRef capturedRef;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authServiceProvider.overrideWithValue(authService),
              plasRepositoryProvider.overrideWithValue(repository),
            ],
            child: MaterialApp(
              theme: buildPlasTheme(),
              home: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  ref.watch(materialsProvider);
                  return const Scaffold(body: SizedBox.shrink());
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(repository.getMaterialsCalls, 1);

        await capturedRef.read(pendingSyncProvider.notifier).enqueue(
              PendingSyncItem(
                idempotencyKey: 'sync-ans-1',
                method: 'POST',
                path: '/exercise-attempts/${attempt.attemptId}/answers',
                body: <String, dynamic>{
                  'question_id': 'ex-01-q1',
                  'answer': <String, dynamic>{'option_id': 'ex-01-q1-opt-1'},
                  'time_spent_seconds': 5,
                },
                createdAtIso: '2026-11-21T00:00:00Z',
                operationLabel: 'Jawaban Soal 1',
              ),
            );

        expect(capturedRef.read(pendingSyncProvider).length, 1);

        await retryPendingSyncQueue(capturedRef);
        await tester.pumpAndSettle();

        expect(capturedRef.read(isSyncingPendingProvider), isFalse);
        expect(capturedRef.read(pendingSyncProvider), isEmpty);
        expect(repository.getMaterialsCalls, 2);
      },
    );
  });

  group('M01 Splash & SessionController bootstrap', () {
    testWidgets('unauthenticated user navigates from M01 to M02', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final authService = _TestAuthService();
      addTearDown(authService.dispose);
      final repository = _TestPlasRepository();

      await tester.pumpWidget(
        _buildApp(
          prefs: prefs,
          authService: authService,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('CS LAB ENV // AUTH'), findsOneWidget);
    });

    testWidgets('404 profile_not_found navigates from M01 to M03', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final authService = _TestAuthService(
        initialUser: const AuthSessionUser(
          userId: 'u1',
          email: 'baru@plas.ac.id',
          accessToken: 'jwt',
        ),
      );
      addTearDown(authService.dispose);
      final repository = _TestPlasRepository();

      await tester.pumpWidget(
        _buildApp(
          prefs: prefs,
          authService: authService,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingIdentityScreen), findsOneWidget);
      expect(find.text('Identitas Mahasiswa'), findsOneWidget);
    });

    testWidgets('401 unauthorized on bootstrap signs out and navigates to M02', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final authService = _TestAuthService(
        initialUser: const AuthSessionUser(
          userId: 'u1',
          email: 'expired@plas.ac.id',
          accessToken: 'expired-jwt',
        ),
      );
      addTearDown(authService.dispose);
      final repository = _TestPlasRepository()
        ..nextGetMeError = PlasApiException.fromApiCode(
          ApiErrorCodes.unauthorized,
          statusCode: 401,
        );

      await tester.pumpWidget(
        _buildApp(
          prefs: prefs,
          authService: authService,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      expect(authService.currentUser, isNull);
      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets(
      'bootstrap error shows PlasErrorView on M01 and retries successfully',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(
          initialUser: const AuthSessionUser(
            userId: 'u1',
            email: 'andi@plas.ac.id',
            accessToken: 'jwt',
          ),
        );
        addTearDown(authService.dispose);
        final repository = _TestPlasRepository(
          initialProfile: StudentProfileDto(
            mahasiswaId: 'mhs-01',
            nama: 'Andi Fajar',
            nim: '2415091001',
            kelas: MockSeedData.classes.first,
            preTestSubmitted: false,
            remainingAiQuota: 10,
          ),
        )..nextGetMeError = PlasApiException.offline();

        await tester.pumpWidget(
          _buildApp(
            prefs: prefs,
            authService: authService,
            repository: repository,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.byType(PlasErrorView), findsOneWidget);
        expect(find.text('Coba Lagi'), findsOneWidget);
        expect(find.text('Keluar'), findsOneWidget);

        await _tapVisible(tester, find.text('Coba Lagi'));
        await tester.pumpAndSettle();

        expect(find.byType(LearnHomeScreen), findsOneWidget);
      },
    );

    testWidgets('remote sign-out returns user to M02', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final authService = _TestAuthService(
        initialUser: const AuthSessionUser(
          userId: 'u1',
          email: 'andi@plas.ac.id',
          accessToken: 'jwt',
        ),
      );
      addTearDown(authService.dispose);
      final repository = _TestPlasRepository(
        initialProfile: StudentProfileDto(
          mahasiswaId: 'mhs-01',
          nama: 'Andi Fajar',
          nim: '2415091001',
          kelas: MockSeedData.classes.first,
          preTestSubmitted: false,
          remainingAiQuota: 10,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          prefs: prefs,
          authService: authService,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LearnHomeScreen), findsOneWidget);

      authService.simulateRemoteSignOut();
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
    });
  });

  group('M02 AuthScreen', () {
    testWidgets(
      'shows inline error banner on invalid email, toggles password visibility, and signs in with email',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService();
        addTearDown(authService.dispose);
        final repository = _TestPlasRepository();

        await tester.pumpWidget(
          _buildApp(
            prefs: prefs,
            authService: authService,
            repository: repository,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('CS LAB ENV // AUTH'), findsOneWidget);
        expect(find.text('atau'), findsOneWidget);

        final submitContext = tester.element(
          find.byKey(const ValueKey('auth_submit_button')),
        );
        final primaryColor = Theme.of(submitContext)
            .elevatedButtonTheme
            .style
            ?.backgroundColor
            ?.resolve(<WidgetState>{});
        expect(primaryColor, PlasColors.brandPrimary);

        final passwordField = tester.widget<TextField>(
          find.byKey(const ValueKey('auth_password_field')),
        );
        expect(passwordField.obscureText, isTrue);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('auth_toggle_password_visibility')),
        );
        await tester.pump();
        final revealedField = tester.widget<TextField>(
          find.byKey(const ValueKey('auth_password_field')),
        );
        expect(revealedField.obscureText, isFalse);

        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('auth_email_field')),
          'bukan-email',
        );
        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('auth_password_field')),
          'secret123',
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('auth_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('auth_error_banner')),
          findsOneWidget,
        );
        expect(find.text('Format email tidak valid.'), findsOneWidget);

        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('auth_email_field')),
          'andi@plas.ac.id',
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('auth_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingIdentityScreen), findsOneWidget);
      },
    );

    testWidgets('supports Daftar mode with optional Nama Panggilan', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final authService = _TestAuthService();
      addTearDown(authService.dispose);
      final repository = _TestPlasRepository();

      await tester.pumpWidget(
        _buildApp(
          prefs: prefs,
          authService: authService,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.byKey(const ValueKey('auth_tab_register')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('auth_display_name_field')),
        findsOneWidget,
      );
      expect(find.text('Buat Akun Mahasiswa'), findsOneWidget);

      await _enterVisibleText(
        tester,
        find.byKey(const ValueKey('auth_display_name_field')),
        'Budi',
      );
      await _enterVisibleText(
        tester,
        find.byKey(const ValueKey('auth_email_field')),
        'budi@plas.ac.id',
      );
      await _enterVisibleText(
        tester,
        find.byKey(const ValueKey('auth_password_field')),
        'secret123',
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('auth_submit_button')),
      );
      await tester.pumpAndSettle();

      expect(authService.lastSignUpDisplayName, 'Budi');
      expect(find.byType(OnboardingIdentityScreen), findsOneWidget);
    });

    testWidgets('supports Masuk dengan Google and surfaces Google auth errors inline', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final authService = _TestAuthService()
        ..nextGoogleError = PlasApiException.fromApiCode(
          ApiErrorCodes.unauthorized,
          statusCode: 401,
          serverMessage: 'Login Google dibatalkan.',
        );
      addTearDown(authService.dispose);
      final repository = _TestPlasRepository();

      await tester.pumpWidget(
        _buildApp(
          prefs: prefs,
          authService: authService,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.byKey(const ValueKey('auth_google_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('auth_error_banner')), findsOneWidget);
      expect(find.text('Login Google dibatalkan.'), findsOneWidget);

      await _tapVisible(tester, find.byKey(const ValueKey('auth_google_button')));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingIdentityScreen), findsOneWidget);
    });
  });

  group('M03 OnboardingIdentityScreen', () {
    testWidgets(
      'handles 409 nim_conflict and profile_conflict inline, shows Valid badges, and proceeds to M04',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(
          initialUser: const AuthSessionUser(
            userId: 'u1',
            email: 'andi@plas.ac.id',
            accessToken: 'jwt',
          ),
        );
        addTearDown(authService.dispose);
        final repository = _TestPlasRepository();

        await tester.pumpWidget(
          _buildApp(
            prefs: prefs,
            authService: authService,
            repository: repository,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingIdentityScreen), findsOneWidget);
        expect(find.textContaining('10 Digit'), findsNothing);
        expect(find.text('Keluar Akun'), findsOneWidget);

        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('identity_nama_field')),
          'Andi Fajar',
        );
        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('identity_nim_field')),
          kMockConflictNim,
        );
        await tester.pump();

        expect(find.byType(PlasStatusBadge), findsNWidgets(2));
        expect(find.byIcon(Symbols.check_circle), findsNWidgets(2));

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('identity_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('identity_nim_error')),
          findsOneWidget,
        );
        expect(
          find.text(plasErrorMessage(ApiErrorCodes.nimConflict)),
          findsOneWidget,
        );

        repository.nextCreateProfileError = PlasApiException.fromApiCode(
          ApiErrorCodes.profileConflict,
          statusCode: 409,
        );
        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('identity_nim_field')),
          '2415091001',
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('identity_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('identity_general_error')),
          findsOneWidget,
        );
        expect(
          find.text(plasErrorMessage(ApiErrorCodes.profileConflict)),
          findsOneWidget,
        );

        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('identity_nim_field')),
          '2415091001',
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('identity_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingClassScreen), findsOneWidget);
      },
    );

    testWidgets('Keluar Akun on M03 returns to M02', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final authService = _TestAuthService(
        initialUser: const AuthSessionUser(
          userId: 'u1',
          email: 'andi@plas.ac.id',
          accessToken: 'jwt',
        ),
      );
      addTearDown(authService.dispose);
      final repository = _TestPlasRepository();

      await tester.pumpWidget(
        _buildApp(
          prefs: prefs,
          authService: authService,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingIdentityScreen), findsOneWidget);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('identity_logout_button')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
    });
  });

  group('M04 OnboardingClassScreen & persistence', () {
    testWidgets(
      'handles classes error/retry, matches TI-2A-2026 with #F0FDF4 preview card, and joins class to /learn',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(
          initialUser: const AuthSessionUser(
            userId: 'u1',
            email: 'andi@plas.ac.id',
            accessToken: 'jwt',
          ),
        );
        addTearDown(authService.dispose);
        final repository = _TestPlasRepository(
          initialProfile: const StudentProfileDto(
            mahasiswaId: 'mhs-01',
            nama: 'Andi Fajar',
            nim: '2415091001',
            preTestSubmitted: false,
            remainingAiQuota: 10,
          ),
        )..nextClassesError = PlasApiException.offline();

        await tester.pumpWidget(
          _buildApp(
            prefs: prefs,
            authService: authService,
            repository: repository,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingClassScreen), findsOneWidget);
        expect(find.byType(PlasErrorView), findsOneWidget);
        expect(find.text('Coba Lagi'), findsOneWidget);

        await _tapVisible(tester, find.text('Coba Lagi'));
        await tester.pumpAndSettle();

        expect(find.text('CS LAB ENV // KELAS'), findsOneWidget);

        final disabledButton = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('class_join_button')),
        );
        expect(disabledButton.onPressed, isNull);

        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('class_code_field')),
          '  ti-2a-2026 ',
        );
        await tester.pumpAndSettle();

        final previewFinder = find.byKey(const ValueKey('class_preview_card'));
        expect(previewFinder, findsOneWidget);
        final previewContainer = tester.widget<Container>(
          find
              .descendant(
                of: previewFinder,
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = previewContainer.decoration! as BoxDecoration;
        expect(decoration.color, PlasColors.successBg);
        expect(
          (decoration.border! as Border).top.color,
          PlasColors.successBorder,
        );
        expect(find.text('Pemrograman TypeScript A'), findsOneWidget);
        expect(find.text('Dr. Rina Kusuma, M.Kom.'), findsOneWidget);

        final enabledButton = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('class_join_button')),
        );
        expect(enabledButton.onPressed, isNotNull);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('class_join_button')),
        );
        await tester.pumpAndSettle();

        expect(repository.updatedClassIds, <String?>['kelas-ti2a-2026']);
        expect(find.byType(LearnHomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Lewati (Pengguna Umum) persists class onboarding flag and subsequent bootstrap skips M04 directly to /learn',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(
          initialUser: const AuthSessionUser(
            userId: 'u1',
            email: 'andi@plas.ac.id',
            accessToken: 'jwt',
          ),
        );
        addTearDown(authService.dispose);
        final repository = _TestPlasRepository(
          initialProfile: const StudentProfileDto(
            mahasiswaId: 'mhs-01',
            nama: 'Andi Fajar',
            nim: '2415091001',
            preTestSubmitted: false,
            remainingAiQuota: 10,
          ),
        );

        await tester.pumpWidget(
          _buildApp(
            prefs: prefs,
            authService: authService,
            repository: repository,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingClassScreen), findsOneWidget);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('class_skip_button')),
        );
        await tester.pumpAndSettle();

        expect(
          prefs.getBool(classOnboardingDoneKey('mhs-01')),
          isTrue,
        );
        expect(find.byType(LearnHomeScreen), findsOneWidget);

        final authService2 = _TestAuthService(
          initialUser: const AuthSessionUser(
            userId: 'u1',
            email: 'andi@plas.ac.id',
            accessToken: 'jwt',
          ),
        );
        addTearDown(authService2.dispose);
        final repository2 = _TestPlasRepository(
          initialProfile: const StudentProfileDto(
            mahasiswaId: 'mhs-01',
            nama: 'Andi Fajar',
            nim: '2415091001',
            preTestSubmitted: false,
            remainingAiQuota: 10,
          ),
        );

        await tester.pumpWidget(
          _buildApp(
            prefs: prefs,
            authService: authService2,
            repository: repository2,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingClassScreen), findsNothing);
        expect(find.byType(LearnHomeScreen), findsOneWidget);
      },
    );
  });

  group('SessionController refreshProfile & signOut preservation', () {
    test(
      'refreshProfile updates isClassLocked and signOut preserves pendingSyncProvider',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(
          initialUser: const AuthSessionUser(
            userId: 'u1',
            email: 'andi@plas.ac.id',
            accessToken: 'jwt',
          ),
        );
        addTearDown(authService.dispose);
        final repository = _TestPlasRepository(
          initialProfile: const StudentProfileDto(
            mahasiswaId: 'mhs-01',
            nama: 'Andi Fajar',
            nim: '2415091001',
            preTestSubmitted: false,
            remainingAiQuota: 10,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authServiceProvider.overrideWithValue(authService),
            plasRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        await container.read(sessionControllerProvider.notifier).bootstrap();
        expect(container.read(sessionControllerProvider).isClassLocked, isFalse);

        await container.read(pendingSyncProvider.notifier).enqueue(
              const PendingSyncItem(
                idempotencyKey: 'keep-me-on-logout',
                method: 'POST',
                path: '/exercise-attempts/a1/submit',
                body: <String, dynamic>{},
                createdAtIso: '2026-11-21T00:00:00Z',
                operationLabel: 'Kirim Latihan',
              ),
            );

        final preStart = await repository.createTestAttempt(
          testId: MockSeedData.preTest.testId,
          creationRequestId: 'pre-req-1',
        );
        for (final q in MockSeedData.preTest.questions) {
          await repository.startTestQuestion(
            attemptId: preStart.attemptId,
            sequence: q.sequence,
          );
          final answer = switch (q.sequence) {
            1 => const McAnswer('pre-q1-opt-1'),
            2 => const McAnswer('pre-q2-opt-2'),
            3 => const TfAnswer(true),
            4 => const FibAnswer('string'),
            _ => const FibAnswer('return'),
          };
          await repository.submitTestAnswer(
            attemptId: preStart.attemptId,
            sequence: q.sequence,
            answer: answer,
            submissionRequestId: 'ans-${q.sequence}',
          );
        }
        await repository.submitTestAttempt(
          attemptId: preStart.attemptId,
          idempotencyKey: 'sub-pre-1',
        );

        await container
            .read(sessionControllerProvider.notifier)
            .refreshProfile();
        expect(container.read(sessionControllerProvider).isClassLocked, isTrue);

        await container.read(sessionControllerProvider.notifier).signOut();
        expect(container.read(sessionControllerProvider).authUser, isNull);
        expect(container.read(sessionControllerProvider).profile, isNull);
        expect(
          container.read(authGateStatusProvider),
          AuthGateStatus.unauthenticated,
        );
        expect(container.read(pendingSyncProvider).length, 1);
        expect(
          container.read(pendingSyncProvider).single.idempotencyKey,
          'keep-me-on-logout',
        );
      },
    );

    test(
      'BUG-003: refreshProfile does not restore profile after concurrent signOut',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(
          initialUser: const AuthSessionUser(
            userId: 'u1',
            email: 'andi@plas.ac.id',
            accessToken: 'jwt',
          ),
        );
        addTearDown(authService.dispose);
        final repository = _TestPlasRepository(
          initialProfile: StudentProfileDto(
            mahasiswaId: 'mhs-01',
            nama: 'Andi Fajar',
            nim: '2415091001',
            kelas: MockSeedData.classes.first,
            preTestSubmitted: false,
            remainingAiQuota: 10,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authServiceProvider.overrideWithValue(authService),
            plasRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        await container.read(sessionControllerProvider.notifier).bootstrap();
        expect(container.read(sessionControllerProvider).profile, isNotNull);
        expect(
          container.read(authGateStatusProvider),
          AuthGateStatus.authenticated,
        );

        final getMeCompleter = Completer<StudentProfileDto>();
        repository.nextGetMeCompleter = getMeCompleter;

        final refreshFuture = container
            .read(sessionControllerProvider.notifier)
            .refreshProfile();
        await container.read(sessionControllerProvider.notifier).signOut();

        getMeCompleter.complete(
          StudentProfileDto(
            mahasiswaId: 'mhs-01',
            nama: 'Andi Fajar',
            nim: '2415091001',
            kelas: MockSeedData.classes.first,
            preTestSubmitted: true,
            remainingAiQuota: 10,
          ),
        );
        await refreshFuture;

        expect(container.read(sessionControllerProvider).authUser, isNull);
        expect(container.read(sessionControllerProvider).profile, isNull);
        expect(
          container.read(authGateStatusProvider),
          AuthGateStatus.unauthenticated,
        );
      },
    );
  });

  group('M01-M04 390x844 @ 2.0x text scale accessibility', () {
    testWidgets(
      'M01 error, M02, M03, and M04 render without overflow or em dashes',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const mq = MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(2.0),
        );

        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(
          initialUser: const AuthSessionUser(
            userId: 'u1',
            email: 'andi@plas.ac.id',
            accessToken: 'jwt',
          ),
        );
        addTearDown(authService.dispose);
        final repository = _TestPlasRepository()
          ..nextGetMeError = PlasApiException.offline();

        // M01 error state
        await tester.pumpWidget(
          _buildApp(
            prefs: prefs,
            authService: authService,
            repository: repository,
            mediaQuery: mq,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(SplashScreen), findsOneWidget);
        _assertNoEmDashInTexts(tester);

        // M02 AuthScreen
        await _tapVisible(tester, find.text('Keluar'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(AuthScreen), findsOneWidget);
        _assertNoEmDashInTexts(tester);

        // M03 OnboardingIdentityScreen
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('auth_google_button')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(OnboardingIdentityScreen), findsOneWidget);
        _assertNoEmDashInTexts(tester);

        // M04 OnboardingClassScreen with matched class preview
        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('identity_nama_field')),
          'Andi Fajar',
        );
        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('identity_nim_field')),
          '2415091001',
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('identity_submit_button')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(OnboardingClassScreen), findsOneWidget);

        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('class_code_field')),
          'TI-2A-2026',
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);
      },
    );
  });
}
