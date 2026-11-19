import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/sync/pending_sync_queue.dart';
import 'package:plasmobile/data/dto/ai_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/data/dto/student_profile_dto.dart';
import 'package:plasmobile/data/repositories/mock_plas_repository.dart';
import 'package:plasmobile/data/repositories/mock_seed_data.dart';
import 'package:plasmobile/data/repositories/plas_repository.dart';

class _FakeClock {
  _FakeClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration delta) {
    now = now.add(delta);
  }
}

Future<void> _completeExercise(
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
    final StudentAnswer answer;
    switch (q.questionType) {
      case QuestionType.mc:
        answer = McAnswer(q.correctOptionId!);
      case QuestionType.tf:
        answer = TfAnswer(q.correctBoolean!);
      case QuestionType.fib:
        answer = FibAnswer(q.correctText!);
    }
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
}

Future<String> _completeTest(
  MockPlasRepository repo,
  _FakeClock clock, {
  required String testId,
  required String keyPrefix,
}) async {
  final start = await repo.createTestAttempt(
    testId: testId,
    creationRequestId: '$keyPrefix-create',
  );
  final seed = MockSeedData.findTest(testId)!;
  for (var i = 0; i < seed.questions.length; i++) {
    final q = seed.questions[i];
    await repo.startTestQuestion(
      attemptId: start.attemptId,
      sequence: q.sequence,
    );
    clock.advance(const Duration(seconds: 15));
    final StudentAnswer answer;
    switch (q.questionType) {
      case QuestionType.mc:
        answer = McAnswer(q.correctOptionId!);
      case QuestionType.tf:
        answer = TfAnswer(q.correctBoolean!);
      case QuestionType.fib:
        answer = FibAnswer(q.correctText!);
    }
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

void main() {
  group('MockPlasRepository', () {
    test('onboarding, conflict NIM, class selection, and DBR-14 lock after PRE test', () async {
      final clock = _FakeClock(DateTime.utc(2026, 11, 19, 10, 0));
      final repo = MockPlasRepository(clock: clock.call);

      await expectLater(
        () => repo.getMe(),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.profileNotFound)
              .having((e) => e.statusCode, 'statusCode', 404),
        ),
      );

      final classes = await repo.getClasses();
      expect(classes.map((c) => c.kelasId), <String>[
        'kelas-ti2a-2026',
        'kelas-ti2b-2026',
      ]);

      await expectLater(
        () => repo.createProfile(
          CreateProfileRequest(nama: 'Mahasiswa', nim: '1' * 31),
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.validationError)
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );

      await expectLater(
        () => repo.createProfile(
          const CreateProfileRequest(
            nama: 'Mahasiswa Konflik',
            nim: kMockConflictNim,
          ),
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.nimConflict)
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      final created = await repo.createProfile(
        const CreateProfileRequest(
          nama: 'Sari Dewi',
          nim: '220101042',
          kelasId: 'kelas-ti2a-2026',
        ),
      );
      expect(created.kelas?.kelasId, 'kelas-ti2a-2026');
      expect(created.preTestSubmitted, isFalse);
      expect(created.remainingAiQuota, 10);

      // Idempotent on same NIM, conflict on different NIM
      final idempotent = await repo.createProfile(
        const CreateProfileRequest(nama: 'Sari Dewi', nim: '220101042'),
      );
      expect(idempotent.nim, '220101042');

      await expectLater(
        () => repo.createProfile(
          const CreateProfileRequest(nama: 'Orang Lain', nim: '220101099'),
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.nimConflict)
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      final general = await repo.updateClass(null);
      expect(general.kelas, isNull);

      final reassigned = await repo.updateClass('kelas-ti2b-2026');
      expect(reassigned.kelas?.kelasId, 'kelas-ti2b-2026');

      await _completeTest(
        repo,
        clock,
        testId: 'test-pre-01',
        keyPrefix: 'pre-lock',
      );

      final meAfterPre = await repo.getMe();
      expect(meAfterPre.preTestSubmitted, isTrue);

      await expectLater(
        () => repo.updateClass('kelas-ti2a-2026'),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.classLocked)
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('exercise rules: DBR-05 limit 3/3, DBR-06, ST001, ST002, OP001, AN001, FIB >= 70%, and P13', () async {
      final clock = _FakeClock(DateTime.utc(2026, 11, 19, 10, 0));
      final repo = MockPlasRepository(clock: clock.call);

      final materials = await repo.getMaterials();
      expect(materials, hasLength(7));
      expect(
        materials.map((m) => m.title).toList(),
        <String>[
          'Struktur Dasar Kode TypeScript',
          'Variabel & Type Annotation',
          'Tipe Data Dasar',
          'Operator dalam Ekspresi',
          'Conditional',
          'Loop',
          'Function',
        ],
      );

      // P13: ExerciseDetailDto omits explanation and answer keys
      final ex01Detail = await repo.getExercise('sub-01');
      expect(ex01Detail.questions, hasLength(2));
      for (final qJson in ex01Detail.toJson()['questions'] as List<dynamic>) {
        final qMap = qJson as Map<String, dynamic>;
        expect(qMap.containsKey('explanation'), isFalse);
        expect(qMap.containsKey('correct_option_id'), isFalse);
        expect(qMap.containsKey('correct_answer'), isFalse);
      }

      // Attempt 1 on ex-01 (MC): OP001 invalid option, type mismatch, ST002, DBR-06, P13, ST001
      final att1 = await repo.createExerciseAttempt(
        exerciseId: 'ex-01',
        creationRequestId: 'ex1-c1',
      );
      await expectLater(
        () => repo.submitExerciseAnswer(
          attemptId: att1.attemptId,
          questionId: 'ex-01-q1',
          answer: const McAnswer('opt-does-not-exist'),
          timeSpentSeconds: 5,
          submissionRequestId: 'ex1-bad-opt',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.invalidOption)
              .having((e) => e.statusCode, 'statusCode', 422),
        ),
      );

      await expectLater(
        () => repo.submitExerciseAnswer(
          attemptId: att1.attemptId,
          questionId: 'ex-01-q1',
          answer: const TfAnswer(true),
          timeSpentSeconds: 5,
          submissionRequestId: 'ex1-bad-type',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.typeMismatch)
              .having((e) => e.statusCode, 'statusCode', 422),
        ),
      );

      final ans1 = await repo.submitExerciseAnswer(
        attemptId: att1.attemptId,
        questionId: 'ex-01-q1',
        answer: const McAnswer('ex-01-q1-opt-1'),
        timeSpentSeconds: 12,
        submissionRequestId: 'ex1-a1',
      );
      expect(ans1.isCorrect, isTrue);
      expect(ans1.explanation, isNotNull);

      // DBR-06: duplicate question with new key
      await expectLater(
        () => repo.submitExerciseAnswer(
          attemptId: att1.attemptId,
          questionId: 'ex-01-q1',
          answer: const McAnswer('ex-01-q1-opt-1'),
          timeSpentSeconds: 12,
          submissionRequestId: 'ex1-a1-dup-new-key',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.alreadyAnswered)
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      // P13: IN_PROGRESS detail hides explanation
      final inProgressDetail =
          await repo.getExerciseAttemptDetail(att1.attemptId);
      expect(inProgressDetail.items.first.explanation, isNull);
      expect(inProgressDetail.items.last.explanation, isNull);

      // ST002: incomplete submit rejected
      await expectLater(
        () => repo.submitExerciseAttempt(
          attemptId: att1.attemptId,
          idempotencyKey: 'ex1-sub-incomplete',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.incompleteAnswers)
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      await repo.submitExerciseAnswer(
        attemptId: att1.attemptId,
        questionId: 'ex-01-q2',
        answer: const McAnswer('ex-01-q2-opt-1'),
        timeSpentSeconds: 8,
        submissionRequestId: 'ex1-a2',
      );
      final submitted1 = await repo.submitExerciseAttempt(
        attemptId: att1.attemptId,
        idempotencyKey: 'ex1-sub-1',
      );
      expect(submitted1.score, 50.0);

      // P13: SUBMITTED detail exposes explanation, never answer keys
      final submittedDetail =
          await repo.getExerciseAttemptDetail(att1.attemptId);
      expect(submittedDetail.items.first.explanation, isNotNull);
      expect(submittedDetail.items.last.explanation, isNotNull);
      for (final itemJson in submittedDetail.toJson()['items'] as List<dynamic>) {
        final itemMap = itemJson as Map<String, dynamic>;
        expect(itemMap.containsKey('correct_option_id'), isFalse);
        expect(itemMap.containsKey('correct_answer'), isFalse);
      }

      // ST001: new submit key or answer after SUBMITTED rejected
      await expectLater(
        () => repo.submitExerciseAttempt(
          attemptId: att1.attemptId,
          idempotencyKey: 'ex1-sub-1-new-key',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.alreadySubmitted)
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      // Attempts 2 and 3 succeed; 4th throws 409 attempt_limit_reached (DBR-05)
      await repo.createExerciseAttempt(
        exerciseId: 'ex-01',
        creationRequestId: 'ex1-c2',
      );
      await repo.createExerciseAttempt(
        exerciseId: 'ex-01',
        creationRequestId: 'ex1-c3',
      );
      await expectLater(
        () => repo.createExerciseAttempt(
          exerciseId: 'ex-01',
          creationRequestId: 'ex1-c4',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.attemptLimitReached)
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      // AN001 (> 255) & FIB >= 70% Levenshtein evaluation on ex-02
      final ex02Att = await repo.createExerciseAttempt(
        exerciseId: 'ex-02',
        creationRequestId: 'ex2-c1',
      );
      await expectLater(
        () => repo.submitExerciseAnswer(
          attemptId: ex02Att.attemptId,
          questionId: 'ex-02-q1',
          answer: FibAnswer('a' * 256),
          timeSpentSeconds: 4,
          submissionRequestId: 'ex2-too-long',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.invalidAnswer)
              .having((e) => e.statusCode, 'statusCode', 422),
        ),
      );

      // 'conzt' vs 'const' -> 4/5 = 80% >= 70%
      final fibNearMatch = await repo.submitExerciseAnswer(
        attemptId: ex02Att.attemptId,
        questionId: 'ex-02-q1',
        answer: const FibAnswer('  CONZT '),
        timeSpentSeconds: 9,
        submissionRequestId: 'ex2-a1',
      );
      expect(fibNearMatch.isCorrect, isTrue);

      // 'bolean' vs 'boolean' -> 6/7 = 85.7% >= 70%
      final fibNearMatch2 = await repo.submitExerciseAnswer(
        attemptId: ex02Att.attemptId,
        questionId: 'ex-02-q2',
        answer: const FibAnswer('bolean'),
        timeSpentSeconds: 7,
        submissionRequestId: 'ex2-a2',
      );
      expect(fibNearMatch2.isCorrect, isTrue);
    });

    test('DBR-15: POST test rejected until all 7 exercises have >= 1 SUBMITTED attempt', () async {
      final clock = _FakeClock(DateTime.utc(2026, 11, 19, 10, 0));
      final repo = MockPlasRepository(clock: clock.call);

      for (var i = 1; i <= 6; i++) {
        final overview = await repo.getTests();
        expect(overview.postTest.isEligible, isFalse);
        expect(overview.postTest.completedExercises, i - 1);

        await expectLater(
          () => repo.createTestAttempt(
            testId: 'test-post-01',
            creationRequestId: 'post-fail-$i',
          ),
          throwsA(
            isA<PlasApiException>()
                .having((e) => e.code, 'code', ApiErrorCodes.prerequisiteNotMet)
                .having((e) => e.statusCode, 'statusCode', 409),
          ),
        );

        await _completeExercise(
          repo,
          exerciseId: 'ex-0$i',
          keyPrefix: 'done-$i',
        );
      }

      // Still 6/7 completed
      await expectLater(
        () => repo.createTestAttempt(
          testId: 'test-post-01',
          creationRequestId: 'post-fail-6-of-7',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.prerequisiteNotMet),
        ),
      );

      // Complete 7th exercise
      await _completeExercise(repo, exerciseId: 'ex-07', keyPrefix: 'done-7');

      final overviewReady = await repo.getTests();
      expect(overviewReady.postTest.isEligible, isTrue);
      expect(overviewReady.postTest.completedExercises, 7);

      final postStart = await repo.createTestAttempt(
        testId: 'test-post-01',
        creationRequestId: 'post-ok',
      );
      expect(postStart.testId, 'test-post-01');
      expect(postStart.firstQuestion, isNull);
    });

    test('test rules: DBR-07, DBR-08, P7 set-if-NULL, frozen options, resume, and P13 result', () async {
      final clock = _FakeClock(DateTime.utc(2026, 11, 19, 10, 0));
      final repo = MockPlasRepository(clock: clock.call);

      final start = await repo.createTestAttempt(
        testId: 'test-pre-01',
        creationRequestId: 't-create-1',
      );
      expect(start.firstQuestion, isNull);
      expect(start.totalQuestions, 5);

      // DBR-07: duplicate createTestAttempt with new key throws attempt_exists
      await expectLater(
        () => repo.createTestAttempt(
          testId: 'test-pre-01',
          creationRequestId: 't-create-2',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.attemptExists)
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      // DBR-08: skipping sequence 1 -> 2 throws wrong_sequence
      await expectLater(
        () => repo.startTestQuestion(attemptId: start.attemptId, sequence: 2),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.wrongSequence)
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      // P7: start seq 1 records questionStartedAt and freezes MC option order
      final q1Start = await repo.startTestQuestion(
        attemptId: start.attemptId,
        sequence: 1,
      );
      final q1OptionOrder = q1Start.options.map((o) => o.optionId).toList();
      expect(q1OptionOrder, hasLength(4));

      // Advance clock and re-call startTestQuestion + resumeTestAttempt -> timestamp & order preserved
      clock.advance(const Duration(seconds: 40));
      final q1Restart = await repo.startTestQuestion(
        attemptId: start.attemptId,
        sequence: 1,
      );
      expect(q1Restart.questionStartedAt, q1Start.questionStartedAt);
      expect(
        q1Restart.options.map((o) => o.optionId).toList(),
        q1OptionOrder,
      );

      final q1Resume = await repo.resumeTestAttempt(start.attemptId);
      expect(q1Resume.sequence, 1);
      expect(q1Resume.questionStartedAt, q1Start.questionStartedAt);
      expect(
        q1Resume.options.map((o) => o.optionId).toList(),
        q1OptionOrder,
      );

      // Answer seq 1 (40s elapsed)
      final ack1 = await repo.submitTestAnswer(
        attemptId: start.attemptId,
        sequence: 1,
        answer: const McAnswer('pre-q1-opt-1'),
        submissionRequestId: 't-ans-1',
      );
      expect(ack1.nextSequence, 2);

      // DBR-08: re-starting or re-answering seq 1 with new key throws already_answered
      await expectLater(
        () => repo.startTestQuestion(attemptId: start.attemptId, sequence: 1),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.alreadyAnswered)
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      // Result unavailable before submit
      await expectLater(
        () => repo.getTestAttemptResult(start.attemptId),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.invalidStateTransition)
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      // Incomplete submit rejected
      await expectLater(
        () => repo.submitTestAttempt(
          attemptId: start.attemptId,
          idempotencyKey: 't-sub-early',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.incompleteAnswers)
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      // Complete sequences 2..5
      for (var seq = 2; seq <= 5; seq++) {
        final qSeed = MockSeedData.preTest.questions[seq - 1];
        await repo.startTestQuestion(attemptId: start.attemptId, sequence: seq);
        clock.advance(const Duration(seconds: 10));
        final StudentAnswer ans;
        switch (qSeed.questionType) {
          case QuestionType.mc:
            ans = McAnswer(qSeed.correctOptionId!);
          case QuestionType.tf:
            ans = TfAnswer(qSeed.correctBoolean!);
          case QuestionType.fib:
            ans = FibAnswer(qSeed.correctText!);
        }
        final ack = await repo.submitTestAnswer(
          attemptId: start.attemptId,
          sequence: seq,
          answer: ans,
          submissionRequestId: 't-ans-$seq',
        );
        expect(ack.nextSequence, seq < 5 ? seq + 1 : isNull);
      }

      final submitted = await repo.submitTestAttempt(
        attemptId: start.attemptId,
        idempotencyKey: 't-sub-final',
      );
      expect(submitted.score, 100.0);
      expect(submitted.items.first.timeSpentSeconds, 40);

      // Resume after SUBMITTED throws 409 attempt_submitted
      await expectLater(
        () => repo.resumeTestAttempt(start.attemptId),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.attemptSubmitted)
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      // P13: result exposes isCorrect & duration, zero explanation/answer keys
      final fetchedResult = await repo.getTestAttemptResult(start.attemptId);
      expect(fetchedResult.items, hasLength(5));
      for (final itemJson in fetchedResult.toJson()['items'] as List<dynamic>) {
        final itemMap = itemJson as Map<String, dynamic>;
        expect(itemMap.containsKey('explanation'), isFalse);
        expect(itemMap.containsKey('correct_option_id'), isFalse);
        expect(itemMap.containsKey('correct_answer'), isFalse);
      }
    });

    test('P2 idempotency replays matching payloads and rejects conflicts across Exercise, Test, and AI', () async {
      final clock = _FakeClock(DateTime.utc(2026, 11, 19, 10, 0));
      final repo = MockPlasRepository(clock: clock.call);

      // Exercise create + answer idempotency
      final exAttempt1 = await repo.createExerciseAttempt(
        exerciseId: 'ex-01',
        creationRequestId: 'k-ex-create',
      );
      final exAttemptReplay = await repo.createExerciseAttempt(
        exerciseId: 'ex-01',
        creationRequestId: 'k-ex-create',
      );
      expect(exAttemptReplay.attemptId, exAttempt1.attemptId);

      await expectLater(
        () => repo.createExerciseAttempt(
          exerciseId: 'ex-02',
          creationRequestId: 'k-ex-create',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.idempotencyConflict)
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      final exAns1 = await repo.submitExerciseAnswer(
        attemptId: exAttempt1.attemptId,
        questionId: 'ex-01-q1',
        answer: const McAnswer('ex-01-q1-opt-1'),
        timeSpentSeconds: 10,
        submissionRequestId: 'k-ex-ans',
      );
      final exAnsReplay = await repo.submitExerciseAnswer(
        attemptId: exAttempt1.attemptId,
        questionId: 'ex-01-q1',
        answer: const McAnswer('ex-01-q1-opt-1'),
        timeSpentSeconds: 10,
        submissionRequestId: 'k-ex-ans',
      );
      expect(exAnsReplay.answeredAt, exAns1.answeredAt);

      await expectLater(
        () => repo.submitExerciseAnswer(
          attemptId: exAttempt1.attemptId,
          questionId: 'ex-01-q1',
          answer: const McAnswer('ex-01-q1-opt-2'),
          timeSpentSeconds: 10,
          submissionRequestId: 'k-ex-ans',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.idempotencyConflict),
        ),
      );

      // Test create + start + answer idempotency
      final tStart1 = await repo.createTestAttempt(
        testId: 'test-pre-01',
        creationRequestId: 'k-t-create',
      );
      final tStartReplay = await repo.createTestAttempt(
        testId: 'test-pre-01',
        creationRequestId: 'k-t-create',
      );
      expect(tStartReplay.attemptId, tStart1.attemptId);

      await expectLater(
        () => repo.createTestAttempt(
          testId: 'test-other',
          creationRequestId: 'k-t-create',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.idempotencyConflict),
        ),
      );

      final tAck1 = await repo.submitTestAnswer(
        attemptId: tStart1.attemptId,
        sequence: 1,
        answer: const McAnswer('pre-q1-opt-1'),
        submissionRequestId: 'k-t-ans',
      );
      final tAckReplay = await repo.submitTestAnswer(
        attemptId: tStart1.attemptId,
        sequence: 1,
        answer: const McAnswer('pre-q1-opt-1'),
        submissionRequestId: 'k-t-ans',
      );
      expect(tAckReplay.answeredAt, tAck1.answeredAt);

      await expectLater(
        () => repo.submitTestAnswer(
          attemptId: tStart1.attemptId,
          sequence: 1,
          answer: const McAnswer('pre-q1-opt-2'),
          submissionRequestId: 'k-t-ans',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.idempotencyConflict),
        ),
      );

      // AI idempotency conflict
      const aiReq = AiAskRequestDto(
        question: 'Apa beda let dan const?',
        submaterialId: 'sub-02',
        hintLevel: AiHintLevel.konsepDasar,
      );
      await repo.askAi(request: aiReq, requestId: 'k-ai-1');
      await expectLater(
        () => repo.askAi(
          request: const AiAskRequestDto(
            question: 'Pertanyaan berbeda',
            submaterialId: 'sub-02',
            hintLevel: AiHintLevel.konsepDasar,
          ),
          requestId: 'k-ai-1',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.idempotencyConflict),
        ),
      );
    });

    test('P12 AI WITA quota: 3 hint levels, 502 retry without quota loss, already_processed, 403 limit, and 16:00 UTC reset', () async {
      // 15:59 UTC == 23:59 WITA on 2026-11-19
      final clock = _FakeClock(DateTime.utc(2026, 11, 19, 15, 59));
      final repo = MockPlasRepository(clock: clock.call);

      final r1 = await repo.askAi(
        request: const AiAskRequestDto(
          question: 'Jelaskan konsep dasar TypeScript.',
          submaterialId: 'sub-01',
          hintLevel: AiHintLevel.konsepDasar,
        ),
        requestId: 'ai-1',
      );
      final r2 = await repo.askAi(
        request: const AiAskRequestDto(
          question: 'Bagaimana strategi menyelesaikan soal ini?',
          submaterialId: 'sub-01',
          hintLevel: AiHintLevel.strategi,
        ),
        requestId: 'ai-2',
      );
      final r3 = await repo.askAi(
        request: const AiAskRequestDto(
          question: 'Mengapa tipe statis mencegah bug?',
          submaterialId: 'sub-01',
          hintLevel: AiHintLevel.penalaran,
        ),
        requestId: 'ai-3',
      );

      expect(r1.answer, isNot(equals(r2.answer)));
      expect(r2.answer, isNot(equals(r3.answer)));
      expect(r1.answer!.contains('\u2014'), isFalse);
      expect(r2.answer!.contains('\u2014'), isFalse);
      expect(r3.answer!.contains('\u2014'), isFalse);
      expect(r3.remainingQuota, 7);

      // Replay after SUCCESS -> already_processed without consuming quota
      final replaySuccess = await repo.askAi(
        request: const AiAskRequestDto(
          question: 'Mengapa tipe statis mencegah bug?',
          submaterialId: 'sub-01',
          hintLevel: AiHintLevel.penalaran,
        ),
        requestId: 'ai-3',
      );
      expect(replaySuccess.status, AiAskStatus.alreadyProcessed);
      expect(replaySuccess.answer, isNull);
      expect(replaySuccess.hintLevel, isNull);
      expect(replaySuccess.remainingQuota, 7);

      // simulateAiFailure throws 502 without consuming quota and allows retry with same requestId
      repo.simulateAiFailure = true;
      await expectLater(
        () => repo.askAi(
          request: const AiAskRequestDto(
            question: 'Pertanyaan saat gangguan.',
            hintLevel: AiHintLevel.konsepDasar,
          ),
          requestId: 'ai-4',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.aiServiceError)
              .having((e) => e.statusCode, 'statusCode', 502),
        ),
      );
      expect((await repo.getAiQuota()).remainingQuota, 7);

      repo.simulateAiFailure = false;
      final retryAfterFailure = await repo.askAi(
        request: const AiAskRequestDto(
          question: 'Pertanyaan saat gangguan.',
          hintLevel: AiHintLevel.konsepDasar,
        ),
        requestId: 'ai-4',
      );
      expect(retryAfterFailure.status, AiAskStatus.success);
      expect(retryAfterFailure.remainingQuota, 6);

      // Exhaust remaining 6 slots (total 10)
      for (var i = 5; i <= 10; i++) {
        await repo.askAi(
          request: AiAskRequestDto(question: 'Pertanyaan ke-$i'),
          requestId: 'ai-$i',
        );
      }
      expect((await repo.getAiQuota()).remainingQuota, 0);

      // 11th request on same WITA day throws 403 quota_exceeded
      await expectLater(
        () => repo.askAi(
          request: const AiAskRequestDto(question: 'Pertanyaan ke-11'),
          requestId: 'ai-11',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.quotaExceeded)
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );

      // Advance clock past 16:00 UTC (00:00 WITA on 2026-11-20) -> resets to 10/10
      clock.now = DateTime.utc(2026, 11, 19, 16, 0);
      final resetQuota = await repo.getAiQuota();
      expect(resetQuota.remainingQuota, 10);
      expect(resetQuota.usageDate, '2026-11-20');

      final afterMidnight = await repo.askAi(
        request: const AiAskRequestDto(question: 'Pertanyaan hari baru'),
        requestId: 'ai-day2-1',
      );
      expect(afterMidnight.remainingQuota, 9);
    });

    test('offline toggle, replayPendingSyncItem for Exercise & Test, and activities ordering', () async {
      final clock = _FakeClock(DateTime.utc(2026, 11, 19, 10, 0));
      final repo = MockPlasRepository(clock: clock.call);

      final exAtt = await repo.createExerciseAttempt(
        exerciseId: 'ex-03',
        creationRequestId: 'sync-ex-c',
      );
      await repo.submitExerciseAnswer(
        attemptId: exAtt.attemptId,
        questionId: 'ex-03-q1',
        answer: const TfAnswer(true),
        timeSpentSeconds: 5,
        submissionRequestId: 'sync-ex-a1',
      );

      final tStart = await repo.createTestAttempt(
        testId: 'test-pre-01',
        creationRequestId: 'sync-t-c',
      );
      for (var seq = 1; seq <= 4; seq++) {
        final q = MockSeedData.preTest.questions[seq - 1];
        await repo.startTestQuestion(attemptId: tStart.attemptId, sequence: seq);
        final StudentAnswer ans = switch (q.questionType) {
          QuestionType.mc => McAnswer(q.correctOptionId!),
          QuestionType.tf => TfAnswer(q.correctBoolean!),
          QuestionType.fib => FibAnswer(q.correctText!),
        };
        await repo.submitTestAnswer(
          attemptId: tStart.attemptId,
          sequence: seq,
          answer: ans,
          submissionRequestId: 'sync-t-a-$seq',
        );
      }
      await repo.startTestQuestion(attemptId: tStart.attemptId, sequence: 5);

      // Go offline
      repo.simulateOffline = true;
      await expectLater(
        () => repo.getMaterials(),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.isOffline, 'isOffline', isTrue)
              .having((e) => e.code, 'code', ApiErrorCodes.networkOffline),
        ),
      );

      // Come back online and replay queued exercise + test items
      repo.simulateOffline = false;
      final queuedItems = <PendingSyncItem>[
        PendingSyncItem(
          idempotencyKey: 'sync-ex-a2',
          method: 'POST',
          path: '/exercise-attempts/${exAtt.attemptId}/answers',
          body: const <String, dynamic>{
            'question_id': 'ex-03-q2',
            'answer': <String, dynamic>{'value': false},
            'time_spent_seconds': 9,
          },
          createdAtIso: '2026-11-19T10:01:00.000Z',
          operationLabel: 'Kirim jawaban latihan',
        ),
        PendingSyncItem(
          idempotencyKey: 'sync-ex-sub',
          method: 'POST',
          path: '/exercise-attempts/${exAtt.attemptId}/submit',
          body: const <String, dynamic>{},
          createdAtIso: '2026-11-19T10:01:05.000Z',
          operationLabel: 'Kumpulkan latihan',
        ),
        PendingSyncItem(
          idempotencyKey: 'sync-t-a-5',
          method: 'POST',
          path: '/test-attempts/${tStart.attemptId}/questions/5/answers',
          body: const <String, dynamic>{
            'answer': <String, dynamic>{'value': 'return'},
          },
          createdAtIso: '2026-11-19T10:02:00.000Z',
          operationLabel: 'Kirim jawaban tes',
        ),
        PendingSyncItem(
          idempotencyKey: 'sync-t-sub',
          method: 'POST',
          path: '/test-attempts/${tStart.attemptId}/submit',
          body: const <String, dynamic>{},
          createdAtIso: '2026-11-19T10:02:05.000Z',
          operationLabel: 'Kumpulkan tes',
        ),
      ];

      for (final item in queuedItems) {
        await repo.replayPendingSyncItem(item);
        // Replay a second time idempotently
        await repo.replayPendingSyncItem(item);
      }

      final progress = await repo.getProgress();
      expect(progress.completedExercises, 1);
      expect(progress.preTestScore, 100.0);

      final activities = await repo.getActivities();
      expect(activities, hasLength(1));
      expect(activities.single.score, 100.0);
    });

    test('plasRepositoryProvider resolves MockPlasRepository by default (USE_MOCK=true)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(plasRepositoryProvider);
      expect(repo, isA<MockPlasRepository>());
    });
  });
}
