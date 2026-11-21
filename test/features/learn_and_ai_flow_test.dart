import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/app.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/router/app_router.dart';
import 'package:plasmobile/core/sync/pending_sync_queue.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/data/dto/ai_dto.dart';
import 'package:plasmobile/data/dto/material_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/data/dto/student_profile_dto.dart';
import 'package:plasmobile/data/repositories/mock_plas_repository.dart';
import 'package:plasmobile/data/repositories/mock_seed_data.dart';
import 'package:plasmobile/data/repositories/plas_repository.dart';
import 'package:plasmobile/data/services/auth_service.dart';
import 'package:plasmobile/features/ai/presentation/ai_assistant_sheet.dart';
import 'package:plasmobile/features/learn/presentation/learn_home_screen.dart';
import 'package:plasmobile/features/learn/presentation/material_detail_screen.dart';
import 'package:plasmobile/features/learn/presentation/submaterial_read_screen.dart';
import 'package:plasmobile/shared/widgets/owl_bracket_mascot.dart';
import 'package:plasmobile/shared/widgets/plas_code_block.dart';
import 'package:plasmobile/shared/widgets/plas_markdown_view.dart';
import 'package:plasmobile/shared/widgets/plas_state_views.dart';
import 'package:plasmobile/shared/widgets/tanya_ai_fab.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _RecordedAiCall {
  const _RecordedAiCall({
    required this.requestId,
    required this.request,
  });

  final String requestId;
  final AiAskRequestDto request;
}

class _SpyPlasRepository extends MockPlasRepository {
  _SpyPlasRepository({super.initialProfile});

  final List<_RecordedAiCall> recordedAiCalls = <_RecordedAiCall>[];

  PlasApiException? nextMaterialsError;
  bool returnEmptyMaterials = false;
  PlasApiException? nextAskAiError;
  AiAskResponseDto? nextAskAiResponse;
  int? forcedRemainingQuota;

  @override
  Future<List<MaterialSummaryDto>> getMaterials() async {
    if (nextMaterialsError != null) {
      final error = nextMaterialsError!;
      nextMaterialsError = null;
      throw error;
    }
    if (returnEmptyMaterials) {
      return const <MaterialSummaryDto>[];
    }
    return super.getMaterials();
  }

  @override
  Future<AiQuotaDto> getAiQuota() async {
    final base = await super.getAiQuota();
    if (forcedRemainingQuota != null) {
      return AiQuotaDto(
        remainingQuota: forcedRemainingQuota!,
        dailyLimit: base.dailyLimit,
        usageDate: base.usageDate,
      );
    }
    return base;
  }

  @override
  Future<AiAskResponseDto> askAi({
    required AiAskRequestDto request,
    required String requestId,
  }) async {
    recordedAiCalls.add(
      _RecordedAiCall(requestId: requestId, request: request),
    );
    if (nextAskAiError != null) {
      final error = nextAskAiError!;
      nextAskAiError = null;
      if (error.code == ApiErrorCodes.quotaExceeded) {
        forcedRemainingQuota = 0;
      }
      throw error;
    }
    if (nextAskAiResponse != null) {
      final response = nextAskAiResponse!;
      nextAskAiResponse = null;
      forcedRemainingQuota = response.remainingQuota;
      return response;
    }
    return super.askAi(request: request, requestId: requestId);
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
  int remainingAiQuota = 10,
}) {
  return StudentProfileDto(
    mahasiswaId: 'mhs-01',
    nama: 'Andi Fajar',
    nim: '2415091001',
    kelas: withClass ? MockSeedData.classes.first : null,
    preTestSubmitted: false,
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
      timeSpentSeconds: 12,
      submissionRequestId: '$keyPrefix-ans-${q.sequence}',
    );
  }
  await repo.submitExerciseAttempt(
    attemptId: attempt.attemptId,
    idempotencyKey: '$keyPrefix-submit',
  );
  return attempt.attemptId;
}

Future<void> _completeTest(
  MockPlasRepository repo, {
  required String testId,
  required String keyPrefix,
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
    final StudentAnswer answer = switch (q.questionType) {
      QuestionType.mc => McAnswer(q.correctOptionId!),
      QuestionType.tf => TfAnswer(q.correctBoolean!),
      QuestionType.fib => FibAnswer(q.correctText!),
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

  group('M05 LearnHomeScreen', () {
    testWidgets(
      'renders greeting, AF avatar, class/general badge, Hero Progress (0/7), and 7 materials navigating to M06',
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
        expect(find.text('Halo, Andi Fajar'), findsOneWidget);
        expect(find.text('AF'), findsOneWidget);
        expect(find.text('TI-2A-2026'), findsOneWidget);

        expect(find.text('0/7 Materi Selesai'), findsOneWidget);
        expect(find.text('0%'), findsOneWidget);
        expect(find.text('Kuota AI: 10/10 WITA'), findsOneWidget);

        final progressBar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(progressBar.backgroundColor, PlasColors.borderSubtle);
        expect(
          progressBar.valueColor?.value,
          PlasColors.brandPrimary,
        );

        expect(find.text('Materi 01'), findsOneWidget);
        expect(find.text('Struktur Dasar Kode TypeScript'), findsOneWidget);
        expect(find.text('Materi 07'), findsOneWidget);
        expect(find.text('Function'), findsOneWidget);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('learn_material_card_mat-01')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MaterialDetailScreen), findsOneWidget);
        expect(_currentUri(tester), '/materials/mat-01');
      },
    );

    testWidgets(
      'shows Pengguna Umum badge when kelas is null and supports error/retry & empty states',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'plas_class_onboarding_done_mhs-01': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(
          initialProfile: _defaultProfile(withClass: false),
        )..nextMaterialsError = PlasApiException.offline();

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LearnHomeScreen), findsOneWidget);
        expect(find.text('Pengguna Umum'), findsOneWidget);
        expect(find.byType(PlasErrorView), findsOneWidget);

        repo.returnEmptyMaterials = true;
        await _tapVisible(tester, find.text('Coba Lagi'));
        await tester.pumpAndSettle();

        expect(find.byType(PlasEmptyView), findsOneWidget);
        expect(find.text('Belum Ada Materi TypeScript'), findsOneWidget);

        repo.returnEmptyMaterials = false;
        await _tapVisible(tester, find.text('Muat Ulang'));
        await tester.pumpAndSettle();

        expect(find.text('Materi 01'), findsOneWidget);
      },
    );

    testWidgets(
      'DBR-15 locked at 5/7, unlocks at 7/7 on refresh, and Pre-Test/Post-Test CTAs navigate properly',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(initialProfile: _defaultProfile());

        for (var i = 1; i <= 5; i++) {
          await _completeExercise(
            repo,
            exerciseId: 'ex-0$i',
            keyPrefix: 'm05-5of7-$i',
          );
        }

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        expect(find.text('5/7 Materi Selesai'), findsOneWidget);
        expect(find.text('71%'), findsOneWidget);
        expect(find.text('Terkunci'), findsOneWidget);
        expect(
          find.text(
            'Selesaikan seluruh latihan (5/7 selesai) untuk membuka Post-test.',
          ),
          findsOneWidget,
        );
        final lockBanner = tester.widget<Container>(
          find.byKey(const ValueKey('learn_post_test_lock_banner')),
        );
        expect(
          (lockBanner.decoration! as BoxDecoration).color,
          PlasColors.warningBg,
        );
        final lockedPostBtn = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('learn_post_test_cta')),
        );
        expect(lockedPostBtn.onPressed, isNull);
        expect(find.text('Mulai Post-test (Terkunci)'), findsOneWidget);
        expect(find.text('Mulai Pre-Test ->'), findsOneWidget);

        // Complete remaining 2 exercises and Pre-Test, then refresh M05.
        await _completeExercise(repo, exerciseId: 'ex-06', keyPrefix: 'm05-6');
        await _completeExercise(repo, exerciseId: 'ex-07', keyPrefix: 'm05-7');
        await _completeTest(
          repo,
          testId: MockSeedData.preTest.testId,
          keyPrefix: 'm05-pre-done',
        );

        await tester.fling(
          find.byType(SingleChildScrollView),
          const Offset(0, 400),
          1000,
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(find.text('7/7 Materi Selesai'), findsOneWidget);
        expect(find.text('100%'), findsOneWidget);
        expect(find.text('Lihat Hasil Pre-Test'), findsOneWidget);
        expect(find.text('Mulai Post-test (Terkunci)'), findsNothing);
        expect(find.text('Mulai Post-test ->'), findsOneWidget);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('learn_post_test_cta')),
        );
        await tester.pumpAndSettle();

        expect(_currentUri(tester), '/tests/test-post-01/session');
      },
    );

    testWidgets(
      'PlasOfflineSyncBanner replays pending queue items and refreshes Hero Progress',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(initialProfile: _defaultProfile());

        final attempt = await repo.createExerciseAttempt(
          exerciseId: 'ex-01',
          creationRequestId: 'sync-att-create',
        );
        await repo.submitExerciseAnswer(
          attemptId: attempt.attemptId,
          questionId: 'ex-01-q1',
          answer: const McAnswer('ex-01-q1-opt-1'),
          timeSpentSeconds: 10,
          submissionRequestId: 'sync-ans-1',
        );

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(LearnHomeScreen)),
        );
        await container.read(pendingSyncProvider.notifier).enqueue(
              PendingSyncItem(
                idempotencyKey: 'sync-ans-2',
                method: 'POST',
                path: '/exercise-attempts/${attempt.attemptId}/answers',
                body: const <String, dynamic>{
                  'question_id': 'ex-01-q2',
                  'answer': <String, dynamic>{'option_id': 'ex-01-q2-opt-2'},
                  'time_spent_seconds': 8,
                },
                createdAtIso: '2026-11-21T00:00:00Z',
                operationLabel: 'Kirim jawaban 2',
              ),
            );
        await container.read(pendingSyncProvider.notifier).enqueue(
              PendingSyncItem(
                idempotencyKey: 'sync-submit-1',
                method: 'POST',
                path: '/exercise-attempts/${attempt.attemptId}/submit',
                body: const <String, dynamic>{},
                createdAtIso: '2026-11-21T00:00:05Z',
                operationLabel: 'Kumpulkan latihan',
              ),
            );
        await tester.pumpAndSettle();

        expect(find.byType(PlasOfflineSyncBanner), findsOneWidget);
        expect(find.textContaining('2 data tersimpan sementara'), findsOneWidget);
        expect(find.text('0/7 Materi Selesai'), findsOneWidget);

        await _tapVisible(tester, find.text('Kirim Ulang Sekarang'));
        await tester.pumpAndSettle();

        expect(find.byType(PlasOfflineSyncBanner), findsNothing);
        expect(find.text('1/7 Materi Selesai'), findsOneWidget);
      },
    );
  });

  group('M06 MaterialDetailScreen', () {
    testWidgets(
      'displays SubMateri & Exercise card, Attempt 3/3 limit reached banner + disabled button, and Riwayat Attempt review navigation',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(initialProfile: _defaultProfile());

        final att1Id = await _completeExercise(
          repo,
          exerciseId: 'ex-01',
          keyPrefix: 'm06-att-1',
        );
        await _completeExercise(
          repo,
          exerciseId: 'ex-01',
          keyPrefix: 'm06-att-2',
        );
        await _completeExercise(
          repo,
          exerciseId: 'ex-01',
          keyPrefix: 'm06-att-3',
        );

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('learn_material_card_mat-01')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MaterialDetailScreen), findsOneWidget);
        expect(find.text('Materi 01'), findsOneWidget);
        expect(find.text('Berkas TypeScript dan Kompilasi tsc'), findsOneWidget);
        expect(find.text('MC'), findsOneWidget);
        expect(find.text('Skor Terbaik: 100'), findsOneWidget);

        expect(
          find.text(plasErrorMessage(ApiErrorCodes.attemptLimitReached)),
          findsOneWidget,
        );
        final limitBanner = tester.widget<Container>(
          find.byKey(const ValueKey('attempt_limit_banner_ex-01')),
        );
        expect((limitBanner.decoration! as BoxDecoration).color, PlasColors.errorBg);

        final openExerciseButton = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('open_exercise_ex-01')),
        );
        expect(openExerciseButton.onPressed, isNull);

        expect(find.text('Riwayat Attempt'), findsOneWidget);
        expect(find.text('Attempt 1/3'), findsOneWidget);
        expect(find.text('Attempt 2/3'), findsOneWidget);
        expect(find.text('Attempt 3/3'), findsNWidgets(2));
        expect(find.text('SUBMITTED'), findsNWidgets(3));

        await _tapVisible(
          tester,
          find.byKey(ValueKey('attempt_history_$att1Id')),
        );
        await tester.pumpAndSettle();

        expect(_currentUri(tester), '/exercise-attempts/$att1Id/review');
      },
    );

    testWidgets(
      'keeps Lanjutkan Latihan -> active when 3rd attempt is IN_PROGRESS',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(initialProfile: _defaultProfile());

        await _completeExercise(repo, exerciseId: 'ex-01', keyPrefix: 'inprog-1');
        await _completeExercise(repo, exerciseId: 'ex-01', keyPrefix: 'inprog-2');
        await repo.createExerciseAttempt(
          exerciseId: 'ex-01',
          creationRequestId: 'inprog-3',
        );

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('learn_material_card_mat-01')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Lanjutkan Latihan ->'), findsOneWidget);
        expect(
          find.text(plasErrorMessage(ApiErrorCodes.attemptLimitReached)),
          findsNothing,
        );
        final openExerciseButton = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('open_exercise_ex-01')),
        );
        expect(openExerciseButton.onPressed, isNotNull);
      },
    );
  });

  group('M07 SubMaterialReadScreen', () {
    testWidgets(
      'renders PlasMarkdownView + PlasCodeBlock, opens M09 via TanyaAiFab, and routes Mulai Latihan -> with submaterialId',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(initialProfile: _defaultProfile());

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

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

        expect(find.byType(SubMaterialReadScreen), findsOneWidget);
        expect(find.byType(PlasMarkdownView), findsOneWidget);
        expect(find.byType(PlasCodeBlock), findsOneWidget);
        expect(find.text('TS'), findsOneWidget);

        // TanyaAiFab opens M09 bottom sheet.
        expect(find.byType(TanyaAiFab), findsOneWidget);
        await _tapVisible(tester, find.byType(TanyaAiFab));
        await tester.pumpAndSettle();

        expect(find.byType(AiAssistantSheet), findsOneWidget);
        expect(find.text('AI Learning Assistant'), findsOneWidget);
        expect(find.text('Socratic Mode'), findsOneWidget);
        expect(find.byType(OwlBracketMascot), findsAtLeastNWidgets(1));

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('ai_footer_close_button')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AiAssistantSheet), findsNothing);

        // Mulai Latihan -> navigates with ?submaterialId=sub-01.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('submaterial_start_exercise_button')),
        );
        await tester.pumpAndSettle();

        expect(
          _currentUri(tester),
          '/exercises/ex-01/session?submaterialId=sub-01',
        );
      },
    );
  });

  group('M09 AiAssistantSheet', () {
    testWidgets(
      'renders 3 Socratic tabs, reuses exact requestId on 502/504/offline retry without losing quota, and mints new requestId on level/question change',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(initialProfile: _defaultProfile());

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

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
        await _tapVisible(tester, find.byType(TanyaAiFab));
        await tester.pumpAndSettle();

        expect(find.text('1. Konsep Dasar'), findsOneWidget);
        expect(find.text('2. Strategi'), findsOneWidget);
        expect(find.text('3. Penalaran'), findsOneWidget);
        expect(find.text('Sisa kuota hari ini: 10/10'), findsOneWidget);

        // 1. Trigger 502 via simulateAiFailure.
        repo.simulateAiFailure = true;
        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('ai_question_field')),
          'Apa fungsi ekstensi .ts?',
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('ai_send_button')),
        );
        await tester.pumpAndSettle();

        expect(repo.recordedAiCalls, hasLength(1));
        final firstId = repo.recordedAiCalls[0].requestId;
        expect(firstId, isNotEmpty);
        expect(find.text('Sisa kuota hari ini: 10/10'), findsOneWidget);
        expect(
          find.text(plasErrorMessage(ApiErrorCodes.aiServiceError)),
          findsOneWidget,
        );

        // 2. Also simulate 504 timeout and offline before succeeding -> MUST keep reusing firstId.
        repo.simulateAiFailure = false;
        repo.nextAskAiError = PlasApiException.fromApiCode(
          ApiErrorCodes.aiTimeout,
          statusCode: 504,
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('ai_send_button')),
        );
        await tester.pumpAndSettle();
        expect(repo.recordedAiCalls, hasLength(2));
        expect(repo.recordedAiCalls[1].requestId, firstId);
        expect(find.text('Sisa kuota hari ini: 10/10'), findsOneWidget);

        repo.nextAskAiError = PlasApiException.offline();
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('ai_send_button')),
        );
        await tester.pumpAndSettle();
        expect(repo.recordedAiCalls, hasLength(3));
        expect(repo.recordedAiCalls[2].requestId, firstId);
        expect(find.text('Sisa kuota hari ini: 10/10'), findsOneWidget);

        // 3. Retry after recovery -> reuses EXACT SAME firstId and consumes only 1 quota.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('ai_send_button')),
        );
        await tester.pumpAndSettle();

        expect(repo.recordedAiCalls, hasLength(4));
        expect(repo.recordedAiCalls[3].requestId, firstId);
        expect(find.text('Sisa kuota hari ini: 9/10'), findsOneWidget);
        expect(find.byKey(const ValueKey('ai_response_box')), findsOneWidget);

        final responseBox = tester.widget<Container>(
          find.byKey(const ValueKey('ai_response_box')),
        );
        final responseDecoration = responseBox.decoration! as BoxDecoration;
        expect(responseDecoration.color, PlasColors.brandTint);
        expect(
          (responseDecoration.border! as Border).top.color,
          PlasColors.brandPrimary,
        );
        expect(
          find.textContaining('[Level 1: Konsep Dasar]'),
          findsOneWidget,
        );

        // 4. Advance via 'Minta Petunjuk Level berikutnya ->' -> mints NEW requestId for Level 2.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('ai_next_level_button')),
        );
        await tester.pumpAndSettle();

        expect(repo.recordedAiCalls, hasLength(5));
        final secondId = repo.recordedAiCalls[4].requestId;
        expect(secondId, isNot(equals(firstId)));
        expect(repo.recordedAiCalls[4].request.hintLevel, AiHintLevel.strategi);
        expect(find.text('Sisa kuota hari ini: 8/10'), findsOneWidget);
        expect(find.textContaining('[Level 2: Strategi]'), findsOneWidget);

        // 5. Switch to Level 3 tab and send -> mints NEW requestId.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('ai_level_tab_3')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('ai_next_level_button')),
          findsNothing,
        );

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('ai_send_button')),
        );
        await tester.pumpAndSettle();

        expect(repo.recordedAiCalls, hasLength(6));
        final thirdId = repo.recordedAiCalls[5].requestId;
        expect(thirdId, isNot(equals(secondId)));
        expect(repo.recordedAiCalls[5].request.hintLevel, AiHintLevel.penalaran);
        expect(find.text('Sisa kuota hari ini: 7/10'), findsOneWidget);
        expect(find.textContaining('[Level 3: Penalaran]'), findsOneWidget);
      },
    );

    testWidgets(
      'handles already_processed preserving prior reply and syncing remainingQuota',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(initialProfile: _defaultProfile());

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

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
        await _tapVisible(tester, find.byType(TanyaAiFab));
        await tester.pumpAndSettle();

        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('ai_question_field')),
          'Jelaskan tsc',
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('ai_send_button')),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('[Level 1: Konsep Dasar]'), findsOneWidget);
        expect(find.text('Sisa kuota hari ini: 9/10'), findsOneWidget);

        repo.nextAskAiResponse = const AiAskResponseDto(
          status: AiAskStatus.alreadyProcessed,
          answer: null,
          hintLevel: null,
          remainingQuota: 8,
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('ai_send_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Permintaan ini telah diproses sebelumnya.'),
          findsOneWidget,
        );
        expect(find.textContaining('[Level 1: Konsep Dasar]'), findsOneWidget);
        expect(find.text('Sisa kuota hari ini: 8/10'), findsOneWidget);
      },
    );

    testWidgets(
      '0/10 quota shows #FEF2F2/#DC2626 banner mentioning 00:00 WITA and disables input & send buttons',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(
          initialProfile: _defaultProfile(remainingAiQuota: 0),
        );

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

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
        await _tapVisible(tester, find.byType(TanyaAiFab));
        await tester.pumpAndSettle();

        expect(find.text('Sisa kuota hari ini: 0/10'), findsOneWidget);
        expect(find.textContaining('00:00 WITA'), findsOneWidget);

        final banner = tester.widget<Container>(
          find.byKey(const ValueKey('ai_quota_exhausted_banner')),
        );
        final bannerDecoration = banner.decoration! as BoxDecoration;
        expect(bannerDecoration.color, PlasColors.errorBg);
        expect(
          (bannerDecoration.border! as Border).top.color,
          PlasColors.errorBorder,
        );

        final field = tester.widget<TextField>(
          find.byKey(const ValueKey('ai_question_field')),
        );
        expect(field.enabled, isFalse);

        final sendButton = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('ai_send_button')),
        );
        expect(sendButton.onPressed, isNull);
        final sendContext = tester.element(
          find.byKey(const ValueKey('ai_send_button')),
        );
        final disabledStyle = Theme.of(sendContext).elevatedButtonTheme.style!;
        expect(
          disabledStyle.backgroundColor?.resolve(<WidgetState>{
            WidgetState.disabled,
          }),
          PlasColors.disabledBg,
        );
        expect(
          disabledStyle.foregroundColor?.resolve(<WidgetState>{
            WidgetState.disabled,
          }),
          PlasColors.disabledText,
        );
        expect(
          find.byKey(const ValueKey('ai_next_level_button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'transitions to 0/10 disabled UI on 403 quota_exceeded error',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(initialProfile: _defaultProfile())
          ..nextAskAiError = PlasApiException.fromApiCode(
            ApiErrorCodes.quotaExceeded,
            statusCode: 403,
          );

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

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
        await _tapVisible(tester, find.byType(TanyaAiFab));
        await tester.pumpAndSettle();

        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('ai_question_field')),
          'Apa itu static typing?',
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('ai_send_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sisa kuota hari ini: 0/10'), findsOneWidget);
        expect(find.textContaining('00:00 WITA'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('ai_question_field')))
              .enabled,
          isFalse,
        );
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

  group('M05, M06, M07, M09 390x844 @ 2.0x text scale layout & zero em dash', () {
    testWidgets(
      'renders M05, M06, M07, and M09 with zero overflow and zero em dashes at 390px and 2.0x scale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(initialProfile: _defaultProfile());

        await _completeExercise(repo, exerciseId: 'ex-01', keyPrefix: 'a11y-1');

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(LearnHomeScreen), findsOneWidget);
        _assertNoEmDashInTexts(tester);

        // Navigate to M06.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('learn_material_card_mat-01')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(MaterialDetailScreen), findsOneWidget);
        _assertNoEmDashInTexts(tester);

        // Navigate to M07.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('read_submaterial_sub-01')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(SubMaterialReadScreen), findsOneWidget);
        _assertNoEmDashInTexts(tester);

        // Open M09.
        await _tapVisible(tester, find.byType(TanyaAiFab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(AiAssistantSheet), findsOneWidget);
        _assertNoEmDashInTexts(tester);

        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('ai_question_field')),
          'Apa itu tsc?',
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('ai_send_button')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);
      },
    );
  });
}
