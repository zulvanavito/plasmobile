import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/app.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/router/app_router.dart';
import 'package:plasmobile/core/router/app_routes.dart';
import 'package:plasmobile/core/sync/pending_sync_queue.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/data/dto/student_profile_dto.dart';
import 'package:plasmobile/data/dto/test_dto.dart';
import 'package:plasmobile/data/repositories/mock_plas_repository.dart';
import 'package:plasmobile/data/repositories/mock_seed_data.dart';
import 'package:plasmobile/data/repositories/plas_repository.dart';
import 'package:plasmobile/data/services/auth_service.dart';
import 'package:plasmobile/features/auth/application/session_controller.dart';
import 'package:plasmobile/features/test_eval/presentation/test_result_screen.dart';
import 'package:plasmobile/features/test_eval/presentation/test_session_screen.dart';
import 'package:plasmobile/shared/widgets/confirm_dialog.dart';
import 'package:plasmobile/shared/widgets/owl_bracket_mascot.dart';
import 'package:plasmobile/shared/widgets/plas_accuracy_ring.dart';
import 'package:plasmobile/shared/widgets/plas_bottom_nav.dart';
import 'package:plasmobile/shared/widgets/plas_state_views.dart';
import 'package:plasmobile/shared/widgets/tanya_ai_fab.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeClock {
  _FakeClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration delta) {
    now = now.add(delta);
  }
}

class _TestAuthService implements AuthService {
  _TestAuthService({AuthSessionUser? initialUser}) : _currentUser = initialUser;

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
    throw UnimplementedError();
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
    _currentUser = null;
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}

class _RecordedStartQuestionCall {
  const _RecordedStartQuestionCall({
    required this.attemptId,
    required this.sequence,
    required this.idempotencyKey,
    required this.question,
  });

  final String attemptId;
  final int sequence;
  final String? idempotencyKey;
  final TestActiveQuestionDto question;
}

class _RecordedTestAnswerCall {
  const _RecordedTestAnswerCall({
    required this.attemptId,
    required this.sequence,
    required this.answer,
    required this.submissionRequestId,
  });

  final String attemptId;
  final int sequence;
  final StudentAnswer answer;
  final String submissionRequestId;
}

class _RecordedTestSubmitCall {
  const _RecordedTestSubmitCall({
    required this.attemptId,
    required this.idempotencyKey,
  });

  final String attemptId;
  final String idempotencyKey;
}

class _SpyPlasRepository extends MockPlasRepository {
  _SpyPlasRepository({
    super.clock,
    super.initialProfile,
  });

  final List<String> recordedCreationKeys = <String>[];
  final List<_RecordedStartQuestionCall> recordedStartQuestionCalls =
      <_RecordedStartQuestionCall>[];
  final List<_RecordedTestAnswerCall> recordedAnswerCalls =
      <_RecordedTestAnswerCall>[];
  final List<TestActiveQuestionDto> recordedResumeCalls =
      <TestActiveQuestionDto>[];
  final List<_RecordedTestSubmitCall> recordedSubmitCalls =
      <_RecordedTestSubmitCall>[];
  final List<PendingSyncItem> recordedReplayItems = <PendingSyncItem>[];
  int getMeCallCount = 0;

  bool simulateEmptyPreTest = false;
  bool commitBeforeNextSubmitAnswerError = false;
  PlasApiException? nextSubmitAnswerError;
  PlasApiException? nextStartQuestionError;

  @override
  Future<StudentProfileDto> getMe() async {
    getMeCallCount++;
    return super.getMe();
  }

  @override
  Future<TestsOverviewDto> getTests() async {
    final dto = await super.getTests();
    if (!simulateEmptyPreTest) return dto;
    return TestsOverviewDto(
      preTest: TestOverviewItemDto(
        testId: dto.preTest.testId,
        testType: dto.preTest.testType,
        title: dto.preTest.title,
        questionCount: 0,
        status: dto.preTest.status,
        activeAttemptId: dto.preTest.activeAttemptId,
        score: dto.preTest.score,
        isEligible: dto.preTest.isEligible,
        completedExercises: dto.preTest.completedExercises,
        totalExercises: dto.preTest.totalExercises,
      ),
      postTest: dto.postTest,
    );
  }

  @override
  Future<TestAttemptStartDto> createTestAttempt({
    required String testId,
    required String creationRequestId,
  }) async {
    recordedCreationKeys.add(creationRequestId);
    return super.createTestAttempt(
      testId: testId,
      creationRequestId: creationRequestId,
    );
  }

  @override
  Future<TestActiveQuestionDto> startTestQuestion({
    required String attemptId,
    required int sequence,
    String? idempotencyKey,
  }) async {
    if (nextStartQuestionError != null) {
      final err = nextStartQuestionError!;
      nextStartQuestionError = null;
      throw err;
    }
    final question = await super.startTestQuestion(
      attemptId: attemptId,
      sequence: sequence,
      idempotencyKey: idempotencyKey,
    );
    recordedStartQuestionCalls.add(
      _RecordedStartQuestionCall(
        attemptId: attemptId,
        sequence: sequence,
        idempotencyKey: idempotencyKey,
        question: question,
      ),
    );
    return question;
  }

  @override
  Future<TestAnswerAckDto> submitTestAnswer({
    required String attemptId,
    required int sequence,
    required StudentAnswer answer,
    required String submissionRequestId,
  }) async {
    recordedAnswerCalls.add(
      _RecordedTestAnswerCall(
        attemptId: attemptId,
        sequence: sequence,
        answer: answer,
        submissionRequestId: submissionRequestId,
      ),
    );
    if (nextSubmitAnswerError != null) {
      final err = nextSubmitAnswerError!;
      final shouldCommit = commitBeforeNextSubmitAnswerError;
      nextSubmitAnswerError = null;
      commitBeforeNextSubmitAnswerError = false;
      if (shouldCommit) {
        await super.submitTestAnswer(
          attemptId: attemptId,
          sequence: sequence,
          answer: answer,
          submissionRequestId: submissionRequestId,
        );
      }
      throw err;
    }
    return super.submitTestAnswer(
      attemptId: attemptId,
      sequence: sequence,
      answer: answer,
      submissionRequestId: submissionRequestId,
    );
  }

  @override
  Future<TestActiveQuestionDto> resumeTestAttempt(String attemptId) async {
    final question = await super.resumeTestAttempt(attemptId);
    recordedResumeCalls.add(question);
    return question;
  }

  @override
  Future<TestAttemptResultDto> submitTestAttempt({
    required String attemptId,
    required String idempotencyKey,
  }) async {
    recordedSubmitCalls.add(
      _RecordedTestSubmitCall(
        attemptId: attemptId,
        idempotencyKey: idempotencyKey,
      ),
    );
    return super.submitTestAttempt(
      attemptId: attemptId,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<void> replayPendingSyncItem(PendingSyncItem item) async {
    recordedReplayItems.add(item);
    return super.replayPendingSyncItem(item);
  }
}

AuthSessionUser _defaultUser() => const AuthSessionUser(
      userId: 'test-user-01',
      email: 'andi@plas.ac.id',
      displayName: 'Andi Fajar',
      accessToken: 'test-jwt',
    );

StudentProfileDto _defaultProfile() => StudentProfileDto(
      mahasiswaId: 'mhs-01',
      nama: 'Andi Fajar',
      nim: '2415091001',
      kelas: MockSeedData.classes.first,
      preTestSubmitted: false,
      remainingAiQuota: 10,
    );

Widget _buildApp({
  required SharedPreferences prefs,
  required _TestAuthService authService,
  required PlasRepository repository,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authServiceProvider.overrideWithValue(authService),
      plasRepositoryProvider.overrideWithValue(repository),
    ],
    child: const PlasApp(),
  );
}

String _currentUri(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  final config = container
      .read(appRouterProvider)
      .routerDelegate
      .currentConfiguration;
  if (config.isNotEmpty) {
    final last = config.last;
    if (last is ImperativeRouteMatch) {
      return last.matches.uri.toString();
    }
  }
  return config.uri.toString();
}

Future<void> _pushRoute(WidgetTester tester, String location) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  container.read(appRouterProvider).push(location);
  await tester.pumpAndSettle();
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

Future<void> _completeAllMandatoryExercises(MockPlasRepository repo) async {
  for (final material in MockSeedData.materials) {
    final attempt = await repo.createExerciseAttempt(
      exerciseId: material.exerciseId,
      creationRequestId: 'ex-create-${material.exerciseId}',
    );
    for (final q in material.questions) {
      final StudentAnswer answer = switch (q.questionType) {
        QuestionType.mc => McAnswer(q.correctOptionId!),
        QuestionType.tf => TfAnswer(q.correctBoolean!),
        QuestionType.fib => FibAnswer(q.correctText!),
      };
      await repo.submitExerciseAnswer(
        attemptId: attempt.attemptId,
        questionId: q.questionId,
        answer: answer,
        timeSpentSeconds: 10,
        submissionRequestId: 'ex-ans-${material.exerciseId}-${q.sequence}',
      );
    }
    await repo.submitExerciseAttempt(
      attemptId: attempt.attemptId,
      idempotencyKey: 'ex-sub-${material.exerciseId}',
    );
  }
}

void _assertAssessmentNoAiAndNoTimer(WidgetTester tester) {
  expect(find.byType(PlasBottomNav), findsNothing);
  expect(find.byType(TanyaAiFab), findsNothing);
  expect(find.byType(OwlBracketMascot), findsNothing);
  expect(find.byIcon(Symbols.timer), findsNothing);
  expect(find.textContaining('Tanya AI'), findsNothing);
  expect(find.text('Sebelumnya'), findsNothing);
}

void _assertNoEmDashInTexts(WidgetTester tester) {
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    final text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
    expect(text, isNot(contains('\u2014')));
  }
}

void _assertNoP13LeaksInTree(WidgetTester tester) {
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    final text = (widget.data ?? widget.textSpan?.toPlainText() ?? '').toLowerCase();
    expect(text, isNot(contains('pembahasan')));
    expect(text, isNot(contains('kunci jawaban')));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('M10, M11, & M12 Pre/Post-Test Linear Flow', () {
    testWidgets(
      'M10 linear Pre-Test flow (MC -> TF -> FIB -> confirm dialog -> M12) enforces ENERGY 1, P12, P7, DBR-14, and P13',
      (tester) async {
        final clock = _FakeClock(DateTime.utc(2026, 11, 20, 9, 0));
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(
          clock: clock.call,
          initialProfile: _defaultProfile(),
        );

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        expect(container.read(sessionControllerProvider).isClassLocked, isFalse);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('learn_pre_test_cta')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TestSessionScreen), findsOneWidget);
        _assertAssessmentNoAiAndNoTimer(tester);
        expect(repo.recordedCreationKeys, hasLength(1));
        expect(repo.recordedStartQuestionCalls.map((c) => c.sequence), [1]);

        // Q1: MC
        expect(find.text('Pre-Test'), findsOneWidget);
        expect(find.text('Soal 1 dari 5'), findsOneWidget);
        expect(find.text('MC'), findsOneWidget);
        expect(find.byKey(const ValueKey('test_input_1')), findsOneWidget);

        // Button must be disabled until an answer is selected, and min height >= 48dp.
        final submitCtaFinder = find.byKey(const ValueKey('test_submit_cta'));
        expect(tester.widget<ElevatedButton>(submitCtaFinder).onPressed, isNull);
        expect(tester.getSize(submitCtaFinder).height, greaterThanOrEqualTo(48));

        clock.advance(const Duration(seconds: 12));
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_pre-q1-opt-1')),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<ElevatedButton>(submitCtaFinder).onPressed,
          isNotNull,
        );
        expect(find.text('Kirim & Lanjut ->'), findsOneWidget);

        await _tapVisible(tester, submitCtaFinder);
        await tester.pumpAndSettle();

        // Q2: MC
        expect(repo.recordedStartQuestionCalls.map((c) => c.sequence), [1, 2]);
        expect(find.text('Soal 2 dari 5'), findsOneWidget);
        expect(find.byKey(const ValueKey('test_input_2')), findsOneWidget);
        expect(tester.widget<ElevatedButton>(submitCtaFinder).onPressed, isNull);
        _assertAssessmentNoAiAndNoTimer(tester);

        clock.advance(const Duration(seconds: 10));
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_pre-q2-opt-2')),
        );
        await _tapVisible(tester, submitCtaFinder);
        await tester.pumpAndSettle();

        // Q3: TF
        expect(
          repo.recordedStartQuestionCalls.map((c) => c.sequence),
          [1, 2, 3],
        );
        expect(find.text('Soal 3 dari 5'), findsOneWidget);
        expect(find.text('TF'), findsOneWidget);
        expect(find.byKey(const ValueKey('test_input_3')), findsOneWidget);
        expect(tester.widget<ElevatedButton>(submitCtaFinder).onPressed, isNull);
        _assertAssessmentNoAiAndNoTimer(tester);

        clock.advance(const Duration(seconds: 8));
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_tf_true')),
        );
        await _tapVisible(tester, submitCtaFinder);
        await tester.pumpAndSettle();

        // Q4: FIB
        expect(
          repo.recordedStartQuestionCalls.map((c) => c.sequence),
          [1, 2, 3, 4],
        );
        expect(find.text('Soal 4 dari 5'), findsOneWidget);
        expect(find.text('FIB'), findsOneWidget);
        expect(find.byKey(const ValueKey('test_input_4')), findsOneWidget);
        expect(tester.widget<ElevatedButton>(submitCtaFinder).onPressed, isNull);
        _assertAssessmentNoAiAndNoTimer(tester);

        clock.advance(const Duration(seconds: 15));
        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('question_fib_field')),
          'string',
        );
        await _tapVisible(tester, submitCtaFinder);
        await tester.pumpAndSettle();

        // Q5: FIB (final question -> 'Kirim & Selesai ->', intentionally wrong for 80% score)
        expect(
          repo.recordedStartQuestionCalls.map((c) => c.sequence),
          [1, 2, 3, 4, 5],
        );
        expect(find.text('Soal 5 dari 5'), findsOneWidget);
        expect(find.text('FIB'), findsOneWidget);
        expect(find.byKey(const ValueKey('test_input_5')), findsOneWidget);
        expect(find.text('Kirim & Selesai ->'), findsOneWidget);
        expect(tester.widget<ElevatedButton>(submitCtaFinder).onPressed, isNull);
        _assertAssessmentNoAiAndNoTimer(tester);

        clock.advance(const Duration(seconds: 9));
        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('question_fib_field')),
          'wrong_keyword',
        );
        await _tapVisible(tester, submitCtaFinder);
        await tester.pumpAndSettle();

        // Confirm dialog appears before submitTestAttempt.
        expect(find.byType(PlasConfirmDialog), findsOneWidget);
        expect(find.text('Kumpulkan Pre-Test?'), findsOneWidget);
        expect(repo.recordedSubmitCalls, isEmpty);

        final meCallsBeforeSubmit = repo.getMeCallCount;
        await _tapVisible(
          tester,
          find.descendant(
            of: find.byType(PlasConfirmDialog),
            matching: find.text('Kumpulkan Pre-Test'),
          ),
        );
        await tester.pumpAndSettle();

        // DBR-14: refreshProfile() was called before navigating to M12.
        expect(repo.getMeCallCount, greaterThan(meCallsBeforeSubmit));
        expect(container.read(sessionControllerProvider).isClassLocked, isTrue);

        // Routed cleanly to M12 TestResultScreen.
        expect(find.byType(TestResultScreen), findsOneWidget);
        expect(_currentUri(tester), '/test-attempts/test-att-1/result');
        expect(find.text('Hasil Pre-Test'), findsNWidgets(2));
        expect(find.text('SUBMITTED'), findsOneWidget);
        expect(find.text('80%'), findsOneWidget);
        expect(find.text('Skor'), findsOneWidget);
        expect(
          find.text('Kelas Anda terkunci setelah Pre-Test dikumpulkan (DBR-14).'),
          findsOneWidget,
        );

        final ringPainter = tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(PlasAccuracyRing),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter! as PlasAccuracyRingPainter;
        expect(ringPainter.arcColor, PlasColors.brandPrimary);

        expect(find.text('54 detik'), findsOneWidget);
        expect(find.text('Benar'), findsNWidgets(5)); // 1 stat tile + 4 item badges
        expect(find.text('Salah'), findsNWidgets(2)); // 1 stat tile + 1 item badge
        expect(find.text('12 detik'), findsOneWidget);
        expect(find.text('10 detik'), findsOneWidget);
        expect(find.text('8 detik'), findsOneWidget);
        expect(find.text('15 detik'), findsOneWidget);
        expect(find.text('9 detik'), findsOneWidget);

        // P13 strict check: ZERO Pembahasan / Kunci Jawaban, ZERO Mascot/FAB.
        _assertNoP13LeaksInTree(tester);
        expect(find.byType(TanyaAiFab), findsNothing);
        expect(find.byType(OwlBracketMascot), findsNothing);

        final homeBtnFinder = find.byKey(const ValueKey('test_result_home_button'));
        expect(tester.getSize(homeBtnFinder).height, greaterThanOrEqualTo(48));
        await _tapVisible(tester, homeBtnFinder);
        await tester.pumpAndSettle();

        expect(find.byType(TestResultScreen), findsNothing);
        expect(_currentUri(tester), AppRoutes.learn);
      },
    );

    testWidgets(
      'M11 Resume IN_PROGRESS displays warning card, preserves frozen MC snapshot order & questionStartedAt (P7), and handles PopScope exit confirmation cleanly',
      (tester) async {
        final clock = _FakeClock(DateTime.utc(2026, 11, 20, 10, 0));
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(
          clock: clock.call,
          initialProfile: _defaultProfile(),
        );

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        // Enter Pre-Test, answer Q1 -> advances to Q2 (MC) which freezes options & records questionStartedAt.
        await _pushRoute(tester, AppRoutes.testSession('test-pre-01'));
        clock.advance(const Duration(seconds: 7));
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_pre-q1-opt-1')),
        );
        await _tapVisible(tester, find.byKey(const ValueKey('test_submit_cta')));
        await tester.pumpAndSettle();

        expect(find.text('Soal 2 dari 5'), findsOneWidget);
        final q2StartCall = repo.recordedStartQuestionCalls.last;
        expect(q2StartCall.sequence, 2);
        final originalQ2Order =
            q2StartCall.question.options.map((o) => o.optionId).toList();
        final originalQ2StartedAt = q2StartCall.question.questionStartedAt;

        // AppBar exit button triggers 'Keluar Sementara dari Tes?' -> confirm exits to LearnHomeScreen.
        await _tapVisible(tester, find.byKey(const ValueKey('test_exit_button')));
        await tester.pumpAndSettle();
        expect(find.byType(PlasConfirmDialog), findsOneWidget);
        expect(find.text('Keluar Sementara dari Tes?'), findsOneWidget);
        expect(find.textContaining('IN_PROGRESS'), findsOneWidget);

        await _tapVisible(tester, find.text('Keluar Sementara'));
        await tester.pumpAndSettle();
        expect(find.byType(TestSessionScreen), findsNothing);
        expect(repo.recordedSubmitCalls, isEmpty);

        // Advance clock by 45s to prove questionStartedAt is NOT overwritten on resume.
        clock.advance(const Duration(seconds: 45));

        // Re-enter session -> M11 Resume view appears.
        await _pushRoute(tester, AppRoutes.testSession('test-pre-01'));
        expect(find.byKey(const ValueKey('test_resume_view')), findsOneWidget);
        _assertAssessmentNoAiAndNoTimer(tester);

        final warningCard = tester.widget<Container>(
          find.byKey(const ValueKey('test_resume_warning_card')),
        );
        final warningDeco = warningCard.decoration! as BoxDecoration;
        expect(warningDeco.color, PlasColors.warningBg);
        expect(find.text('IN_PROGRESS'), findsOneWidget);
        expect(find.byKey(const ValueKey('test_resume_back_button')), findsOneWidget);

        await _tapVisible(tester, find.byKey(const ValueKey('test_resume_cta')));
        await tester.pumpAndSettle();

        expect(repo.recordedResumeCalls, hasLength(1));
        final resumedQ2 = repo.recordedResumeCalls.single;
        expect(resumedQ2.sequence, 2);
        expect(resumedQ2.questionStartedAt, originalQ2StartedAt);
        expect(
          resumedQ2.options.map((o) => o.optionId).toList(),
          originalQ2Order,
        );

        // Verify compact #FFFBEB M11 banner & exact UI order of frozen MC options.
        final resumedBanner = tester.widget<Container>(
          find.byKey(const ValueKey('test_resumed_banner')),
        );
        expect(
          (resumedBanner.decoration! as BoxDecoration).color,
          PlasColors.warningBg,
        );
        expect(find.text('Melanjutkan sesi IN_PROGRESS'), findsOneWidget);
        expect(find.text('Soal 2 dari 5'), findsOneWidget);

        var prevTop = -1.0;
        for (final optId in originalQ2Order) {
          final dy = tester
              .getTopLeft(find.byKey(ValueKey('question_mc_option_$optId')))
              .dy;
          expect(dy, greaterThan(prevTop));
          prevTop = dy;
        }

        // Trigger PopScope via Navigator.maybePop() and cancel -> stays on Q2 without submitting.
        unawaited(
          Navigator.of(tester.element(find.byType(TestSessionScreen)))
              .maybePop(),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PlasConfirmDialog), findsOneWidget);
        expect(find.text('Keluar Sementara dari Tes?'), findsOneWidget);

        await _tapVisible(tester, find.text('Batal'));
        await tester.pumpAndSettle();
        expect(find.byType(TestSessionScreen), findsOneWidget);
        expect(find.text('Soal 2 dari 5'), findsOneWidget);
        expect(repo.recordedSubmitCalls, isEmpty);
      },
    );

    testWidgets(
      'Cancel on final submit confirm dialog keeps Semua Soal Terjawab recovery without 409 duplicate answer, and offline answer/submit queue replays with exact UUID keys',
      (tester) async {
        final clock = _FakeClock(DateTime.utc(2026, 11, 20, 11, 0));
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(
          clock: clock.call,
          initialProfile: _defaultProfile(),
        );

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        await _pushRoute(tester, AppRoutes.testSession('test-pre-01'));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(TestSessionScreen)),
        );

        // Answer Q1..Q4 online.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_pre-q1-opt-1')),
        );
        await _tapVisible(tester, find.byKey(const ValueKey('test_submit_cta')));
        await tester.pumpAndSettle();

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_pre-q2-opt-2')),
        );
        await _tapVisible(tester, find.byKey(const ValueKey('test_submit_cta')));
        await tester.pumpAndSettle();

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_tf_true')),
        );
        await _tapVisible(tester, find.byKey(const ValueKey('test_submit_cta')));
        await tester.pumpAndSettle();

        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('question_fib_field')),
          'string',
        );
        await _tapVisible(tester, find.byKey(const ValueKey('test_submit_cta')));
        await tester.pumpAndSettle();

        expect(find.text('Soal 5 dari 5'), findsOneWidget);

        // Go offline on Q5 and submit answer -> queued in pendingSyncProvider.
        repo.simulateOffline = true;
        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('question_fib_field')),
          'return',
        );
        await _tapVisible(tester, find.byKey(const ValueKey('test_submit_cta')));
        await tester.pumpAndSettle();

        expect(find.byType(PlasOfflineSyncBanner), findsOneWidget);
        expect(
          tester
              .widget<ElevatedButton>(
                find.byKey(const ValueKey('test_submit_cta')),
              )
              .onPressed,
          isNull,
        );

        final queuedAfterQ5 = container.read(pendingSyncProvider);
        expect(queuedAfterQ5, hasLength(1));
        expect(
          queuedAfterQ5.single.path,
          '/test-attempts/test-att-1/questions/5/answers',
        );
        final q5AnswerKey = queuedAfterQ5.single.idempotencyKey;
        expect(q5AnswerKey, repo.recordedAnswerCalls.last.submissionRequestId);

        // Retrying while offline preserves queued item.
        await _tapVisible(tester, find.text('Kirim Ulang Sekarang'));
        await tester.pumpAndSettle();
        expect(container.read(pendingSyncProvider), hasLength(1));

        // Reconnect and replay Q5 answer -> opens final submit confirmation dialog.
        repo.simulateOffline = false;
        await _tapVisible(tester, find.text('Kirim Ulang Sekarang'));
        await tester.pumpAndSettle();

        expect(container.read(pendingSyncProvider), isEmpty);
        expect(repo.recordedReplayItems.map((e) => e.idempotencyKey), [
          q5AnswerKey,
          q5AnswerKey,
        ]);
        expect(repo.recordedAnswerCalls.last.submissionRequestId, q5AnswerKey);
        expect(find.byType(PlasConfirmDialog), findsOneWidget);
        expect(find.text('Kumpulkan Pre-Test?'), findsOneWidget);

        // Cancel dialog -> renders 'Semua Soal Terjawab' with 'Kumpulkan Pre-Test' CTA.
        final answerCallCountAfterQ5 = repo.recordedAnswerCalls.length;
        await _tapVisible(tester, find.text('Batal'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('test_ready_to_submit_view')),
          findsOneWidget,
        );
        expect(find.text('Semua Soal Terjawab'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('test_final_submit_cta')),
          findsOneWidget,
        );
        expect(repo.recordedAnswerCalls, hasLength(answerCallCountAfterQ5));
        expect(repo.recordedSubmitCalls, isEmpty);

        // Go offline before tapping 'Kumpulkan Pre-Test' -> queues /submit.
        repo.simulateOffline = true;
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('test_final_submit_cta')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PlasConfirmDialog), findsOneWidget);
        await _tapVisible(
          tester,
          find.descendant(
            of: find.byType(PlasConfirmDialog),
            matching: find.text('Kumpulkan Pre-Test'),
          ),
        );
        await tester.pumpAndSettle();

        expect(repo.recordedAnswerCalls, hasLength(answerCallCountAfterQ5));
        final queuedSubmit = container.read(pendingSyncProvider);
        expect(queuedSubmit, hasLength(1));
        expect(queuedSubmit.single.path, '/test-attempts/test-att-1/submit');
        final submitKey = queuedSubmit.single.idempotencyKey;
        expect(submitKey, repo.recordedSubmitCalls.last.idempotencyKey);
        expect(find.byType(PlasOfflineSyncBanner), findsOneWidget);

        // Reconnect and replay -> DBR-14 lock updates & transitions to M12.
        repo.recordedReplayItems.clear();
        repo.simulateOffline = false;
        await _tapVisible(tester, find.text('Kirim Ulang Sekarang'));
        await tester.pumpAndSettle();

        expect(container.read(pendingSyncProvider), isEmpty);
        expect(repo.recordedReplayItems.map((e) => e.idempotencyKey), [
          submitKey,
        ]);
        expect(repo.recordedSubmitCalls.last.idempotencyKey, submitKey);
        expect(container.read(sessionControllerProvider).isClassLocked, isTrue);
        expect(find.byType(TestResultScreen), findsOneWidget);
        expect(find.text('100%'), findsOneWidget);
      },
    );

    testWidgets(
      'Handles DBR-15 prerequisite error, 422 test_empty, 404 not_found, submitted-status auto redirect, and 409 attempt_submitted on resume',
      (tester) async {
        final clock = _FakeClock(DateTime.utc(2026, 11, 20, 12, 0));
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(
          clock: clock.call,
          initialProfile: _defaultProfile(),
        );

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        // 1. DBR-15: Navigating directly to ineligible Post-Test renders PlasErrorView.
        await _pushRoute(tester, AppRoutes.testSession('test-post-01'));
        expect(find.byKey(const ValueKey('test_load_error_view')), findsOneWidget);
        expect(
          find.text(plasErrorMessage(ApiErrorCodes.prerequisiteNotMet)),
          findsOneWidget,
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('test_error_back_button')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TestSessionScreen), findsNothing);

        // 2. 422 test_empty
        repo.simulateEmptyPreTest = true;
        await _pushRoute(tester, AppRoutes.testSession('test-pre-01'));
        expect(find.byKey(const ValueKey('test_load_error_view')), findsOneWidget);
        expect(
          find.text(plasErrorMessage(ApiErrorCodes.testEmpty)),
          findsOneWidget,
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('test_error_back_button')),
        );
        await tester.pumpAndSettle();
        repo.simulateEmptyPreTest = false;

        // 3. 404 not_found
        await _pushRoute(tester, AppRoutes.testSession('test-unknown-id'));
        expect(find.byKey(const ValueKey('test_load_error_view')), findsOneWidget);
        expect(
          find.text(plasErrorMessage(ApiErrorCodes.notFound)),
          findsOneWidget,
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('test_error_back_button')),
        );
        await tester.pumpAndSettle();

        // 4. resumeTestAttempt throwing 409 attempt_submitted routes to M12.
        final started = await repo.createTestAttempt(
          testId: 'test-pre-01',
          creationRequestId: 'pre-create-direct',
        );
        for (var seq = 1; seq <= 5; seq++) {
          final qSeed = MockSeedData.preTest.questions[seq - 1];
          await repo.startTestQuestion(
            attemptId: started.attemptId,
            sequence: seq,
          );
          final StudentAnswer ans = switch (qSeed.questionType) {
            QuestionType.mc => McAnswer(qSeed.correctOptionId!),
            QuestionType.tf => TfAnswer(qSeed.correctBoolean!),
            QuestionType.fib => FibAnswer(qSeed.correctText!),
          };
          await repo.submitTestAnswer(
            attemptId: started.attemptId,
            sequence: seq,
            answer: ans,
            submissionRequestId: 'pre-ans-direct-$seq',
          );
        }
        await repo.submitTestAttempt(
          attemptId: started.attemptId,
          idempotencyKey: 'pre-sub-direct',
        );
        // Simulate overview returning SUBMITTED -> direct redirect to M12.
        await _pushRoute(tester, AppRoutes.testSession('test-pre-01'));
        expect(find.byType(TestResultScreen), findsOneWidget);
        expect(
          _currentUri(tester),
          '/test-attempts/${started.attemptId}/result',
        );

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('test_result_home_button')),
        );
        await tester.pumpAndSettle();

        // 5. Complete all 7 mandatory exercises -> Post-Test becomes eligible and M12 omits Pre-Test lock note.
        await _completeAllMandatoryExercises(repo);
        await _pushRoute(tester, AppRoutes.testSession('test-post-01'));
        expect(find.text('Post-Test'), findsOneWidget);
        expect(find.text('Soal 1 dari 5'), findsOneWidget);

        // Also verify 409 attempt_submitted during resumeTestAttempt routes cleanly to M12.
        await _tapVisible(tester, find.byKey(const ValueKey('test_exit_button')));
        await tester.pumpAndSettle();
        await _tapVisible(tester, find.text('Keluar Sementara'));
        await tester.pumpAndSettle();

        // Re-open M11 Resume view while Post-Test is still IN_PROGRESS.
        await _pushRoute(tester, AppRoutes.testSession('test-post-01'));
        expect(find.byKey(const ValueKey('test_resume_view')), findsOneWidget);

        // Submit the attempt behind the scenes before tapping 'Lanjutkan Tes ->'.
        final postOverview = (await repo.getTests()).postTest;
        final postAttemptId = postOverview.activeAttemptId!;
        for (var seq = 1; seq <= 5; seq++) {
          final qSeed = MockSeedData.postTest.questions[seq - 1];
          await repo.startTestQuestion(attemptId: postAttemptId, sequence: seq);
          final StudentAnswer ans = switch (qSeed.questionType) {
            QuestionType.mc => McAnswer(qSeed.correctOptionId!),
            QuestionType.tf => TfAnswer(qSeed.correctBoolean!),
            QuestionType.fib => FibAnswer(qSeed.correctText!),
          };
          await repo.submitTestAnswer(
            attemptId: postAttemptId,
            sequence: seq,
            answer: ans,
            submissionRequestId: 'post-ans-$seq',
          );
        }
        await repo.submitTestAttempt(
          attemptId: postAttemptId,
          idempotencyKey: 'post-sub',
        );

        // Tapping 'Lanjutkan Tes ->' triggers 409 attempt_submitted and redirects to M12.
        await _tapVisible(tester, find.byKey(const ValueKey('test_resume_cta')));
        await tester.pumpAndSettle();

        expect(find.byType(TestResultScreen), findsOneWidget);
        expect(_currentUri(tester), '/test-attempts/$postAttemptId/result');
        expect(find.text('Hasil Post-Test'), findsNWidgets(2));
        expect(
          find.byKey(const ValueKey('test_result_class_lock_note')),
          findsNothing,
        );
        _assertNoP13LeaksInTree(tester);
      },
    );

    testWidgets(
      'BUG-002 & BUG-006: Changing answer after 500 error mints new key, and 409 already_answered sets pendingNextSequence across startTestQuestion failure',
      (tester) async {
        final clock = _FakeClock(DateTime.utc(2026, 11, 20, 13, 0));
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(
          clock: clock.call,
          initialProfile: _defaultProfile(),
        );

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        await _pushRoute(tester, AppRoutes.testSession('test-pre-01'));
        expect(find.text('Soal 1 dari 5'), findsOneWidget);

        // Q1: fail with 500 -> change option -> must mint fresh submissionRequestId.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_pre-q1-opt-2')),
        );
        repo.commitBeforeNextSubmitAnswerError = false;
        repo.nextSubmitAnswerError = PlasApiException.fromApiCode(
          ApiErrorCodes.serverError,
          statusCode: 500,
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('test_submit_cta')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('test_submission_error_view')),
          findsOneWidget,
        );
        expect(repo.recordedAnswerCalls, hasLength(1));
        final q1FirstKey = repo.recordedAnswerCalls.first.submissionRequestId;

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_pre-q1-opt-1')),
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('test_submit_cta')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Soal 2 dari 5'), findsOneWidget);
        expect(repo.recordedAnswerCalls, hasLength(2));
        expect(repo.recordedAnswerCalls[1].submissionRequestId, isNot(q1FirstKey));
        expect(
          repo.recordedAnswerCalls[1].answer,
          const McAnswer('pre-q1-opt-1'),
        );

        // Q2: simulate 409 already_answered followed by transient 500 on startTestQuestion(3).
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_pre-q2-opt-2')),
        );
        repo.commitBeforeNextSubmitAnswerError = true;
        repo.nextSubmitAnswerError = PlasApiException.fromApiCode(
          ApiErrorCodes.alreadyAnswered,
          statusCode: 409,
        );
        repo.nextStartQuestionError = PlasApiException.fromApiCode(
          ApiErrorCodes.serverError,
          statusCode: 500,
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('test_submit_cta')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('test_submission_error_view')),
          findsOneWidget,
        );
        expect(find.text('Soal 2 dari 5'), findsOneWidget);
        expect(
          repo.recordedAnswerCalls.where((c) => c.sequence == 2),
          hasLength(1),
        );

        // Retrying CTA must advance directly to Q3 without re-calling submitTestAnswer(2).
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('test_submit_cta')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Soal 3 dari 5'), findsOneWidget);
        expect(
          repo.recordedAnswerCalls.where((c) => c.sequence == 2),
          hasLength(1),
        );
      },
    );

    testWidgets(
      'Renders M10, M11 Resume, dialogs, and M12 at 390x844 @ 2.0x text scale with zero overflow and zero em dashes',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final clock = _FakeClock(DateTime.utc(2026, 11, 20, 14, 0));
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(
          clock: clock.call,
          initialProfile: _defaultProfile(),
        );

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        // 1. M10 Q1 (MC) @ 2.0x
        await _pushRoute(tester, AppRoutes.testSession('test-pre-01'));
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);
        _assertAssessmentNoAiAndNoTimer(tester);

        // Answer Q1 and advance to Q2.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_pre-q1-opt-1')),
        );
        await _tapVisible(tester, find.byKey(const ValueKey('test_submit_cta')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);

        // Open exit confirmation dialog @ 2.0x and confirm exit.
        await _tapVisible(tester, find.byKey(const ValueKey('test_exit_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);
        await _tapVisible(tester, find.text('Keluar Sementara'));
        await tester.pumpAndSettle();

        // 2. M11 Resume View @ 2.0x
        await _pushRoute(tester, AppRoutes.testSession('test-pre-01'));
        expect(find.byKey(const ValueKey('test_resume_view')), findsOneWidget);
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);
        _assertAssessmentNoAiAndNoTimer(tester);

        await _tapVisible(tester, find.byKey(const ValueKey('test_resume_cta')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);

        // Answer Q2 (MC) -> Q3 (TF) @ 2.0x
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_pre-q2-opt-2')),
        );
        await _tapVisible(tester, find.byKey(const ValueKey('test_submit_cta')));
        await tester.pumpAndSettle();
        expect(find.text('Soal 3 dari 5'), findsOneWidget);
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);

        // Answer Q3 (TF) -> Q4 (FIB) @ 2.0x
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_tf_true')),
        );
        await _tapVisible(tester, find.byKey(const ValueKey('test_submit_cta')));
        await tester.pumpAndSettle();
        expect(find.text('Soal 4 dari 5'), findsOneWidget);
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);

        // Answer Q4 (FIB) -> Q5 (FIB) @ 2.0x
        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('question_fib_field')),
          'string',
        );
        await _tapVisible(tester, find.byKey(const ValueKey('test_submit_cta')));
        await tester.pumpAndSettle();
        expect(find.text('Soal 5 dari 5'), findsOneWidget);
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);

        // Answer Q5 (FIB) -> cancel submit dialog -> 'Semua Soal Terjawab' @ 2.0x
        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('question_fib_field')),
          'return',
        );
        await _tapVisible(tester, find.byKey(const ValueKey('test_submit_cta')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);

        await _tapVisible(tester, find.text('Batal'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('test_ready_to_submit_view')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);

        // Submit -> M12 @ 2.0x
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('test_final_submit_cta')),
        );
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
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);
        _assertNoP13LeaksInTree(tester);

        await tester.ensureVisible(
          find.byKey(const ValueKey('test_result_home_button')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
