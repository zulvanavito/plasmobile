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
import 'package:plasmobile/core/theme/plas_theme.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/data/dto/ai_dto.dart';
import 'package:plasmobile/data/dto/exercise_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/data/dto/student_profile_dto.dart';
import 'package:plasmobile/data/repositories/mock_plas_repository.dart';
import 'package:plasmobile/data/repositories/mock_seed_data.dart';
import 'package:plasmobile/data/repositories/plas_repository.dart';
import 'package:plasmobile/data/services/auth_service.dart';
import 'package:plasmobile/features/ai/presentation/ai_assistant_sheet.dart';
import 'package:plasmobile/features/exercise/presentation/exercise_review_screen.dart';
import 'package:plasmobile/features/exercise/presentation/exercise_session_screen.dart';
import 'package:plasmobile/features/shared/widgets/question_answer_input.dart';
import 'package:plasmobile/shared/widgets/confirm_dialog.dart';
import 'package:plasmobile/shared/widgets/plas_accuracy_ring.dart';
import 'package:plasmobile/shared/widgets/plas_bottom_nav.dart';
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

class _FakeClock {
  _FakeClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration delta) {
    now = now.add(delta);
  }
}

class _RecordedAnswerSubmission {
  const _RecordedAnswerSubmission({
    required this.attemptId,
    required this.questionId,
    required this.answer,
    required this.timeSpentSeconds,
    required this.submissionRequestId,
  });

  final String attemptId;
  final String questionId;
  final StudentAnswer answer;
  final int timeSpentSeconds;
  final String submissionRequestId;
}

class _RecordedAttemptSubmission {
  const _RecordedAttemptSubmission({
    required this.attemptId,
    required this.idempotencyKey,
  });

  final String attemptId;
  final String idempotencyKey;
}

class _RecordedAiAsk {
  const _RecordedAiAsk({
    required this.request,
    required this.requestId,
  });

  final AiAskRequestDto request;
  final String requestId;
}

class _SpyPlasRepository extends MockPlasRepository {
  _SpyPlasRepository({super.initialProfile});

  final List<String> recordedCreationKeys = <String>[];
  final List<_RecordedAnswerSubmission> recordedAnswerCalls =
      <_RecordedAnswerSubmission>[];
  final List<_RecordedAttemptSubmission> recordedSubmitCalls =
      <_RecordedAttemptSubmission>[];
  final List<PendingSyncItem> recordedReplayItems = <PendingSyncItem>[];
  final List<_RecordedAiAsk> recordedAiCalls = <_RecordedAiAsk>[];
  bool commitBeforeThrowingNextAnswerError = false;
  PlasApiException? nextSubmitAnswerError;

  @override
  Future<ExerciseAttemptDto> createExerciseAttempt({
    required String exerciseId,
    required String creationRequestId,
  }) async {
    recordedCreationKeys.add(creationRequestId);
    return super.createExerciseAttempt(
      exerciseId: exerciseId,
      creationRequestId: creationRequestId,
    );
  }

  @override
  Future<ExerciseAnswerResponseDto> submitExerciseAnswer({
    required String attemptId,
    required String questionId,
    required StudentAnswer answer,
    required int timeSpentSeconds,
    required String submissionRequestId,
  }) async {
    recordedAnswerCalls.add(
      _RecordedAnswerSubmission(
        attemptId: attemptId,
        questionId: questionId,
        answer: answer,
        timeSpentSeconds: timeSpentSeconds,
        submissionRequestId: submissionRequestId,
      ),
    );
    if (nextSubmitAnswerError != null) {
      final err = nextSubmitAnswerError!;
      final shouldCommitFirst = commitBeforeThrowingNextAnswerError;
      nextSubmitAnswerError = null;
      commitBeforeThrowingNextAnswerError = false;
      if (shouldCommitFirst) {
        await super.submitExerciseAnswer(
          attemptId: attemptId,
          questionId: questionId,
          answer: answer,
          timeSpentSeconds: timeSpentSeconds,
          submissionRequestId: submissionRequestId,
        );
      }
      throw err;
    }
    return super.submitExerciseAnswer(
      attemptId: attemptId,
      questionId: questionId,
      answer: answer,
      timeSpentSeconds: timeSpentSeconds,
      submissionRequestId: submissionRequestId,
    );
  }

  @override
  Future<ExerciseAttemptDto> submitExerciseAttempt({
    required String attemptId,
    required String idempotencyKey,
  }) async {
    recordedSubmitCalls.add(
      _RecordedAttemptSubmission(
        attemptId: attemptId,
        idempotencyKey: idempotencyKey,
      ),
    );
    return super.submitExerciseAttempt(
      attemptId: attemptId,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<void> replayPendingSyncItem(PendingSyncItem item) async {
    recordedReplayItems.add(item);
    return super.replayPendingSyncItem(item);
  }

  @override
  Future<AiAskResponseDto> askAi({
    required AiAskRequestDto request,
    required String requestId,
  }) async {
    recordedAiCalls.add(_RecordedAiAsk(request: request, requestId: requestId));
    return super.askAi(request: request, requestId: requestId);
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

Widget _wrapStandalone(
  Widget child, {
  double width = 390,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    theme: buildPlasTheme(),
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 844),
        textScaler: textScaler,
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(PlasSpacing.space4),
          child: child,
        ),
      ),
    ),
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

void _assertNoEmDashInTexts(WidgetTester tester) {
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    final text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
    expect(text, isNot(contains('\u2014')));
  }
}

void _assertNoAnswerKeysInTree(WidgetTester tester) {
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    final text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
    expect(text.toLowerCase(), isNot(contains('kunci jawaban')));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('PlasAccuracyRing', () {
    testWidgets(
      'renders CustomPaint with #15803D / #1D4ED8 over #E2E8F0, clamps percentage, and exposes Semantics',
      (tester) async {
        await tester.pumpWidget(
          _wrapStandalone(
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PlasAccuracyRing(
                  percentage: 85.6,
                  label: 'Akurasi',
                ),
                SizedBox(height: PlasSpacing.space4),
                PlasAccuracyRing(
                  percentage: 140,
                  arcColor: PlasColors.brandPrimary,
                  label: 'Progres',
                ),
                SizedBox(height: PlasSpacing.space4),
                PlasAccuracyRing(percentage: -15),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('86%'), findsOneWidget);
        expect(find.text('Akurasi'), findsOneWidget);
        expect(find.bySemanticsLabel('Akurasi 86%'), findsOneWidget);

        expect(find.text('100%'), findsOneWidget);
        expect(find.text('Progres'), findsOneWidget);
        expect(find.bySemanticsLabel('Progres 100%'), findsOneWidget);

        expect(find.text('0%'), findsOneWidget);
        expect(find.bySemanticsLabel('Akurasi 0%'), findsOneWidget);

        final customPaints = tester.widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(PlasAccuracyRing),
            matching: find.byType(CustomPaint),
          ),
        ).toList();
        expect(customPaints, hasLength(3));

        final firstPainter =
            customPaints[0].painter! as PlasAccuracyRingPainter;
        expect(firstPainter.arcColor, PlasColors.successBorder);
        expect(firstPainter.trackColor, PlasColors.borderSubtle);
        expect(firstPainter.percentage, 85.6);

        final secondPainter =
            customPaints[1].painter! as PlasAccuracyRingPainter;
        expect(secondPainter.arcColor, PlasColors.brandPrimary);
        expect(secondPainter.trackColor, PlasColors.borderSubtle);
        expect(secondPainter.percentage, 100.0);

        final thirdPainter =
            customPaints[2].painter! as PlasAccuracyRingPainter;
        expect(thirdPainter.percentage, 0.0);
        expect(firstPainter.shouldRepaint(secondPainter), isTrue);
        expect(firstPainter.shouldRepaint(firstPainter), isFalse);
      },
    );
  });

  group('QuestionAnswerInput', () {
    testWidgets(
      'MC renders 4 cards with >= 48dp height, #64748B rest border, and #1D4ED8/#EFF6FF selected styling',
      (tester) async {
        StudentAnswer? currentValue;
        final options = MockSeedData.materials.first.questions.first.options;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) => _wrapStandalone(
              QuestionAnswerInput(
                questionType: QuestionType.mc,
                options: options,
                value: currentValue,
                onChanged: (next) {
                  setState(() {
                    currentValue = next;
                  });
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        for (final opt in options) {
          final cardFinder = find.byKey(
            ValueKey('question_mc_option_${opt.optionId}'),
          );
          expect(cardFinder, findsOneWidget);
          expect(tester.getSize(cardFinder).height, greaterThanOrEqualTo(48.0));

          final container = tester.widget<Container>(cardFinder);
          final deco = container.decoration! as BoxDecoration;
          expect(deco.color, PlasColors.bgSurface);
          final border = deco.border! as Border;
          expect(border.top.color, PlasColors.borderInteractive);
          expect(border.top.width, 1.0);
        }

        await tester.tap(
          find.byKey(ValueKey('question_mc_option_${options[1].optionId}')),
        );
        await tester.pumpAndSettle();

        expect(currentValue, McAnswer(options[1].optionId));
        final selectedContainer = tester.widget<Container>(
          find.byKey(ValueKey('question_mc_option_${options[1].optionId}')),
        );
        final selectedDeco = selectedContainer.decoration! as BoxDecoration;
        expect(selectedDeco.color, PlasColors.brandTint);
        final selectedBorder = selectedDeco.border! as Border;
        expect(selectedBorder.top.color, PlasColors.brandPrimary);
        expect(selectedBorder.top.width, 2.0);
      },
    );

    testWidgets(
      'TF renders equal-width Row at 1.0x and stacks vertically at 2.0x scale on 390px',
      (tester) async {
        StudentAnswer? currentValue;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) => _wrapStandalone(
              QuestionAnswerInput(
                questionType: QuestionType.tf,
                value: currentValue,
                onChanged: (next) {
                  setState(() {
                    currentValue = next;
                  });
                },
              ),
              width: 390,
              textScaler: TextScaler.noScaling,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final trueFinder = find.byKey(const ValueKey('question_tf_true'));
        final falseFinder = find.byKey(const ValueKey('question_tf_false'));
        expect(trueFinder, findsOneWidget);
        expect(falseFinder, findsOneWidget);

        expect(
          tester.getTopLeft(trueFinder).dy,
          tester.getTopLeft(falseFinder).dy,
        );
        expect(
          tester.getTopLeft(trueFinder).dx,
          lessThan(tester.getTopLeft(falseFinder).dx),
        );
        expect(
          tester.getSize(trueFinder).width,
          closeTo(tester.getSize(falseFinder).width, 0.5),
        );

        await tester.tap(falseFinder);
        await tester.pumpAndSettle();
        expect(currentValue, const TfAnswer(false));

        final selectedFalse = tester.widget<Container>(falseFinder);
        final selectedDeco = selectedFalse.decoration! as BoxDecoration;
        expect(selectedDeco.color, PlasColors.brandTint);
        expect((selectedDeco.border! as Border).top.color, PlasColors.brandPrimary);

        await tester.pumpWidget(
          _wrapStandalone(
            QuestionAnswerInput(
              questionType: QuestionType.tf,
              value: const TfAnswer(true),
              onChanged: (_) {},
            ),
            width: 390,
            textScaler: const TextScaler.linear(2.0),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          tester.getTopLeft(trueFinder).dx,
          tester.getTopLeft(falseFinder).dx,
        );
        expect(
          tester.getTopLeft(trueFinder).dy,
          lessThan(tester.getTopLeft(falseFinder).dy),
        );
      },
    );

    testWidgets(
      'FIB uses JetBrains Mono, suppresses default counter, shows custom X / 255 counter, emits null for whitespace, and resets on question change',
      (tester) async {
        StudentAnswer? emitted;
        var hasEmitted = false;
        var questionKey = 'q1';

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) => _wrapStandalone(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  QuestionAnswerInput(
                    key: ValueKey(questionKey),
                    questionType: QuestionType.fib,
                    value: emitted,
                    onChanged: (next) {
                      hasEmitted = true;
                      setState(() {
                        emitted = next;
                      });
                    },
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        questionKey = 'q2';
                        emitted = null;
                      });
                    },
                    child: const Text('Next'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        emitted = null;
                      });
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fieldFinder = find.byKey(const ValueKey('question_fib_field'));
        final field = tester.widget<TextField>(fieldFinder);
        expect(field.style?.fontFamily, PlasTypography.fontMono);
        expect(field.maxLength, 255);
        expect(
          (field.decoration!.enabledBorder! as OutlineInputBorder)
              .borderSide
              .color,
          PlasColors.borderInteractive,
        );
        expect(
          (field.decoration!.focusedBorder! as OutlineInputBorder).borderSide,
          const BorderSide(color: PlasColors.brandPrimary, width: 2),
        );
        expect(
          find.text('Ketik jawaban singkat Anda (maksimal 255 karakter).'),
          findsOneWidget,
        );
        expect(find.text('0 / 255'), findsOneWidget);
        expect(find.text('0/255'), findsNothing);

        await tester.enterText(fieldFinder, '   ');
        await tester.pumpAndSettle();
        expect(hasEmitted, isTrue);
        expect(emitted, isNull);
        expect(find.text('3 / 255'), findsOneWidget);

        await tester.enterText(fieldFinder, 'const');
        await tester.pumpAndSettle();
        expect(emitted, const FibAnswer('const'));
        expect(find.text('5 / 255'), findsOneWidget);

        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('0 / 255'), findsOneWidget);

        // Also verify didUpdateWidget resets controller when value transitions back to null on the same Key.
        await tester.enterText(fieldFinder, 'boolean');
        await tester.pumpAndSettle();
        expect(find.text('7 / 255'), findsOneWidget);

        await tester.tap(find.text('Clear'));
        await tester.pumpAndSettle();
        expect(find.text('0 / 255'), findsOneWidget);
      },
    );
  });

  group('M08 ExerciseSessionScreen & M13 ExerciseReviewScreen', () {
    testWidgets(
      'M08 MC flow hides bottom nav/timer/instant feedback, toggles Petunjuk Awal without quota loss, opens M09 via TanyaAiFab, confirms submit, and routes to M13',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(initialProfile: _defaultProfile());

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        await _pushRoute(
          tester,
          AppRoutes.exerciseSession('ex-01', submaterialId: 'sub-01'),
        );

        expect(find.byType(ExerciseSessionScreen), findsOneWidget);
        expect(find.byType(PlasBottomNav), findsNothing);
        expect(find.text('Soal 1 dari 2'), findsOneWidget);
        expect(find.text('MC'), findsOneWidget);
        expect(find.text('Attempt 1/3'), findsOneWidget);
        expect(find.text('Pembahasan Konsep'), findsNothing);
        expect(find.text('Benar'), findsNothing);
        expect(find.text('Salah'), findsNothing);
        _assertNoAnswerKeysInTree(tester);

        // Toggle Petunjuk Awal free hint.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_hint_toggle')),
        );
        await tester.pumpAndSettle();
        final hintCard = tester.widget<Container>(
          find.byKey(const ValueKey('exercise_hint_card')),
        );
        final hintDeco = hintCard.decoration! as BoxDecoration;
        expect(hintDeco.color, PlasColors.warningBg);
        expect((hintDeco.border! as Border).top.color, PlasColors.warningBorder);
        expect(find.textContaining('halo.ts'), findsOneWidget);
        expect((await repo.getAiQuota()).remainingQuota, 10);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_hint_toggle')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('exercise_hint_card')), findsNothing);

        // TanyaAiFab opens M09 with submaterialId + exerciseQuestionId context.
        await _tapVisible(tester, find.byType(TanyaAiFab));
        await tester.pumpAndSettle();
        expect(find.byType(AiAssistantSheet), findsOneWidget);
        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('ai_question_field')),
          'Apa perbedaan .ts dan .js?',
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('ai_send_button')),
        );
        await tester.pumpAndSettle();
        expect(repo.recordedAiCalls, hasLength(1));
        expect(repo.recordedAiCalls.first.request.submaterialId, 'sub-01');
        expect(
          repo.recordedAiCalls.first.request.exerciseQuestionId,
          'ex-01-q1',
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('ai_footer_close_button')),
        );
        await tester.pumpAndSettle();

        // CTA disabled until option selected.
        expect(
          tester
              .widget<ElevatedButton>(
                find.byKey(const ValueKey('exercise_submit_cta')),
              )
              .onPressed,
          isNull,
        );

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_ex-01-q1-opt-1')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Kirim & Lanjut ->'), findsOneWidget);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_submit_cta')),
        );
        await tester.pumpAndSettle();

        // Advances to Question 2 with zero instant Benar/Salah feedback.
        expect(find.text('Soal 2 dari 2'), findsOneWidget);
        expect(find.text('Kirim & Selesai ->'), findsOneWidget);
        expect(find.text('Benar'), findsNothing);
        expect(find.text('Salah'), findsNothing);
        expect(find.text('Pembahasan Konsep'), findsNothing);

        // Answer Question 2 wrong intentionally to verify 50% review stats in M13.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_ex-01-q2-opt-1')),
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_submit_cta')),
        );
        await tester.pumpAndSettle();

        // ConfirmDialog must appear before submitting attempt.
        expect(find.byType(PlasConfirmDialog), findsOneWidget);
        expect(find.text('Kumpulkan Latihan?'), findsOneWidget);
        expect(find.textContaining('2 dari 2 soal'), findsOneWidget);

        // Canceling keeps session on M08 without submitting attempt.
        await _tapVisible(tester, find.text('Batal'));
        await tester.pumpAndSettle();
        expect(find.byType(ExerciseSessionScreen), findsOneWidget);
        expect(repo.recordedSubmitCalls, isEmpty);

        // Re-tap submit CTA and confirm.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_submit_cta')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PlasConfirmDialog), findsOneWidget);
        await _tapVisible(tester, find.text('Kumpulkan'));
        await tester.pumpAndSettle();

        // Redirected via pushReplacement to M13.
        expect(find.byType(ExerciseReviewScreen), findsOneWidget);
        expect(
          _currentUri(tester),
          '/exercise-attempts/ex-att-1/review',
        );

        expect(find.byType(PlasAccuracyRing), findsOneWidget);
        expect(find.text('50%'), findsOneWidget);
        final ringPainter = tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(PlasAccuracyRing),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter! as PlasAccuracyRingPainter;
        expect(ringPainter.arcColor, PlasColors.successBorder);

        expect(find.text('Attempt 1/3'), findsOneWidget);
        expect(find.text('SUBMITTED'), findsOneWidget);
        expect(find.text('Jawaban Anda'), findsNWidgets(2));
        expect(find.text('.ts'), findsOneWidget);
        expect(find.text('node'), findsOneWidget);
        expect(find.text('Pembahasan Konsep'), findsNWidgets(2));

        final expCard = tester.widget<Container>(
          find.byKey(const ValueKey('review_explanation_ex-01-q1')),
        );
        final expDeco = expCard.decoration! as BoxDecoration;
        expect(expDeco.color, PlasColors.brandTint);
        expect(find.byIcon(Symbols.menu_book), findsNWidgets(2));

        // P13 strict check: ZERO Kunci Jawaban text anywhere.
        _assertNoAnswerKeysInTree(tester);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('review_back_to_material_button')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ExerciseReviewScreen), findsNothing);
      },
    );

    testWidgets(
      'M08 supports full TF and FIB sessions and renders typed Jawaban Anda in M13',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(initialProfile: _defaultProfile());

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        // 1. TF Exercise (ex-03)
        await _pushRoute(
          tester,
          AppRoutes.exerciseSession('ex-03', submaterialId: 'sub-03'),
        );
        expect(find.text('TF'), findsOneWidget);
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_tf_true')),
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_submit_cta')),
        );
        await tester.pumpAndSettle();

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_tf_false')),
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_submit_cta')),
        );
        await tester.pumpAndSettle();
        await _tapVisible(tester, find.text('Kumpulkan'));
        await tester.pumpAndSettle();

        expect(find.byType(ExerciseReviewScreen), findsOneWidget);
        expect(find.text('100%'), findsOneWidget);
        expect(find.text('Jawaban Anda'), findsNWidgets(2));
        expect(find.text('Pembahasan Konsep'), findsNWidgets(2));
        _assertNoAnswerKeysInTree(tester);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('review_back_to_material_button')),
        );
        await tester.pumpAndSettle();

        // 2. FIB Exercise (ex-02)
        await _pushRoute(
          tester,
          AppRoutes.exerciseSession('ex-02', submaterialId: 'sub-02'),
        );
        expect(find.text('FIB'), findsOneWidget);
        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('question_fib_field')),
          'const',
        );
        expect(find.text('5 / 255'), findsOneWidget);
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_submit_cta')),
        );
        await tester.pumpAndSettle();

        expect(find.text('0 / 255'), findsOneWidget);
        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('question_fib_field')),
          'boolean',
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_submit_cta')),
        );
        await tester.pumpAndSettle();
        await _tapVisible(tester, find.text('Kumpulkan'));
        await tester.pumpAndSettle();

        expect(find.byType(ExerciseReviewScreen), findsOneWidget);
        expect(find.text('100%'), findsOneWidget);
        final fibText = tester.widget<Text>(find.text('const'));
        expect(fibText.style?.fontFamily, PlasTypography.fontMono);
        expect(find.text('boolean'), findsOneWidget);
        expect(find.text('Pembahasan Konsep'), findsNWidgets(2));
        _assertNoAnswerKeysInTree(tester);
      },
    );

    testWidgets(
      'M08 offline fallback queues answers + submit with preserved UUID idempotency keys, replays via PlasOfflineSyncBanner, and transitions to M13 without duplicate attempts',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(initialProfile: _defaultProfile());

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        await _pushRoute(
          tester,
          AppRoutes.exerciseSession('ex-01', submaterialId: 'sub-01'),
        );
        expect(repo.recordedCreationKeys, hasLength(1));

        // Go offline mid-session.
        repo.simulateOffline = true;

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_ex-01-q1-opt-1')),
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_submit_cta')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PlasOfflineSyncBanner), findsOneWidget);
        expect(find.text('Soal 2 dari 2'), findsOneWidget);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_ex-01-q2-opt-2')),
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_submit_cta')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PlasConfirmDialog), findsOneWidget);
        await _tapVisible(tester, find.text('Kumpulkan'));
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(ExerciseSessionScreen)),
        );
        final queued = container.read(pendingSyncProvider);
        expect(queued, hasLength(3));
        expect(queued[0].path, '/exercise-attempts/ex-att-1/answers');
        expect(queued[1].path, '/exercise-attempts/ex-att-1/answers');
        expect(queued[2].path, '/exercise-attempts/ex-att-1/submit');

        final key1 = queued[0].idempotencyKey;
        final key2 = queued[1].idempotencyKey;
        final submitKey = queued[2].idempotencyKey;
        expect(key1, repo.recordedAnswerCalls[0].submissionRequestId);
        expect(key2, repo.recordedAnswerCalls[1].submissionRequestId);
        expect(submitKey, isNotEmpty);

        // Retrying while still offline keeps all 3 queued items intact.
        await _tapVisible(tester, find.text('Kirim Ulang Sekarang'));
        await tester.pumpAndSettle();
        expect(container.read(pendingSyncProvider), hasLength(3));
        expect(find.byType(ExerciseSessionScreen), findsOneWidget);

        // Reconnect and replay via PlasOfflineSyncBanner.
        repo.recordedReplayItems.clear();
        repo.simulateOffline = false;
        await _tapVisible(tester, find.text('Kirim Ulang Sekarang'));
        await tester.pumpAndSettle();

        expect(container.read(pendingSyncProvider), isEmpty);
        expect(repo.recordedReplayItems.map((e) => e.idempotencyKey), [
          key1,
          key2,
          submitKey,
        ]);
        expect(repo.recordedAnswerCalls.last.submissionRequestId, key2);
        expect(repo.recordedSubmitCalls.last.idempotencyKey, submitKey);

        expect(find.byType(ExerciseReviewScreen), findsOneWidget);
        expect(_currentUri(tester), '/exercise-attempts/ex-att-1/review');
        expect(find.text('100%'), findsOneWidget);
        expect(await repo.getExerciseAttempts('ex-01'), hasLength(1));
      },
    );

    testWidgets(
      'M08 resumes IN_PROGRESS attempt at first unanswered question and handles 409 attempt_limit_reached cleanly',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(initialProfile: _defaultProfile());

        final attempt = await repo.createExerciseAttempt(
          exerciseId: 'ex-01',
          creationRequestId: 'pre-create',
        );
        await repo.submitExerciseAnswer(
          attemptId: attempt.attemptId,
          questionId: 'ex-01-q1',
          answer: const McAnswer('ex-01-q1-opt-1'),
          timeSpentSeconds: 9,
          submissionRequestId: 'pre-ans-1',
        );

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        // Visiting M13 while IN_PROGRESS must NOT show Pembahasan Konsep or AccuracyRing.
        await _pushRoute(tester, AppRoutes.exerciseReview(attempt.attemptId));
        expect(find.byKey(const ValueKey('review_in_progress_guard')), findsOneWidget);
        expect(find.text('Pembahasan Konsep'), findsNothing);
        expect(find.byType(PlasAccuracyRing), findsNothing);

        // Resuming M08 lands directly on Soal 2 dari 2 without creating a new attempt.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('review_resume_session_button')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ExerciseSessionScreen), findsOneWidget);
        expect(find.text('Soal 2 dari 2'), findsOneWidget);
        expect(repo.recordedCreationKeys, hasLength(1));

        // Exhaust all 3 attempts on ex-04 and verify 409 attempt_limit_reached UI.
        for (var i = 1; i <= 3; i++) {
          final att = await repo.createExerciseAttempt(
            exerciseId: 'ex-04',
            creationRequestId: 'ex04-create-$i',
          );
          await repo.submitExerciseAnswer(
            attemptId: att.attemptId,
            questionId: 'ex-04-q1',
            answer: const McAnswer('ex-04-q1-opt-2'),
            timeSpentSeconds: 5,
            submissionRequestId: 'ex04-a1-$i',
          );
          await repo.submitExerciseAnswer(
            attemptId: att.attemptId,
            questionId: 'ex-04-q2',
            answer: const McAnswer('ex-04-q2-opt-2'),
            timeSpentSeconds: 5,
            submissionRequestId: 'ex04-a2-$i',
          );
          await repo.submitExerciseAttempt(
            attemptId: att.attemptId,
            idempotencyKey: 'ex04-submit-$i',
          );
        }

        await _pushRoute(
          tester,
          AppRoutes.exerciseSession('ex-04', submaterialId: 'sub-04'),
        );
        expect(
          find.byKey(const ValueKey('exercise_load_error_view')),
          findsOneWidget,
        );
        expect(
          find.text(plasErrorMessage(ApiErrorCodes.attemptLimitReached)),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('exercise_error_back_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'BUG-001: M08 freezes submissionKey and timeSpentSeconds when retrying unchanged answer after 503 and mints new key when answer changes',
      (tester) async {
        final clock = _FakeClock(DateTime.utc(2026, 11, 20, 9, 0));
        final prefs = await SharedPreferences.getInstance();
        final authService = _TestAuthService(initialUser: _defaultUser());
        addTearDown(authService.dispose);
        final repo = _SpyPlasRepository(initialProfile: _defaultProfile());

        final router = GoRouter(
          initialLocation: '/exercises/ex-01/session',
          routes: [
            GoRoute(
              path: '/exercises/:exerciseId/session',
              builder: (context, state) => ExerciseSessionScreen(
                exerciseId: state.pathParameters['exerciseId']!,
                submaterialId: 'sub-01',
                clock: clock.call,
              ),
            ),
            GoRoute(
              path: '/exercise-attempts/:attemptId/review',
              builder: (context, state) => ExerciseReviewScreen(
                attemptId: state.pathParameters['attemptId']!,
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authServiceProvider.overrideWithValue(authService),
              plasRepositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp.router(
              theme: buildPlasTheme(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance clock by 12s while viewing Q1.
        clock.advance(const Duration(seconds: 12));
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_ex-01-q1-opt-1')),
        );

        // Simulate server committing Q1 then dropping connection with 503.
        repo.commitBeforeThrowingNextAnswerError = true;
        repo.nextSubmitAnswerError = PlasApiException.fromApiCode(
          ApiErrorCodes.serverError,
          statusCode: 503,
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_submit_cta')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('exercise_submission_error_view')),
          findsOneWidget,
        );
        expect(find.text('Soal 1 dari 2'), findsOneWidget);
        expect(repo.recordedAnswerCalls, hasLength(1));
        expect(repo.recordedAnswerCalls.first.timeSpentSeconds, 12);

        // Advance clock 15s and retry unchanged answer -> must reuse exact key & frozen 12s.
        clock.advance(const Duration(seconds: 15));
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_submit_cta')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Soal 2 dari 2'), findsOneWidget);
        expect(repo.recordedAnswerCalls, hasLength(2));
        expect(
          repo.recordedAnswerCalls[1].submissionRequestId,
          repo.recordedAnswerCalls[0].submissionRequestId,
        );
        expect(repo.recordedAnswerCalls[1].timeSpentSeconds, 12);

        // Q2: fail without commit, then change selected option -> must mint fresh UUID & elapsed.
        clock.advance(const Duration(seconds: 5));
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_ex-01-q2-opt-1')),
        );
        repo.commitBeforeThrowingNextAnswerError = false;
        repo.nextSubmitAnswerError = PlasApiException.fromApiCode(
          ApiErrorCodes.serverError,
          statusCode: 503,
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_submit_cta')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('exercise_submission_error_view')),
          findsOneWidget,
        );
        expect(repo.recordedAnswerCalls, hasLength(3));
        final q2FirstKey = repo.recordedAnswerCalls[2].submissionRequestId;
        expect(repo.recordedAnswerCalls[2].timeSpentSeconds, 5);

        clock.advance(const Duration(seconds: 8));
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('question_mc_option_ex-01-q2-opt-2')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('exercise_submission_error_view')),
          findsNothing,
        );

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_submit_cta')),
        );
        await tester.pumpAndSettle();

        expect(repo.recordedAnswerCalls, hasLength(4));
        expect(
          repo.recordedAnswerCalls[3].submissionRequestId,
          isNot(q2FirstKey),
        );
        expect(
          repo.recordedAnswerCalls[3].answer,
          const McAnswer('ex-01-q2-opt-2'),
        );
        expect(repo.recordedAnswerCalls[3].timeSpentSeconds, 13);

        await _tapVisible(tester, find.text('Kumpulkan'));
        await tester.pumpAndSettle();
        expect(find.byType(ExerciseReviewScreen), findsOneWidget);
        expect(find.text('100%'), findsOneWidget);
      },
    );
  });

  group('M08 & M13 390x844 @ 2.0x text scale layout & zero em dash', () {
    testWidgets(
      'renders PlasAccuracyRing, QuestionAnswerInput, M08 MC/TF/FIB, and M13 with zero overflow and zero em dashes at 390px @ 2.0x',
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

        await tester.pumpWidget(
          _buildApp(prefs: prefs, authService: authService, repository: repo),
        );
        await tester.pumpAndSettle();

        // 1. M08 MC @ 2.0x
        await _pushRoute(
          tester,
          AppRoutes.exerciseSession('ex-01', submaterialId: 'sub-01'),
        );
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_hint_toggle')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);

        // 2. M08 TF @ 2.0x
        await _pushRoute(
          tester,
          AppRoutes.exerciseSession('ex-03', submaterialId: 'sub-03'),
        );
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);

        // 3. M08 FIB @ 2.0x -> submit -> M13 @ 2.0x
        await _pushRoute(
          tester,
          AppRoutes.exerciseSession('ex-02', submaterialId: 'sub-02'),
        );
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);

        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('question_fib_field')),
          'const',
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_submit_cta')),
        );
        await tester.pumpAndSettle();

        await _enterVisibleText(
          tester,
          find.byKey(const ValueKey('question_fib_field')),
          'boolean',
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('exercise_submit_cta')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);

        await _tapVisible(tester, find.text('Kumpulkan'));
        await tester.pumpAndSettle();

        expect(find.byType(ExerciseReviewScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        _assertNoEmDashInTexts(tester);
        _assertNoAnswerKeysInTree(tester);

        await tester.ensureVisible(
          find.byKey(const ValueKey('review_back_to_material_button')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
