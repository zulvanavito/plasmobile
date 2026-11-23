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
import 'package:plasmobile/data/dto/ai_dto.dart';
import 'package:plasmobile/data/dto/progress_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/data/dto/student_profile_dto.dart';
import 'package:plasmobile/data/dto/test_dto.dart';
import 'package:plasmobile/data/repositories/mock_plas_repository.dart';
import 'package:plasmobile/data/repositories/mock_seed_data.dart';
import 'package:plasmobile/data/repositories/plas_repository.dart';
import 'package:plasmobile/data/services/auth_service.dart';
import 'package:plasmobile/features/auth/application/session_controller.dart';
import 'package:plasmobile/features/auth/presentation/auth_screen.dart';
import 'package:plasmobile/features/auth/presentation/onboarding_class_screen.dart';
import 'package:plasmobile/features/exercise/presentation/exercise_review_screen.dart';
import 'package:plasmobile/features/exercise/presentation/exercise_session_screen.dart';
import 'package:plasmobile/features/history/presentation/history_screen.dart';
import 'package:plasmobile/features/learn/presentation/learn_home_screen.dart';
import 'package:plasmobile/features/profile/presentation/profile_screen.dart';
import 'package:plasmobile/features/test_eval/presentation/test_result_screen.dart';
import 'package:plasmobile/features/test_eval/presentation/test_session_screen.dart';
import 'package:plasmobile/shared/widgets/confirm_dialog.dart';
import 'package:plasmobile/shared/widgets/owl_bracket_mascot.dart';
import 'package:plasmobile/shared/widgets/plas_state_views.dart';
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
  int signOutCallCount = 0;

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
    signOutCallCount++;
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

class _SpyPlasRepository extends MockPlasRepository {
  _SpyPlasRepository({
    super.clock,
    super.initialProfile,
  });

  int getMeCalls = 0;
  int getTestsCalls = 0;
  int getActivitiesCalls = 0;
  int getAiQuotaCalls = 0;
  int getClassesCalls = 0;
  final List<String?> updatedClassIds = <String?>[];
  final List<PendingSyncItem> replayedItems = <PendingSyncItem>[];
  PlasApiException? nextActivitiesError;

  @override
  Future<StudentProfileDto> getMe() async {
    getMeCalls++;
    return super.getMe();
  }

  @override
  Future<List<ClassInfoDto>> getClasses() async {
    getClassesCalls++;
    return super.getClasses();
  }

  @override
  Future<StudentProfileDto> updateClass(String? kelasId) async {
    updatedClassIds.add(kelasId);
    return super.updateClass(kelasId);
  }

  @override
  Future<TestsOverviewDto> getTests() async {
    getTestsCalls++;
    return super.getTests();
  }

  @override
  Future<List<ActivityItemDto>> getActivities() async {
    getActivitiesCalls++;
    if (nextActivitiesError != null) {
      final error = nextActivitiesError!;
      nextActivitiesError = null;
      throw error;
    }
    return super.getActivities();
  }

  @override
  Future<AiQuotaDto> getAiQuota() async {
    getAiQuotaCalls++;
    return super.getAiQuota();
  }

  @override
  Future<void> replayPendingSyncItem(PendingSyncItem item) async {
    replayedItems.add(item);
    return super.replayPendingSyncItem(item);
  }
}

AuthSessionUser _defaultUser() => const AuthSessionUser(
      userId: 'test-user-01',
      email: 'andi@plas.ac.id',
      displayName: 'Andi Fajar',
      accessToken: 'test-jwt',
    );

StudentProfileDto _defaultProfile({
  bool withClass = true,
  bool preTestSubmitted = false,
  int remainingAiQuota = 10,
}) {
  return StudentProfileDto(
    mahasiswaId: 'mhs-01',
    nama: 'Andi Fajar',
    nim: '2415091001',
    kelas: withClass ? MockSeedData.classes.first : null,
    preTestSubmitted: preTestSubmitted,
    remainingAiQuota: remainingAiQuota,
  );
}

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

Future<String> _completeExercise(
  MockPlasRepository repo, {
  required String exerciseId,
  required String keyPrefix,
}) async {
  final attempt = await repo.createExerciseAttempt(
    exerciseId: exerciseId,
    creationRequestId: '$keyPrefix-create',
  );
  final seed = MockSeedData.findByExerciseId(exerciseId)!;
  for (final q in seed.questions) {
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
      submissionRequestId: '$keyPrefix-ans-${q.sequence}',
    );
  }
  await repo.submitExerciseAttempt(
    attemptId: attempt.attemptId,
    idempotencyKey: '$keyPrefix-submit',
  );
  return attempt.attemptId;
}

Future<String> _completeTest(
  MockPlasRepository repo, {
  required String testId,
  required String keyPrefix,
  bool missLastQuestion = false,
}) async {
  final start = await repo.createTestAttempt(
    testId: testId,
    creationRequestId: '$keyPrefix-create',
  );
  final seed = MockSeedData.findTest(testId)!;
  for (final q in seed.questions) {
    await repo.startTestQuestion(
      attemptId: start.attemptId,
      sequence: q.sequence,
    );
    final isLastWrong = missLastQuestion && q.sequence == seed.questions.length;
    final StudentAnswer answer = switch (q.questionType) {
      QuestionType.mc => McAnswer(q.correctOptionId!),
      QuestionType.tf => TfAnswer(q.correctBoolean!),
      QuestionType.fib => FibAnswer(
          isLastWrong ? 'wrong_answer' : q.correctText!,
        ),
    };
    await repo.submitTestAnswer(
      attemptId: start.attemptId,
      sequence: q.sequence,
      answer: answer,
      submissionRequestId: '$keyPrefix-ans-${q.sequence}',
    );
  }
  await repo.submitTestAttempt(
    attemptId: start.attemptId,
    idempotencyKey: '$keyPrefix-submit',
  );
  return start.attemptId;
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

  group('M14 HistoryScreen (Riwayat Latihan & Tes)', () {
    testWidgets(
      'renders empty state PlasEmptyView -> Mulai Belajar to /learn and DBR-15 locked Post-Test card',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(initialProfile: _defaultProfile());

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LearnHomeScreen), findsOneWidget);

        await _tapVisible(tester, find.text('Riwayat'));
        await tester.pumpAndSettle();

        expect(find.byType(HistoryScreen), findsOneWidget);
        expect(_currentUri(tester), AppRoutes.history);
        expect(find.text('CS LAB ENV // RIWAYAT'), findsOneWidget);
        expect(find.text('Riwayat Latihan & Tes'), findsOneWidget);

        // Pre-Test Belum Mulai, Post-Test Terkunci (DBR-15).
        expect(find.text('Belum Mulai'), findsOneWidget);
        expect(find.text('Terkunci'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('history_post_test_lock_banner')),
          findsOneWidget,
        );
        final postCta = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('history_post_test_cta')),
        );
        expect(postCta.onPressed, isNull);

        // Empty activity list renders PlasEmptyView with Mulai Belajar -> /learn.
        expect(find.byType(PlasEmptyView), findsOneWidget);
        expect(find.text('Belum Ada Riwayat Latihan'), findsOneWidget);
        expect(find.byType(OwlBracketMascot), findsOneWidget);

        await _tapVisible(tester, find.text('Mulai Belajar'));
        await tester.pumpAndSettle();

        expect(_currentUri(tester), AppRoutes.learn);
        expect(find.byType(LearnHomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      'navigates Pre/Post cards (M12 & M10), displays WITA exercise cards (M13 & M08), filters Semua/Selesai/Berlangsung, and handles filtered empty state',
      (tester) async {
        // 16:15 UTC == 00:15 WITA next day (tests Asia/Makassar UTC+8 rollover).
        final clock = _FakeClock(DateTime.utc(2026, 11, 20, 16, 15));
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(
          clock: clock.call,
          initialProfile: _defaultProfile(),
        );

        // Pre-Test submitted with 80% score (4/5 correct).
        final preAttemptId = await _completeTest(
          repo,
          testId: MockSeedData.preTest.testId,
          keyPrefix: 'hist-pre',
          missLastQuestion: true,
        );

        // Exercise 1 SUBMITTED at 21 Nov 2026, 00:15 WITA.
        final ex1AttemptId = await _completeExercise(
          repo,
          exerciseId: 'ex-01',
          keyPrefix: 'hist-ex1',
        );

        // Exercise 2 IN_PROGRESS at 21 Nov 2026, 00:30 WITA.
        clock.advance(const Duration(minutes: 15));
        final ex2Attempt = await repo.createExerciseAttempt(
          exerciseId: 'ex-02',
          creationRequestId: 'hist-ex2-create',
        );

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        await _tapVisible(tester, find.text('Riwayat'));
        await tester.pumpAndSettle();

        expect(find.byType(HistoryScreen), findsOneWidget);

        // Pre-Test SUBMITTED card shows 80% and opens M12.
        expect(find.text('Skor: 80%'), findsOneWidget);
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('history_pre_test_cta')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TestResultScreen), findsOneWidget);
        expect(_currentUri(tester), '/test-attempts/$preAttemptId/result');

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('test_result_back_button')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(HistoryScreen), findsOneWidget);

        // Exercise cards show material, submaterial, type, Attempt 1/3, status, score, WITA timestamp (no WIB).
        expect(find.text('Struktur Dasar Kode TypeScript'), findsOneWidget);
        expect(find.text('Berkas TypeScript dan Kompilasi tsc'), findsOneWidget);
        expect(find.text('MC'), findsOneWidget);
        expect(find.text('Skor: 100%'), findsOneWidget);
        expect(
          find.text('Dikumpulkan 21 Nov 2026, 00:15 WITA'),
          findsOneWidget,
        );

        expect(find.text('Variabel & Type Annotation'), findsOneWidget);
        expect(
          find.text('Deklarasi let, const, dan Type Annotation'),
          findsOneWidget,
        );
        expect(find.text('FIB'), findsOneWidget);
        expect(find.text('Dimulai 21 Nov 2026, 00:30 WITA'), findsOneWidget);
        expect(find.text('Attempt 1/3'), findsNWidgets(2));
        expect(find.text('SUBMITTED'), findsNWidgets(2)); // Pre-Test + ex-01
        expect(find.text('IN_PROGRESS'), findsOneWidget); // ex-02
        expect(find.textContaining('WIB'), findsNothing);

        // Min touch target checks >= 48dp for filter pills & cards.
        for (final key in [
          const ValueKey('history_filter_all'),
          const ValueKey('history_filter_submitted'),
          const ValueKey('history_filter_in_progress'),
          ValueKey('history_activity_card_$ex1AttemptId'),
          ValueKey('history_activity_card_${ex2Attempt.attemptId}'),
        ]) {
          final size = tester.getSize(find.byKey(key));
          expect(size.height, greaterThanOrEqualTo(48.0));
          expect(size.width, greaterThanOrEqualTo(48.0));
        }

        // Filter: Selesai -> only ex-01.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('history_filter_submitted')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('history_activity_card_$ex1AttemptId')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('history_activity_card_${ex2Attempt.attemptId}')),
          findsNothing,
        );

        // Filter: Berlangsung -> only ex-02.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('history_filter_in_progress')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('history_activity_card_$ex1AttemptId')),
          findsNothing,
        );
        expect(
          find.byKey(ValueKey('history_activity_card_${ex2Attempt.attemptId}')),
          findsOneWidget,
        );

        // Filter: Semua -> both visible.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('history_filter_all')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('history_activity_card_$ex1AttemptId')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('history_activity_card_${ex2Attempt.attemptId}')),
          findsOneWidget,
        );

        // Tap SUBMITTED card -> M13 ExerciseReviewScreen.
        await _tapVisible(
          tester,
          find.byKey(ValueKey('history_activity_card_$ex1AttemptId')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ExerciseReviewScreen), findsOneWidget);
        expect(_currentUri(tester), '/exercise-attempts/$ex1AttemptId/review');

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('review_back_button')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(HistoryScreen), findsOneWidget);

        // Tap IN_PROGRESS card -> M08 ExerciseSessionScreen.
        await _tapVisible(
          tester,
          find.byKey(ValueKey('history_activity_card_${ex2Attempt.attemptId}')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ExerciseSessionScreen), findsOneWidget);
        expect(_currentUri(tester), '/exercises/ex-02/session');

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_back_button')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(HistoryScreen), findsOneWidget);

        // Complete ex-02 in repository, pull-to-refresh, then test filtered empty state.
        final seed2 = MockSeedData.findByExerciseId('ex-02')!;
        for (final q in seed2.questions) {
          await repo.submitExerciseAnswer(
            attemptId: ex2Attempt.attemptId,
            questionId: q.questionId,
            answer: FibAnswer(q.correctText!),
            timeSpentSeconds: 10,
            submissionRequestId: 'hist-ex2-ans-${q.sequence}',
          );
        }
        await repo.submitExerciseAttempt(
          attemptId: ex2Attempt.attemptId,
          idempotencyKey: 'hist-ex2-submit',
        );

        final historyScroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(HistoryScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        historyScroll.position.jumpTo(0);
        await tester.pumpAndSettle();

        final testsBeforeRefresh = repo.getTestsCalls;
        final actsBeforeRefresh = repo.getActivitiesCalls;
        await tester.fling(
          find.descendant(
            of: find.byType(HistoryScreen),
            matching: find.byType(SingleChildScrollView),
          ),
          const Offset(0, 400),
          1000,
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(repo.getTestsCalls, greaterThan(testsBeforeRefresh));
        expect(repo.getActivitiesCalls, greaterThan(actsBeforeRefresh));

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('history_filter_in_progress')),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Tidak Ada Aktivitas pada Filter Ini'),
          findsOneWidget,
        );
        expect(find.text('Tampilkan Semua'), findsOneWidget);

        await _tapVisible(tester, find.text('Tampilkan Semua'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('history_activity_card_$ex1AttemptId')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('history_activity_card_${ex2Attempt.attemptId}')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'navigates IN_PROGRESS / eligible test cards to M10 and replays PlasOfflineSyncBanner',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(initialProfile: _defaultProfile());

        // Start Pre-Test as IN_PROGRESS and complete all 7 exercises so Post-Test is eligible.
        await repo.createTestAttempt(
          testId: MockSeedData.preTest.testId,
          creationRequestId: 'hist-pre-inprog',
        );
        for (var i = 1; i <= 6; i++) {
          await _completeExercise(
            repo,
            exerciseId: 'ex-0$i',
            keyPrefix: 'hist-elig-$i',
          );
        }

        // Create ex-07 attempt and queue final answers + submit offline.
        final ex7Attempt = await repo.createExerciseAttempt(
          exerciseId: 'ex-07',
          creationRequestId: 'hist-ex7-create',
        );

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        await _tapVisible(tester, find.text('Riwayat'));
        await tester.pumpAndSettle();

        expect(find.byType(HistoryScreen), findsOneWidget);
        expect(find.text('Lanjutkan Pre-Test ->'), findsOneWidget);
        expect(find.text('Terkunci'), findsOneWidget); // 6/7 completed

        final container = ProviderScope.containerOf(
          tester.element(find.byType(HistoryScreen)),
        );
        await container.read(pendingSyncProvider.notifier).enqueue(
              PendingSyncItem(
                idempotencyKey: 'hist-sync-q1',
                method: 'POST',
                path: '/exercise-attempts/${ex7Attempt.attemptId}/answers',
                body: const <String, dynamic>{
                  'question_id': 'ex-07-q1',
                  'answer': <String, dynamic>{'option_id': 'ex-07-q1-opt-1'},
                  'time_spent_seconds': 8,
                },
                createdAtIso: '2026-11-21T00:00:00Z',
                operationLabel: 'Soal 1',
              ),
            );
        await container.read(pendingSyncProvider.notifier).enqueue(
              PendingSyncItem(
                idempotencyKey: 'hist-sync-q2',
                method: 'POST',
                path: '/exercise-attempts/${ex7Attempt.attemptId}/answers',
                body: const <String, dynamic>{
                  'question_id': 'ex-07-q2',
                  'answer': <String, dynamic>{'option_id': 'ex-07-q2-opt-2'},
                  'time_spent_seconds': 8,
                },
                createdAtIso: '2026-11-21T00:00:05Z',
                operationLabel: 'Soal 2',
              ),
            );
        await container.read(pendingSyncProvider.notifier).enqueue(
              PendingSyncItem(
                idempotencyKey: 'hist-sync-sub',
                method: 'POST',
                path: '/exercise-attempts/${ex7Attempt.attemptId}/submit',
                body: const <String, dynamic>{},
                createdAtIso: '2026-11-21T00:00:10Z',
                operationLabel: 'Submit ex-07',
              ),
            );
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(HistoryScreen),
            matching: find.byType(PlasOfflineSyncBanner),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('3 data tersimpan sementara'), findsOneWidget);

        await _tapVisible(tester, find.text('Kirim Ulang Sekarang'));
        await tester.pumpAndSettle();

        expect(container.read(pendingSyncProvider), isEmpty);
        expect(repo.replayedItems, hasLength(3));
        expect(
          find.descendant(
            of: find.byType(HistoryScreen),
            matching: find.byType(PlasOfflineSyncBanner),
          ),
          findsNothing,
        );
        // Post-Test is now unlocked and eligible!
        expect(find.text('Mulai Post-Test ->'), findsOneWidget);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('history_pre_test_cta')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TestSessionScreen), findsOneWidget);
        expect(_currentUri(tester), '/tests/test-pre-01/session');

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('test_resume_back_button')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(HistoryScreen), findsOneWidget);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('history_post_test_cta')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TestSessionScreen), findsOneWidget);
        expect(_currentUri(tester), '/tests/test-post-01/session');
      },
    );

    testWidgets(
      'handles error/retry on activitiesProvider',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(initialProfile: _defaultProfile())
          ..nextActivitiesError = PlasApiException.offline();

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        await _tapVisible(tester, find.text('Riwayat'));
        await tester.pumpAndSettle();

        expect(find.byType(PlasErrorView), findsOneWidget);
        expect(find.text('Gagal Memuat Riwayat Latihan'), findsOneWidget);

        await _tapVisible(tester, find.text('Coba Lagi'));
        await tester.pumpAndSettle();

        expect(find.text('Belum Ada Riwayat Latihan'), findsOneWidget);
      },
    );
  });

  group('M15 ProfileScreen (Profil, Kuota AI WITA, DBR-14, & Logout)', () {
    testWidgets(
      'renders identity (Nama, NIM, Email), AI WITA quota, unlocked class update via PATCH /me/class, and 409 class_locked recovery',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'plas_class_onboarding_done_mhs-01': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(
          initialProfile: _defaultProfile(
            withClass: false,
            remainingAiQuota: 7,
          ),
        );

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        await _tapVisible(tester, find.text('Profil'));
        await tester.pumpAndSettle();

        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(_currentUri(tester), AppRoutes.profile);
        expect(find.text('CS LAB ENV // PROFIL'), findsOneWidget);
        expect(find.text('Profil & Kelas Mahasiswa'), findsOneWidget);

        // Identitas Mahasiswa
        expect(find.text('AF'), findsOneWidget);
        expect(find.text('Andi Fajar'), findsOneWidget);
        expect(find.text('NIM'), findsOneWidget);
        expect(find.text('2415091001'), findsOneWidget);
        expect(find.text('andi@plas.ac.id'), findsOneWidget);
        expect(find.byIcon(Symbols.mail), findsOneWidget);
        expect(find.text('Pengguna Umum (Tanpa Kelas)'), findsOneWidget);
        expect(
          find.text('Belum tergabung kelas (Pengguna Umum)'),
          findsOneWidget,
        );

        // Kuota AI Harian (WITA)
        expect(find.text('Kuota AI Harian (WITA)'), findsOneWidget);
        expect(find.text('7/10 WITA'), findsOneWidget);
        expect(
          find.text('Reset otomatis pukul 00:00 WITA'),
          findsOneWidget,
        );

        // Simpan Kelas starts disabled until class code matched.
        final saveButtonFinder = find.byKey(
          const ValueKey('profile_save_class_button'),
        );
        expect(
          tester.widget<ElevatedButton>(saveButtonFinder).onPressed,
          isNull,
        );

        // Match TI-2A-2026 via input and save via PATCH /me/class.
        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('profile_class_code_field')),
          'ti-2a-2026',
        );
        expect(
          find.byKey(const ValueKey('profile_class_preview_card')),
          findsOneWidget,
        );
        expect(find.text('Pemrograman TypeScript A'), findsOneWidget);
        expect(find.text('Dr. Rina Kusuma, M.Kom.'), findsOneWidget);

        final enabledBtn = tester.widget<ElevatedButton>(saveButtonFinder);
        expect(enabledBtn.onPressed, isNotNull);
        expect(
          enabledBtn.style?.backgroundColor?.resolve(<WidgetState>{}),
          PlasColors.brandPrimary,
        );

        await _tapVisible(tester, saveButtonFinder);
        await tester.pumpAndSettle();

        expect(repo.updatedClassIds, <String?>['kelas-ti2a-2026']);
        expect(
          find.byKey(const ValueKey('profile_class_success_banner')),
          findsOneWidget,
        );
        expect(find.text('Pemrograman TypeScript A'), findsOneWidget);
        expect(find.text('2026/2027 / Semester Ganjil'), findsOneWidget);

        // Quick-pick TI-2B-2026 chip (>= 48dp) and save.
        final chipFinder = find.byKey(
          const ValueKey('profile_class_quick_pick_kelas-ti2b-2026'),
        );
        final chipSize = tester.getSize(chipFinder);
        expect(chipSize.height, greaterThanOrEqualTo(48.0));
        expect(chipSize.width, greaterThanOrEqualTo(48.0));

        await _tapVisible(tester, chipFinder);
        await tester.pumpAndSettle();
        await _tapVisible(tester, saveButtonFinder);
        await tester.pumpAndSettle();

        expect(repo.updatedClassIds, <String?>[
          'kelas-ti2a-2026',
          'kelas-ti2b-2026',
        ]);
        expect(find.text('Pemrograman TypeScript B'), findsOneWidget);
        expect(find.text('Andi Pratama, M.T.'), findsOneWidget);

        // Simulate Pre-Test submitted remotely -> 409 class_locked recovery calls refreshProfile().
        await _completeTest(
          repo,
          testId: MockSeedData.preTest.testId,
          keyPrefix: 'prof-lock-race',
        );
        final getMeBeforeRace = repo.getMeCalls;

        await _tapVisible(
          tester,
          find.byKey(
            const ValueKey('profile_class_quick_pick_kelas-ti2a-2026'),
          ),
        );
        await tester.pumpAndSettle();
        await _tapVisible(tester, saveButtonFinder);
        await tester.pumpAndSettle();

        expect(repo.getMeCalls, greaterThan(getMeBeforeRace));
        expect(
          find.byKey(const ValueKey('profile_class_locked_banner')),
          findsOneWidget,
        );
        expect(
          find.text(plasErrorMessage(ApiErrorCodes.classLocked)),
          findsOneWidget,
        );
        expect(
          tester.widget<ElevatedButton>(saveButtonFinder).onPressed,
          isNull,
        );
      },
    );

    testWidgets(
      'DBR-14 locked state renders #FFFBEB banner, #E2E8F0/#475569 disabled styling, Symbols.lock, refresh, and Logout confirm dialog (Batal vs Keluar -> M02)',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(
          initialProfile: _defaultProfile(
            withClass: true,
            preTestSubmitted: true,
            remainingAiQuota: 0,
          ),
        );

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        await _tapVisible(tester, find.text('Profil'));
        await tester.pumpAndSettle();

        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(find.text('0/10 WITA'), findsOneWidget);

        // DBR-14 #FFFBEB warning banner
        final bannerFinder = find.byKey(
          const ValueKey('profile_class_locked_banner'),
        );
        expect(bannerFinder, findsOneWidget);
        final bannerContainer = tester.widget<Container>(bannerFinder);
        final bannerDeco = bannerContainer.decoration! as BoxDecoration;
        expect(bannerDeco.color, PlasColors.warningBg);
        expect(
          (bannerDeco.border! as Border).top.color,
          PlasColors.warningBorder,
        );
        expect(
          find.text(
            'Kelas tidak dapat diubah karena Pre-test Anda telah dikumpulkan (SUBMITTED).',
          ),
          findsOneWidget,
        );

        // Disabled input styled #E2E8F0 / #475569 + Symbols.lock
        final fieldFinder = find.byKey(
          const ValueKey('profile_class_code_field'),
        );
        final fieldWidget = tester.widget<TextField>(fieldFinder);
        expect(fieldWidget.enabled, isFalse);
        expect(fieldWidget.decoration?.fillColor, PlasColors.disabledBg);
        expect(fieldWidget.style?.color, PlasColors.disabledText);
        expect(
          find.descendant(
            of: fieldFinder,
            matching: find.byIcon(Symbols.lock),
          ),
          findsOneWidget,
        );

        // Disabled CTA styled #E2E8F0 / #475569 + Symbols.lock + onPressed == null
        final saveBtnFinder = find.byKey(
          const ValueKey('profile_save_class_button'),
        );
        final saveBtn = tester.widget<ElevatedButton>(saveBtnFinder);
        expect(saveBtn.onPressed, isNull);
        expect(
          saveBtn.style?.backgroundColor?.resolve(<WidgetState>{
            WidgetState.disabled,
          }),
          PlasColors.disabledBg,
        );
        expect(
          saveBtn.style?.foregroundColor?.resolve(<WidgetState>{
            WidgetState.disabled,
          }),
          PlasColors.disabledText,
        );
        expect(
          find.descendant(
            of: saveBtnFinder,
            matching: find.byIcon(Symbols.lock),
          ),
          findsOneWidget,
        );

        // Quick-pick chips hidden while locked.
        expect(
          find.byKey(
            const ValueKey('profile_class_quick_pick_kelas-ti2a-2026'),
          ),
          findsNothing,
        );

        // Pull-to-refresh calls getMe, getAiQuota, getClasses.
        final meBefore = repo.getMeCalls;
        final quotaBefore = repo.getAiQuotaCalls;
        final classesBefore = repo.getClassesCalls;
        await tester.fling(
          find.descendant(
            of: find.byType(ProfileScreen),
            matching: find.byType(SingleChildScrollView),
          ),
          const Offset(0, 400),
          1000,
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(repo.getMeCalls, greaterThan(meBefore));
        expect(repo.getAiQuotaCalls, greaterThan(quotaBefore));
        expect(repo.getClassesCalls, greaterThan(classesBefore));

        // Logout confirm dialog: Batal keeps user authenticated; Keluar signs out to M02.
        final logoutBtnFinder = find.byKey(
          const ValueKey('profile_logout_button'),
        );
        expect(
          tester.getSize(logoutBtnFinder).height,
          greaterThanOrEqualTo(48.0),
        );
        expect(
          find.descendant(
            of: logoutBtnFinder,
            matching: find.byIcon(Symbols.logout),
          ),
          findsOneWidget,
        );

        await _tapVisible(tester, logoutBtnFinder);
        await tester.pumpAndSettle();

        expect(find.byType(PlasConfirmDialog), findsOneWidget);
        expect(find.text('Keluar dari Akun?'), findsOneWidget);

        await _tapVisible(
          tester,
          find.descendant(
            of: find.byType(PlasConfirmDialog),
            matching: find.text('Batal'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PlasConfirmDialog), findsNothing);
        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(authService.signOutCallCount, 0);
        expect(authService.currentUser, isNotNull);

        await _tapVisible(tester, logoutBtnFinder);
        await tester.pumpAndSettle();
        await _tapVisible(
          tester,
          find.descendant(
            of: find.byType(PlasConfirmDialog),
            matching: find.text('Keluar'),
          ),
        );
        await tester.pumpAndSettle();

        expect(authService.signOutCallCount, 1);
        expect(authService.currentUser, isNull);
        expect(find.byType(AuthScreen), findsOneWidget);
      },
    );

    testWidgets(
      'DBR-14 relaxed when preTestSubmitted == true and kelas == null: keeps user authenticated, allows joining new class in ProfileScreen, refreshes providers, then re-locks without overflow @ 2.0x',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(
          initialProfile: _defaultProfile(
            withClass: false,
            preTestSubmitted: true,
          ),
        );

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingClassScreen), findsNothing);
        expect(find.byType(LearnHomeScreen), findsOneWidget);

        await _tapVisible(tester, find.text('Profil'));
        await tester.pumpAndSettle();

        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(
          find.byKey(const ValueKey('profile_rejoin_class_note')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('profile_class_locked_banner')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);

        final fieldWidget = tester.widget<TextField>(
          find.byKey(const ValueKey('profile_class_code_field')),
        );
        expect(fieldWidget.enabled, isTrue);
        expect(
          find.byKey(
            const ValueKey('profile_class_quick_pick_kelas-ti2a-2026'),
          ),
          findsOneWidget,
        );

        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('profile_class_code_field')),
          'TI-2A-2026',
        );
        final saveButtonFinder = find.byKey(
          const ValueKey('profile_save_class_button'),
        );
        expect(tester.widget<ElevatedButton>(saveButtonFinder).onPressed, isNotNull);

        final meBeforeSave = repo.getMeCalls;
        final classesBeforeSave = repo.getClassesCalls;

        await _tapVisible(tester, saveButtonFinder);
        await tester.pumpAndSettle();

        expect(repo.updatedClassIds, <String?>['kelas-ti2a-2026']);
        expect(repo.getMeCalls, greaterThan(meBeforeSave));
        expect(repo.getClassesCalls, greaterThan(classesBeforeSave));
        expect(
          find.byKey(const ValueKey('profile_class_success_banner')),
          findsOneWidget,
        );
        expect(find.text('Pemrograman TypeScript A'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('profile_class_locked_banner')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('profile_class_code_field')),
              )
              .enabled,
          isFalse,
        );
        expect(tester.widget<ElevatedButton>(saveButtonFinder).onPressed, isNull);
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);
      },
    );
  });

  group('M14 & M15 390x844 @ 2.0x text scale accessibility', () {
    testWidgets(
      'renders M14 and both M15 (unlocked & DBR-14 locked + logout dialog) at 390x844 @ 2.0x with zero overflow and zero em dashes',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final clock = _FakeClock(DateTime.utc(2026, 11, 20, 16, 15));
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(
          clock: clock.call,
          initialProfile: _defaultProfile(),
        );

        await _completeExercise(
          repo,
          exerciseId: 'ex-01',
          keyPrefix: 'a11y-ex1',
        );
        await repo.createExerciseAttempt(
          exerciseId: 'ex-02',
          creationRequestId: 'a11y-ex2',
        );

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        // 1. M14 HistoryScreen @ 2.0x with offline banner + cards + filters
        await _tapVisible(tester, find.text('Riwayat'));
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(HistoryScreen)),
        );
        await container.read(pendingSyncProvider.notifier).enqueue(
              const PendingSyncItem(
                idempotencyKey: 'a11y-sync-1',
                method: 'POST',
                path: '/exercise-attempts/ex-att-2/submit',
                body: <String, dynamic>{},
                createdAtIso: '2026-11-21T00:00:00Z',
                operationLabel: 'Submit',
              ),
            );
        await tester.pumpAndSettle();

        expect(find.byType(HistoryScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);

        await tester.ensureVisible(
          find.byKey(const ValueKey('history_filter_in_progress')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 2. M15 ProfileScreen (unlocked with matched class preview) @ 2.0x
        await _tapVisible(tester, find.text('Profil'));
        await tester.pumpAndSettle();

        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);

        await _tapVisible(
          tester,
          find.byKey(
            const ValueKey('profile_class_quick_pick_kelas-ti2b-2026'),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);

        // 3. M15 ProfileScreen (DBR-14 locked + logout dialog) @ 2.0x
        await _completeTest(
          repo,
          testId: MockSeedData.preTest.testId,
          keyPrefix: 'a11y-pre-lock',
        );
        await container.read(sessionControllerProvider.notifier).refreshProfile();
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('profile_class_locked_banner')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('profile_logout_button')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PlasConfirmDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);
      },
    );
  });
}
