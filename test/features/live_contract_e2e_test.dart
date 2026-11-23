import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/app.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/network/dio_client.dart';
import 'package:plasmobile/core/network/idempotency_interceptor.dart';
import 'package:plasmobile/core/sync/pending_sync_queue.dart';
import 'package:plasmobile/data/dto/ai_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/data/dto/student_profile_dto.dart';
import 'package:plasmobile/data/repositories/api_plas_repository.dart';
import 'package:plasmobile/data/repositories/mock_plas_repository.dart';
import 'package:plasmobile/data/repositories/mock_seed_data.dart';
import 'package:plasmobile/data/repositories/plas_repository.dart';
import 'package:plasmobile/data/services/auth_service.dart';
import 'package:plasmobile/features/ai/presentation/ai_assistant_sheet.dart';
import 'package:plasmobile/features/auth/application/session_controller.dart';
import 'package:plasmobile/features/auth/presentation/auth_screen.dart';
import 'package:plasmobile/features/auth/presentation/onboarding_class_screen.dart';
import 'package:plasmobile/features/auth/presentation/onboarding_identity_screen.dart';
import 'package:plasmobile/features/exercise/presentation/exercise_review_screen.dart';
import 'package:plasmobile/features/exercise/presentation/exercise_session_screen.dart';
import 'package:plasmobile/features/learn/presentation/learn_home_screen.dart';
import 'package:plasmobile/features/learn/presentation/material_detail_screen.dart';
import 'package:plasmobile/features/learn/presentation/submaterial_read_screen.dart';
import 'package:plasmobile/features/profile/presentation/profile_screen.dart';
import 'package:plasmobile/features/test_eval/presentation/test_result_screen.dart';
import 'package:plasmobile/features/test_eval/presentation/test_session_screen.dart';
import 'package:plasmobile/shared/widgets/confirm_dialog.dart';
import 'package:plasmobile/shared/widgets/plas_state_views.dart';
import 'package:plasmobile/shared/widgets/tanya_ai_fab.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LiveTestAuthService implements AuthService {
  _LiveTestAuthService({AuthSessionUser? initialUser})
      : _currentUser = initialUser;

  final StreamController<AuthSessionUser?> _controller =
      StreamController<AuthSessionUser?>.broadcast();
  AuthSessionUser? _currentUser;

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
    final user = AuthSessionUser(
      userId: 'live-student-001',
      email: email.trim(),
      displayName: 'Andi Fajar',
      accessToken: 'live-supabase-jwt',
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
    throw UnimplementedError();
  }

  @override
  Future<AuthSessionUser> signInWithGoogle() async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {
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

class _ContractHttpAdapter implements HttpClientAdapter {
  _ContractHttpAdapter(this.backend);

  final MockPlasRepository backend;
  final List<RequestOptions> capturedRequests = <RequestOptions>[];
  Future<ResponseBody?> Function(RequestOptions options)? overrideHandler;

  static ResponseBody jsonResponse(int statusCode, Object? body) {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: const <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  static ResponseBody errorEnvelope(
    int statusCode,
    String code,
    String message,
  ) {
    return jsonResponse(statusCode, <String, dynamic>{
      'error': <String, dynamic>{
        'code': code,
        'message': message,
      },
    });
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedRequests.add(options);

    if (overrideHandler != null) {
      final overridden = await overrideHandler!(options);
      if (overridden != null) return overridden;
    }

    try {
      return await _dispatch(options);
    } on PlasApiException catch (error) {
      if (error.isOffline) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'Koneksi internet terputus.',
        );
      }
      return errorEnvelope(
        error.statusCode ?? 500,
        error.code,
        error.serverMessage ?? error.message,
      );
    }
  }

  Future<ResponseBody> _dispatch(RequestOptions options) async {
    final method = options.method.toUpperCase();
    final path = options.path;
    final body = options.data is Map
        ? Map<String, dynamic>.from(options.data as Map)
        : const <String, dynamic>{};
    final idempotencyKey = options.headers[kIdempotencyHeader]?.toString() ?? '';

    if (method == 'GET' && path == '/me') {
      return jsonResponse(200, (await backend.getMe()).toJson());
    }
    if (method == 'POST' && path == '/me') {
      final profile = await backend.createProfile(
        CreateProfileRequest.fromJson(body),
      );
      return jsonResponse(201, profile.toJson());
    }
    if (method == 'GET' && path == '/classes') {
      final list = await backend.getClasses();
      return jsonResponse(200, list.map((c) => c.toJson()).toList());
    }
    if (method == 'PATCH' && path == '/me/class') {
      final updated = await backend.updateClass(body['kelas_id'] as String?);
      return jsonResponse(200, updated.toJson());
    }
    if (method == 'GET' && path == '/materials') {
      final list = await backend.getMaterials();
      return jsonResponse(200, list.map((m) => m.toJson()).toList());
    }
    final matMatch = RegExp(r'^/materials/([^/]+)$').firstMatch(path);
    if (method == 'GET' && matMatch != null) {
      final detail = await backend.getMaterialDetail(matMatch.group(1)!);
      return jsonResponse(200, detail.toJson());
    }
    final subExMatch = RegExp(r'^/sub-materials/([^/]+)/exercise$').firstMatch(path);
    if (method == 'GET' && subExMatch != null) {
      final ex = await backend.getExercise(subExMatch.group(1)!);
      return jsonResponse(200, ex.toJson());
    }
    final subMatch = RegExp(r'^/sub-materials/([^/]+)$').firstMatch(path);
    if (method == 'GET' && subMatch != null) {
      final sub = await backend.getSubMaterial(subMatch.group(1)!);
      return jsonResponse(200, sub.toJson());
    }
    final exAttMatch = RegExp(r'^/exercises/([^/]+)/attempts$').firstMatch(path);
    if (exAttMatch != null) {
      final exerciseId = exAttMatch.group(1)!;
      if (method == 'POST') {
        final created = await backend.createExerciseAttempt(
          exerciseId: exerciseId,
          creationRequestId: idempotencyKey,
        );
        return jsonResponse(201, created.toJson());
      }
      if (method == 'GET') {
        final list = await backend.getExerciseAttempts(exerciseId);
        return jsonResponse(200, list.map((a) => a.toJson()).toList());
      }
    }
    final exAnsMatch = RegExp(r'^/exercise-attempts/([^/]+)/answers$').firstMatch(path);
    if (method == 'POST' && exAnsMatch != null) {
      final attemptId = exAnsMatch.group(1)!;
      final questionId = body['question_id'] as String;
      final qSeed = MockSeedData.findExerciseQuestion(questionId)!;
      final answer = StudentAnswer.fromJson(
        qSeed.questionType,
        Map<String, dynamic>.from(body['answer'] as Map),
      );
      final resp = await backend.submitExerciseAnswer(
        attemptId: attemptId,
        questionId: questionId,
        answer: answer,
        timeSpentSeconds: (body['time_spent_seconds'] as num).toInt(),
        submissionRequestId: idempotencyKey,
      );
      return jsonResponse(200, resp.toJson());
    }
    final exSubMatch = RegExp(r'^/exercise-attempts/([^/]+)/submit$').firstMatch(path);
    if (method == 'POST' && exSubMatch != null) {
      final submitted = await backend.submitExerciseAttempt(
        attemptId: exSubMatch.group(1)!,
        idempotencyKey: idempotencyKey,
      );
      return jsonResponse(200, submitted.toJson());
    }
    final exDetailMatch = RegExp(r'^/exercise-attempts/([^/]+)$').firstMatch(path);
    if (method == 'GET' && exDetailMatch != null) {
      final detail = await backend.getExerciseAttemptDetail(exDetailMatch.group(1)!);
      return jsonResponse(200, detail.toJson());
    }
    if (method == 'GET' && path == '/tests') {
      return jsonResponse(200, (await backend.getTests()).toJson());
    }
    final testAttMatch = RegExp(r'^/tests/([^/]+)/attempts$').firstMatch(path);
    if (method == 'POST' && testAttMatch != null) {
      final started = await backend.createTestAttempt(
        testId: testAttMatch.group(1)!,
        creationRequestId: idempotencyKey,
      );
      return jsonResponse(201, started.toJson());
    }
    final testStartMatch = RegExp(
      r'^/test-attempts/([^/]+)/questions/(\d+)/start$',
    ).firstMatch(path);
    if (method == 'POST' && testStartMatch != null) {
      final q = await backend.startTestQuestion(
        attemptId: testStartMatch.group(1)!,
        sequence: int.parse(testStartMatch.group(2)!),
        idempotencyKey: idempotencyKey.isEmpty ? null : idempotencyKey,
      );
      return jsonResponse(200, q.toJson());
    }
    final testAnsMatch = RegExp(
      r'^/test-attempts/([^/]+)/questions/(\d+)/answers$',
    ).firstMatch(path);
    if (method == 'POST' && testAnsMatch != null) {
      final attemptId = testAnsMatch.group(1)!;
      final sequence = int.parse(testAnsMatch.group(2)!);
      final resumed = await backend.resumeTestAttempt(attemptId);
      final answer = StudentAnswer.fromJson(
        resumed.questionType,
        Map<String, dynamic>.from(body['answer'] as Map),
      );
      final ack = await backend.submitTestAnswer(
        attemptId: attemptId,
        sequence: sequence,
        answer: answer,
        submissionRequestId: idempotencyKey,
      );
      return jsonResponse(200, ack.toJson());
    }
    final testResumeMatch = RegExp(r'^/test-attempts/([^/]+)/resume$').firstMatch(path);
    if (method == 'GET' && testResumeMatch != null) {
      final resumed = await backend.resumeTestAttempt(testResumeMatch.group(1)!);
      return jsonResponse(200, resumed.toJson());
    }
    final testSubMatch = RegExp(r'^/test-attempts/([^/]+)/submit$').firstMatch(path);
    if (method == 'POST' && testSubMatch != null) {
      final res = await backend.submitTestAttempt(
        attemptId: testSubMatch.group(1)!,
        idempotencyKey: idempotencyKey,
      );
      return jsonResponse(200, res.toJson());
    }
    final testResMatch = RegExp(r'^/test-attempts/([^/]+)$').firstMatch(path);
    if (method == 'GET' && testResMatch != null) {
      final res = await backend.getTestAttemptResult(testResMatch.group(1)!);
      return jsonResponse(200, res.toJson());
    }
    if (method == 'GET' && path == '/ai/quota') {
      return jsonResponse(200, (await backend.getAiQuota()).toJson());
    }
    if (method == 'POST' && path == '/ai/ask') {
      final rawLevel = (body['hint_level'] as num?)?.toInt() ?? 1;
      final resp = await backend.askAi(
        request: AiAskRequestDto(
          question: body['question'] as String,
          submaterialId: body['submaterial_id'] as String?,
          exerciseQuestionId: body['exercise_question_id'] as String?,
          hintLevel: AiHintLevel.fromValue(rawLevel),
        ),
        requestId: idempotencyKey,
      );
      return jsonResponse(200, resp.toJson());
    }
    if (method == 'GET' && path == '/progress') {
      return jsonResponse(200, (await backend.getProgress()).toJson());
    }
    if (method == 'GET' && path == '/activities') {
      final list = await backend.getActivities();
      return jsonResponse(200, list.map((a) => a.toJson()).toList());
    }
    return errorEnvelope(404, ApiErrorCodes.notFound, 'Endpoint tidak ditemukan.');
  }
}

StudentProfileDto _defaultProfile() => StudentProfileDto(
      mahasiswaId: 'mhs-01',
      nama: 'Andi Fajar',
      nim: '2415091001',
      kelas: MockSeedData.classes.first,
      preTestSubmitted: false,
      remainingAiQuota: 10,
    );

Widget _buildHttpApp({
  required SharedPreferences prefs,
  required _LiveTestAuthService authService,
  required _ContractHttpAdapter adapter,
}) {
  final dio = createPlasDio(
    baseUrl: 'https://api.plas.test/api',
    getAccessToken: authService.getAccessToken,
    httpClientAdapter: adapter,
  );
  final repo = ApiPlasRepository(dio: dio);

  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authServiceProvider.overrideWithValue(authService),
      plasRepositoryProvider.overrideWithValue(repo),
    ],
    child: const PlasApp(),
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> _enterVisibleText(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Tahap 5 E2E Live Contract (ApiPlasRepository + Dio + PlasApp)', () {
    testWidgets(
      '1. Onboarding HTTP flow: Authorization Bearer, 404 profile_not_found, 409 nim_conflict, POST /me, PATCH /me/class -> M05',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _LiveTestAuthService();
        addTearDown(authService.dispose);
        final backend = MockPlasRepository();
        final adapter = _ContractHttpAdapter(backend);

        await tester.pumpWidget(
          _buildHttpApp(prefs: prefs, authService: authService, adapter: adapter),
        );
        await tester.pumpAndSettle();

        // Starts at M02 AuthScreen -> sign in -> 404 profile_not_found -> M03.
        expect(find.byType(AuthScreen), findsOneWidget);
        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('auth_email_field')),
          'andi@plas.ac.id',
        );
        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('auth_password_field')),
          'secret123',
        );
        await _tapVisible(tester, find.byKey(const ValueKey('auth_submit_button')));
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingIdentityScreen), findsOneWidget);
        final meReq = adapter.capturedRequests.firstWhere((r) => r.path == '/me');
        expect(meReq.headers['Authorization'], 'Bearer live-supabase-jwt');

        // Trigger 409 nim_conflict envelope inline on M03.
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
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('identity_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(plasErrorMessage(ApiErrorCodes.nimConflict)),
          findsOneWidget,
        );
        expect(find.byType(OnboardingIdentityScreen), findsOneWidget);

        // Valid NIM -> POST /me -> M04 OnboardingClassScreen.
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

        // Select TI-2A-2026 -> PATCH /me/class -> M05 LearnHomeScreen.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('class_quick_pick_kelas-ti2a-2026')),
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('class_join_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LearnHomeScreen), findsOneWidget);
        expect(find.text('TI-2A-2026'), findsOneWidget);
        final patchReq = adapter.capturedRequests.lastWhere(
          (r) => r.method == 'PATCH' && r.path == '/me/class',
        );
        expect(patchReq.headers['Authorization'], 'Bearer live-supabase-jwt');
        expect(patchReq.data, <String, dynamic>{'kelas_id': 'kelas-ti2a-2026'});
      },
    );

    testWidgets(
      '2. Latihan HTTP & offline replay idempoten: preserves Idempotency-Key and canonical P6 payload into M13 without answer keys',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _LiveTestAuthService(
          initialUser: const AuthSessionUser(
            userId: 'live-student-001',
            email: 'andi@plas.ac.id',
            displayName: 'Andi Fajar',
            accessToken: 'live-supabase-jwt',
          ),
        );
        addTearDown(authService.dispose);
        final backend = MockPlasRepository(initialProfile: _defaultProfile());
        final adapter = _ContractHttpAdapter(backend);

        await tester.pumpWidget(
          _buildHttpApp(prefs: prefs, authService: authService, adapter: adapter),
        );
        await tester.pumpAndSettle();

        // Navigate M05 -> M06 -> M07 -> M08A/B.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('learn_material_card_mat-01')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MaterialDetailScreen), findsOneWidget);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('read_submaterial_sub-01')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SubMaterialReadScreen), findsOneWidget);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('submaterial_start_exercise_button')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ExerciseSessionScreen), findsOneWidget);

        // Simulate connection drop during Q1, Q2, and attempt submission.
        backend.simulateOffline = true;

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_ex-01-q1-opt-1')),
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_submit_cta')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Soal 2 dari 2'), findsOneWidget);
        expect(find.byType(PlasOfflineSyncBanner), findsOneWidget);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_ex-01-q2-opt-2')),
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_submit_cta')),
        );
        await tester.pumpAndSettle();
        await _tapVisible(tester, find.text('Kumpulkan'));
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(ExerciseSessionScreen)),
        );
        final queued = container.read(pendingSyncProvider);
        expect(queued, hasLength(3));
        final q1Key = queued[0].idempotencyKey;
        final q2Key = queued[1].idempotencyKey;
        final submitKey = queued[2].idempotencyKey;

        // Reconnect and replay queue via HTTP -> transitions to M13.
        adapter.capturedRequests.clear();
        backend.simulateOffline = false;
        await _tapVisible(tester, find.text('Kirim Ulang Sekarang'));
        await tester.pumpAndSettle();

        expect(container.read(pendingSyncProvider), isEmpty);
        expect(find.byType(ExerciseReviewScreen), findsOneWidget);
        expect(find.text('100%'), findsOneWidget);

        final replayAnswerReqs = adapter.capturedRequests
            .where((r) => r.method == 'POST' && r.path.endsWith('/answers'))
            .toList();
        expect(replayAnswerReqs, hasLength(2));
        expect(replayAnswerReqs[0].headers[kIdempotencyHeader], q1Key);
        expect(replayAnswerReqs[1].headers[kIdempotencyHeader], q2Key);

        final q1Body = Map<String, dynamic>.from(replayAnswerReqs[0].data as Map);
        final p6Payload = Map<String, dynamic>.from(q1Body['answer'] as Map);
        expect(p6Payload.keys.toList(), <String>['option_id']);

        final replaySubmitReq = adapter.capturedRequests.firstWhere(
          (r) => r.method == 'POST' && r.path.endsWith('/submit'),
        );
        expect(replaySubmitReq.headers[kIdempotencyHeader], submitKey);

        // P13 verification on M13 UI.
        for (final widget in tester.widgetList<Text>(find.byType(Text))) {
          final text = (widget.data ?? widget.textSpan?.toPlainText() ?? '').toLowerCase();
          expect(text, isNot(contains('kunci jawaban')));
        }
      },
    );

    testWidgets(
      '3. DBR-14, DBR-15, P12, & P13 HTTP flow: Post-test terkunci, Pre-Test linear tanpa AI, M12 tanpa kunci, M15 terkunci DBR-14',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _LiveTestAuthService(
          initialUser: const AuthSessionUser(
            userId: 'live-student-001',
            email: 'andi@plas.ac.id',
            displayName: 'Andi Fajar',
            accessToken: 'live-supabase-jwt',
          ),
        );
        addTearDown(authService.dispose);
        final backend = MockPlasRepository(initialProfile: _defaultProfile());
        final adapter = _ContractHttpAdapter(backend);

        await tester.pumpWidget(
          _buildHttpApp(prefs: prefs, authService: authService, adapter: adapter),
        );
        await tester.pumpAndSettle();

        // DBR-15: Post-Test CTA is locked on M05 before all 7 exercises are SUBMITTED.
        final postCta = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('learn_post_test_cta')),
        );
        expect(postCta.onPressed, isNull);

        // Open Pre-Test (M10).
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('learn_pre_test_cta')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TestSessionScreen), findsOneWidget);
        expect(find.byType(TanyaAiFab), findsNothing);
        expect(find.byIcon(Symbols.timer), findsNothing);

        // Complete all 5 Pre-Test questions over HTTP.
        final submitCta = find.byKey(const ValueKey('test_submit_cta'));
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_pre-q1-opt-1')),
        );
        await _tapVisible(tester, submitCta);
        await tester.pumpAndSettle();

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_pre-q2-opt-2')),
        );
        await _tapVisible(tester, submitCta);
        await tester.pumpAndSettle();

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_tf_true')),
        );
        await _tapVisible(tester, submitCta);
        await tester.pumpAndSettle();

        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('question_fib_field')),
          'string',
        );
        await _tapVisible(tester, submitCta);
        await tester.pumpAndSettle();

        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('question_fib_field')),
          'return',
        );
        await _tapVisible(tester, submitCta);
        await tester.pumpAndSettle();

        await _tapVisible(
          tester,
          find.descendant(
            of: find.byType(PlasConfirmDialog),
            matching: find.text('Kumpulkan Pre-Test'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TestResultScreen), findsOneWidget);
        expect(find.text('100%'), findsOneWidget);
        for (final widget in tester.widgetList<Text>(find.byType(Text))) {
          final text = (widget.data ?? widget.textSpan?.toPlainText() ?? '').toLowerCase();
          expect(text, isNot(contains('pembahasan')));
          expect(text, isNot(contains('kunci jawaban')));
        }

        final container = ProviderScope.containerOf(
          tester.element(find.byType(TestResultScreen)),
        );
        expect(container.read(sessionControllerProvider).isClassLocked, isTrue);

        // Return home -> switch to Profile tab -> DBR-14 class lock must be enforced.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('test_result_home_button')),
        );
        await tester.pumpAndSettle();
        await _tapVisible(tester, find.text('Profil'));
        await tester.pumpAndSettle();

        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(
          find.byKey(const ValueKey('profile_class_locked_banner')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<ElevatedButton>(
                find.byKey(const ValueKey('profile_save_class_button')),
              )
              .onPressed,
          isNull,
        );
      },
    );

    testWidgets(
      '4. AI Socratic WITA HTTP flow: 35s timeout, 504 ai_timeout retry with identical Idempotency-Key -> already_processed, & 403 quota_exceeded',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _LiveTestAuthService(
          initialUser: const AuthSessionUser(
            userId: 'live-student-001',
            email: 'andi@plas.ac.id',
            displayName: 'Andi Fajar',
            accessToken: 'live-supabase-jwt',
          ),
        );
        addTearDown(authService.dispose);
        final backend = MockPlasRepository(
          initialProfile: _defaultProfile(),
          clock: () => DateTime.utc(2026, 11, 20, 16, 5), // 00:05 WITA
        );
        final adapter = _ContractHttpAdapter(backend);

        await tester.pumpWidget(
          _buildHttpApp(prefs: prefs, authService: authService, adapter: adapter),
        );
        await tester.pumpAndSettle();

        // Navigate to M07 and open M09 AiAssistantSheet.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('learn_material_card_mat-01')),
        );
        await tester.pumpAndSettle();
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('read_submaterial_sub-01')),
        );
        await tester.pumpAndSettle();
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('submaterial_tanya_ai_fab')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AiAssistantSheet), findsOneWidget);
        expect(find.text('Sisa kuota hari ini: 10/10'), findsOneWidget);

        // Simulate server finishing AI call but gateway timing out with 504 ai_timeout.
        var shouldReturn504Once = true;
        adapter.overrideHandler = (options) async {
          if (options.method == 'POST' &&
              options.path == '/ai/ask' &&
              shouldReturn504Once) {
            shouldReturn504Once = false;
            final body = Map<String, dynamic>.from(options.data as Map);
            await backend.askAi(
              request: AiAskRequestDto(
                question: body['question'] as String,
                submaterialId: body['submaterial_id'] as String?,
                exerciseQuestionId: body['exercise_question_id'] as String?,
                hintLevel: AiHintLevel.fromValue(
                  (body['hint_level'] as num?)?.toInt() ?? 1,
                ),
              ),
              requestId: options.headers[kIdempotencyHeader]!.toString(),
            );
            return _ContractHttpAdapter.errorEnvelope(
              504,
              ApiErrorCodes.aiTimeout,
              'Permintaan AI melebihi batas waktu.',
            );
          }
          return null;
        };

        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('ai_question_field')),
          'Apa fungsi anotasi tipe pada parameter?',
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('ai_send_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('ai_error_banner')),
          findsOneWidget,
        );

        // Retry after 504 -> must reuse identical Idempotency-Key & handle already_processed.
        await _tapVisible(
          tester,
          find.descendant(
            of: find.byKey(const ValueKey('ai_error_banner')),
            matching: find.text('Coba Lagi'),
          ),
        );
        await tester.pumpAndSettle();

        final askReqs = adapter.capturedRequests
            .where((r) => r.method == 'POST' && r.path == '/ai/ask')
            .toList();
        expect(askReqs, hasLength(2));
        expect(
          askReqs[0].headers[kIdempotencyHeader],
          askReqs[1].headers[kIdempotencyHeader],
        );
        expect(askReqs[0].receiveTimeout, kAiRequestTimeout);
        expect(
          find.byKey(const ValueKey('ai_already_processed_note')),
          findsOneWidget,
        );
        expect(find.text('Sisa kuota hari ini: 9/10'), findsOneWidget);

        // Next ask hits 403 quota_exceeded envelope -> transitions to 0/10 & 00:00 WITA.
        adapter.overrideHandler = (options) async {
          if (options.method == 'POST' && options.path == '/ai/ask') {
            return _ContractHttpAdapter.errorEnvelope(
              403,
              ApiErrorCodes.quotaExceeded,
              'Kuota AI hari ini habis.',
            );
          }
          return null;
        };

        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('ai_question_field')),
          'Pertanyaan lanjutan setelah batas kuota',
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('ai_send_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('ai_quota_exhausted_banner')),
          findsOneWidget,
        );
        expect(find.text('Sisa kuota hari ini: 0/10'), findsOneWidget);
        expect(find.textContaining('00:00 WITA'), findsOneWidget);
        expect(
          tester
              .widget<ElevatedButton>(
                find.byKey(const ValueKey('ai_send_button')),
              )
              .onPressed,
          isNull,
        );
      },
    );
  });
}
