import 'dart:convert';
import 'dart:math';

import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/sync/pending_sync_queue.dart';
import 'package:plasmobile/core/utils/levenshtein.dart';
import 'package:plasmobile/core/utils/wita_clock.dart';
import 'package:plasmobile/data/dto/ai_dto.dart';
import 'package:plasmobile/data/dto/exercise_dto.dart';
import 'package:plasmobile/data/dto/material_dto.dart';
import 'package:plasmobile/data/dto/progress_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/data/dto/student_profile_dto.dart';
import 'package:plasmobile/data/dto/test_dto.dart';
import 'package:plasmobile/data/repositories/mock_seed_data.dart';
import 'package:plasmobile/data/repositories/plas_repository.dart';

class MockPlasRepository implements PlasRepository {
  MockPlasRepository({
    DateTime Function()? clock,
    StudentProfileDto? initialProfile,
    this.simulateOffline = false,
    this.simulateAiFailure = false,
  })  : _clock = clock ?? DateTime.now,
        _profile = initialProfile {
    _quotaUsageDate = witaDateString(_clock());
    _aiUsedToday = initialProfile != null
        ? (dailyAiQuotaLimit - initialProfile.remainingAiQuota)
            .clamp(0, dailyAiQuotaLimit)
        : 0;
  }

  static const int maxExerciseAttempts = 3;
  static const int dailyAiQuotaLimit = 10;

  static final RegExp _exerciseAnswerPathPattern = RegExp(
    r'^/exercise-attempts/([^/]+)/answers$',
  );
  static final RegExp _exerciseSubmitPathPattern = RegExp(
    r'^/exercise-attempts/([^/]+)/submit$',
  );
  static final RegExp _testAnswerPathPattern = RegExp(
    r'^/test-attempts/([^/]+)/questions/(\d+)/answers$',
  );
  static final RegExp _testSubmitPathPattern = RegExp(
    r'^/test-attempts/([^/]+)/submit$',
  );

  final DateTime Function() _clock;
  StudentProfileDto? _profile;
  bool simulateOffline;
  bool simulateAiFailure;

  late String _quotaUsageDate;
  late int _aiUsedToday;
  int _nextExerciseAttemptSeq = 1;
  int _nextTestAttemptSeq = 1;

  final Map<String, _ExerciseAttemptState> _exerciseAttempts =
      <String, _ExerciseAttemptState>{};
  final Map<String, List<String>> _exerciseAttemptIdsByExercise =
      <String, List<String>>{};

  final Map<String, _TestAttemptState> _testAttempts =
      <String, _TestAttemptState>{};
  final Map<String, String> _testAttemptIdByTestId = <String, String>{};

  final Map<(String, String), _IdempotencyEntry> _idempotencyStore =
      <(String, String), _IdempotencyEntry>{};
  final Map<String, _AiIdempotencyEntry> _aiIdempotencyStore =
      <String, _AiIdempotencyEntry>{};

  int get _remainingAiQuota =>
      (dailyAiQuotaLimit - _aiUsedToday).clamp(0, dailyAiQuotaLimit);

  bool get _isPreTestSubmitted {
    final preAttemptId = _testAttemptIdByTestId[MockSeedData.preTest.testId];
    final submitted = preAttemptId != null &&
        _testAttempts[preAttemptId]?.status == AttemptStatus.submitted;
    return (_profile?.preTestSubmitted ?? false) || submitted;
  }

  void _ensureOnline() {
    if (simulateOffline) {
      throw PlasApiException.offline();
    }
  }

  void _refreshQuotaWindow() {
    final todayWita = witaDateString(_clock());
    if (todayWita != _quotaUsageDate) {
      _quotaUsageDate = todayWita;
      _aiUsedToday = 0;
    }
  }

  // 4.1 Profil, Onboarding, & Kelas

  @override
  Future<StudentProfileDto> getMe() async {
    _ensureOnline();
    _refreshQuotaWindow();
    final profile = _profile;
    if (profile == null) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.profileNotFound,
        statusCode: 404,
      );
    }
    return profile.copyWith(
      remainingAiQuota: _remainingAiQuota,
      preTestSubmitted: _isPreTestSubmitted,
    );
  }

  @override
  Future<StudentProfileDto> createProfile(CreateProfileRequest request) async {
    _ensureOnline();
    _refreshQuotaWindow();

    final nama = request.nama.trim();
    final nim = request.nim.trim();
    if (nama.isEmpty || nim.isEmpty || nama.length > 100 || nim.length > 30) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.validationError,
        statusCode: 400,
      );
    }
    if (nim == kMockConflictNim) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.nimConflict,
        statusCode: 409,
      );
    }

    ClassInfoDto? selectedClass;
    if (request.kelasId != null) {
      selectedClass = MockSeedData.findClass(request.kelasId!);
      if (selectedClass == null) {
        throw PlasApiException.fromApiCode(
          ApiErrorCodes.notFound,
          statusCode: 404,
        );
      }
    }

    final existing = _profile;
    if (existing != null) {
      if (existing.nim == nim) {
        return existing.copyWith(
          remainingAiQuota: _remainingAiQuota,
          preTestSubmitted: _isPreTestSubmitted,
        );
      }
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.nimConflict,
        statusCode: 409,
      );
    }

    final created = StudentProfileDto(
      mahasiswaId: 'mhs-mock-01',
      nama: nama,
      nim: nim,
      kelas: selectedClass,
      preTestSubmitted: _isPreTestSubmitted,
      remainingAiQuota: _remainingAiQuota,
    );
    _profile = created;
    return created;
  }

  @override
  Future<List<ClassInfoDto>> getClasses() async {
    _ensureOnline();
    return List<ClassInfoDto>.unmodifiable(MockSeedData.classes);
  }

  @override
  Future<StudentProfileDto> updateClass(String? kelasId) async {
    _ensureOnline();
    _refreshQuotaWindow();

    final profile = _profile;
    if (profile == null) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.profileNotFound,
        statusCode: 404,
      );
    }
    if (_isPreTestSubmitted && profile.kelas != null) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.classLocked,
        statusCode: 409,
      );
    }

    ClassInfoDto? nextClass;
    if (kelasId != null) {
      nextClass = MockSeedData.findClass(kelasId);
      if (nextClass == null) {
        throw PlasApiException.fromApiCode(
          ApiErrorCodes.notFound,
          statusCode: 404,
        );
      }
    }

    final updated = profile.copyWith(
      kelas: nextClass,
      clearKelas: kelasId == null,
      remainingAiQuota: _remainingAiQuota,
      preTestSubmitted: _isPreTestSubmitted,
    );
    _profile = updated;
    return updated;
  }

  // 4.2 Materi

  @override
  Future<List<MaterialSummaryDto>> getMaterials() async {
    _ensureOnline();
    return List<MaterialSummaryDto>.unmodifiable(
      MockSeedData.materials.map(
        (m) => MaterialSummaryDto(
          materialId: m.materialId,
          sequence: m.sequence,
          title: m.title,
          description: m.description,
          submaterialCount: 1,
          completedExercises: _hasSubmittedExercise(m.exerciseId) ? 1 : 0,
        ),
      ),
    );
  }

  @override
  Future<MaterialDetailDto> getMaterialDetail(String materialId) async {
    _ensureOnline();
    final material = MockSeedData.findMaterial(materialId);
    if (material == null) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.notFound,
        statusCode: 404,
      );
    }

    final attempts = _attemptsForExercise(material.exerciseId);
    return MaterialDetailDto(
      materialId: material.materialId,
      sequence: material.sequence,
      title: material.title,
      description: material.description,
      submaterials: List<SubMaterialSummaryDto>.unmodifiable(
        <SubMaterialSummaryDto>[
          SubMaterialSummaryDto(
            submaterialId: material.submaterialId,
            sequence: material.submaterialSequence,
            title: material.submaterialTitle,
            hasSubmittedExercise: _hasSubmittedExercise(material.exerciseId),
            attemptsUsed: attempts.length,
            maxAttempts: maxExerciseAttempts,
          ),
        ],
      ),
    );
  }

  @override
  Future<SubMaterialDetailDto> getSubMaterial(String submaterialId) async {
    _ensureOnline();
    final material = MockSeedData.findBySubmaterialId(submaterialId);
    if (material == null) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.notFound,
        statusCode: 404,
      );
    }

    final attempts = _attemptsForExercise(material.exerciseId);
    final latestStatus = attempts.isEmpty ? null : attempts.last.status;
    double? bestScore;
    for (final attempt in attempts) {
      if (attempt.status == AttemptStatus.submitted && attempt.score != null) {
        if (bestScore == null || attempt.score! > bestScore) {
          bestScore = attempt.score;
        }
      }
    }

    return SubMaterialDetailDto(
      submaterialId: material.submaterialId,
      materialId: material.materialId,
      sequence: material.submaterialSequence,
      title: material.submaterialTitle,
      contentMarkdown: material.contentMarkdown,
      exercise: ExerciseOverviewDto(
        exerciseId: material.exerciseId,
        title: material.exerciseTitle,
        questionType: material.questionType,
        latestAttemptStatus: latestStatus,
        attemptsUsed: attempts.length,
        remainingAttempts: (maxExerciseAttempts - attempts.length)
            .clamp(0, maxExerciseAttempts),
        maxAttempts: maxExerciseAttempts,
        bestScore: bestScore,
      ),
    );
  }

  // 4.3 Exercise

  @override
  Future<ExerciseDetailDto> getExercise(String submaterialId) async {
    _ensureOnline();
    final material = MockSeedData.findBySubmaterialId(submaterialId);
    if (material == null) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.notFound,
        statusCode: 404,
      );
    }

    return ExerciseDetailDto(
      exerciseId: material.exerciseId,
      submaterialId: material.submaterialId,
      title: material.exerciseTitle,
      questionType: material.questionType,
      questions: List<ExerciseQuestionDto>.unmodifiable(
        material.questions.map((q) => q.toExerciseQuestionDto()),
      ),
    );
  }

  @override
  Future<ExerciseAttemptDto> createExerciseAttempt({
    required String exerciseId,
    required String creationRequestId,
  }) async {
    _ensureOnline();
    _requireNonEmptyKey(creationRequestId);

    const scope = 'create_exercise_attempt';
    final fp = _fingerprint(<String, Object?>{'exercise_id': exerciseId});
    final cached = _replayOrThrow<ExerciseAttemptDto>(
      scope,
      creationRequestId,
      fp,
    );
    if (cached != null) return cached;

    final material = MockSeedData.findByExerciseId(exerciseId);
    if (material == null) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.notFound,
        statusCode: 404,
      );
    }

    final existing = _attemptsForExercise(exerciseId);
    if (existing.length >= maxExerciseAttempts) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.attemptLimitReached,
        statusCode: 409,
      );
    }

    final attemptId = 'ex-att-${_nextExerciseAttemptSeq++}';
    final state = _ExerciseAttemptState(
      attemptId: attemptId,
      material: material,
      attemptNumber: existing.length + 1,
      startedAt: _clock().toUtc(),
    );
    _exerciseAttempts[attemptId] = state;
    _exerciseAttemptIdsByExercise
        .putIfAbsent(exerciseId, () => <String>[])
        .add(attemptId);

    final dto = state.toAttemptDto();
    _saveIdempotency(scope, creationRequestId, fp, dto);
    return dto;
  }

  @override
  Future<ExerciseAnswerResponseDto> submitExerciseAnswer({
    required String attemptId,
    required String questionId,
    required StudentAnswer answer,
    required int timeSpentSeconds,
    required String submissionRequestId,
  }) async {
    _ensureOnline();
    _requireNonEmptyKey(submissionRequestId);
    if (timeSpentSeconds < 0) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.validationError,
        statusCode: 400,
      );
    }

    final answerJson = answer.toJson();
    const scope = 'submit_exercise_answer';
    final fp = _fingerprint(<String, Object?>{
      'attempt_id': attemptId,
      'question_id': questionId,
      'answer': answerJson,
      'time_spent_seconds': timeSpentSeconds,
    });
    final cached = _replayOrThrow<ExerciseAnswerResponseDto>(
      scope,
      submissionRequestId,
      fp,
    );
    if (cached != null) return cached;

    final attempt = _exerciseAttempts[attemptId];
    if (attempt == null) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.notFound,
        statusCode: 404,
      );
    }
    if (attempt.status == AttemptStatus.submitted) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.alreadySubmitted,
        statusCode: 409,
      );
    }

    final seedQuestion = attempt.findQuestion(questionId);
    if (seedQuestion == null) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.notFound,
        statusCode: 404,
      );
    }
    if (attempt.answers.containsKey(questionId)) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.alreadyAnswered,
        statusCode: 409,
      );
    }

    final isCorrect = _evaluateExerciseAnswer(seedQuestion, answer);
    final answeredAt = _clock().toUtc();
    attempt.answers[questionId] = _ExerciseAnswerRecord(
      studentAnswer: answer,
      isCorrect: isCorrect,
      timeSpentSeconds: timeSpentSeconds,
      answeredAt: answeredAt,
    );

    final response = ExerciseAnswerResponseDto(
      attemptId: attemptId,
      questionId: questionId,
      isCorrect: isCorrect,
      explanation: seedQuestion.explanation,
      hint: seedQuestion.hint,
      answeredAt: answeredAt,
    );
    _saveIdempotency(scope, submissionRequestId, fp, response);
    return response;
  }

  @override
  Future<ExerciseAttemptDto> submitExerciseAttempt({
    required String attemptId,
    required String idempotencyKey,
  }) async {
    _ensureOnline();
    _requireNonEmptyKey(idempotencyKey);

    const scope = 'submit_exercise_attempt';
    final fp = _fingerprint(<String, Object?>{'attempt_id': attemptId});
    final cached = _replayOrThrow<ExerciseAttemptDto>(
      scope,
      idempotencyKey,
      fp,
    );
    if (cached != null) return cached;

    final attempt = _exerciseAttempts[attemptId];
    if (attempt == null) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.notFound,
        statusCode: 404,
      );
    }
    if (attempt.status == AttemptStatus.submitted) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.alreadySubmitted,
        statusCode: 409,
      );
    }
    if (attempt.answers.length < attempt.material.questions.length) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.incompleteAnswers,
        statusCode: 409,
      );
    }

    final total = attempt.material.questions.length;
    final correctCount = attempt.answers.values
        .where((record) => record.isCorrect)
        .length;
    attempt.status = AttemptStatus.submitted;
    attempt.score = (correctCount / total) * 100.0;
    attempt.submittedAt = _clock().toUtc();

    final dto = attempt.toAttemptDto();
    _saveIdempotency(scope, idempotencyKey, fp, dto);
    return dto;
  }

  @override
  Future<List<ExerciseAttemptDto>> getExerciseAttempts(
    String exerciseId,
  ) async {
    _ensureOnline();
    if (MockSeedData.findByExerciseId(exerciseId) == null) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.notFound,
        statusCode: 404,
      );
    }

    return List<ExerciseAttemptDto>.unmodifiable(
      _attemptsForExercise(exerciseId).map((attempt) => attempt.toAttemptDto()),
    );
  }

  @override
  Future<ExerciseAttemptDetailDto> getExerciseAttemptDetail(
    String attemptId,
  ) async {
    _ensureOnline();
    final attempt = _exerciseAttempts[attemptId];
    if (attempt == null) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.notFound,
        statusCode: 404,
      );
    }

    final isSubmitted = attempt.status == AttemptStatus.submitted;
    final items = attempt.material.questions.map((question) {
      final answerRecord = attempt.answers[question.questionId];
      return ExerciseReviewItemDto(
        questionId: question.questionId,
        sequence: question.sequence,
        questionText: question.questionText,
        questionType: question.questionType,
        options: question.options,
        studentAnswer: answerRecord?.studentAnswer,
        isCorrect: answerRecord?.isCorrect,
        explanation: isSubmitted ? question.explanation : null,
        hint: question.hint,
        timeSpentSeconds: answerRecord?.timeSpentSeconds ?? 0,
      );
    }).toList();

    return ExerciseAttemptDetailDto(
      attemptId: attempt.attemptId,
      exerciseId: attempt.material.exerciseId,
      exerciseTitle: attempt.material.exerciseTitle,
      attemptNumber: attempt.attemptNumber,
      status: attempt.status,
      score: attempt.score,
      startedAt: attempt.startedAt,
      submittedAt: attempt.submittedAt,
      items: List<ExerciseReviewItemDto>.unmodifiable(items),
    );
  }

  // 4.4 Pre-Test / Post-Test

  @override
  Future<TestsOverviewDto> getTests() async {
    _ensureOnline();
    final completed = _completedExerciseCount();
    final total = MockSeedData.materials.length;

    return TestsOverviewDto(
      preTest: _buildTestOverview(
        MockSeedData.preTest,
        isEligible: true,
        completedExercises: completed,
        totalExercises: total,
      ),
      postTest: _buildTestOverview(
        MockSeedData.postTest,
        isEligible: completed == total,
        completedExercises: completed,
        totalExercises: total,
      ),
    );
  }

  @override
  Future<TestAttemptStartDto> createTestAttempt({
    required String testId,
    required String creationRequestId,
  }) async {
    _ensureOnline();
    _requireNonEmptyKey(creationRequestId);

    const scope = 'create_test_attempt';
    final fp = _fingerprint(<String, Object?>{'test_id': testId});
    final cached = _replayOrThrow<TestAttemptStartDto>(
      scope,
      creationRequestId,
      fp,
    );
    if (cached != null) return cached;

    final seedTest = MockSeedData.findTest(testId);
    if (seedTest == null) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.notFound,
        statusCode: 404,
      );
    }
    if (seedTest.questions.isEmpty) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.testEmpty,
        statusCode: 422,
      );
    }

    if (seedTest.testType == TestType.post &&
        _completedExerciseCount() < MockSeedData.materials.length) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.prerequisiteNotMet,
        statusCode: 409,
      );
    }
    if (_testAttemptIdByTestId.containsKey(testId)) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.attemptExists,
        statusCode: 409,
      );
    }

    final attemptId = 'test-att-${_nextTestAttemptSeq++}';
    final startedAt = _clock().toUtc();
    final snapshots = seedTest.questions.map((q) {
      final frozenOptions = q.questionType == QuestionType.mc
          ? _shuffleOptionsOnce(
              q.options,
              Object.hash(testId, creationRequestId, q.questionId),
            )
          : const <QuestionOptionDto>[];
      return _TestQuestionSnapshot(
        questionId: q.questionId,
        sequence: q.sequence,
        questionText: q.questionText,
        questionType: q.questionType,
        options: frozenOptions,
        correctOptionId: q.correctOptionId,
        correctBoolean: q.correctBoolean,
        correctText: q.correctText,
      );
    }).toList(growable: false);

    final state = _TestAttemptState(
      attemptId: attemptId,
      test: seedTest,
      startedAt: startedAt,
      snapshots: snapshots,
    );
    _testAttempts[attemptId] = state;
    _testAttemptIdByTestId[testId] = attemptId;

    final dto = TestAttemptStartDto(
      attemptId: attemptId,
      testId: seedTest.testId,
      testType: seedTest.testType,
      status: AttemptStatus.inProgress,
      totalQuestions: snapshots.length,
      currentSequence: 1,
      startedAt: startedAt,
      firstQuestion: null,
    );
    _saveIdempotency(scope, creationRequestId, fp, dto);
    return dto;
  }

  @override
  Future<TestActiveQuestionDto> startTestQuestion({
    required String attemptId,
    required int sequence,
    String? idempotencyKey,
  }) async {
    _ensureOnline();
    String? fp;
    const scope = 'start_test_question';
    if (idempotencyKey != null) {
      _requireNonEmptyKey(idempotencyKey);
      fp = _fingerprint(<String, Object?>{
        'attempt_id': attemptId,
        'sequence': sequence,
      });
      final cached = _replayOrThrow<TestActiveQuestionDto>(
        scope,
        idempotencyKey,
        fp,
      );
      if (cached != null) return cached;
    }

    final attempt = _testAttempts[attemptId];
    if (attempt == null) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.notFound,
        statusCode: 404,
      );
    }
    if (attempt.status == AttemptStatus.submitted) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.attemptSubmitted,
        statusCode: 409,
      );
    }
    if (sequence < 1 || sequence > attempt.snapshots.length) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.validationError,
        statusCode: 400,
      );
    }

    _enforceLinearSequence(attempt, sequence);

    final snapshot = attempt.snapshots[sequence - 1];
    snapshot.questionStartedAt ??= _clock().toUtc();

    final dto = TestActiveQuestionDto(
      sequence: snapshot.sequence,
      totalQuestions: attempt.snapshots.length,
      questionText: snapshot.questionText,
      questionType: snapshot.questionType,
      options: snapshot.options,
      questionStartedAt: snapshot.questionStartedAt!,
    );
    if (idempotencyKey != null && fp != null) {
      _saveIdempotency(scope, idempotencyKey, fp, dto);
    }
    return dto;
  }

  @override
  Future<TestAnswerAckDto> submitTestAnswer({
    required String attemptId,
    required int sequence,
    required StudentAnswer answer,
    required String submissionRequestId,
  }) async {
    _ensureOnline();
    _requireNonEmptyKey(submissionRequestId);

    final answerJson = answer.toJson();
    const scope = 'submit_test_answer';
    final fp = _fingerprint(<String, Object?>{
      'attempt_id': attemptId,
      'sequence': sequence,
      'answer': answerJson,
    });
    final cached = _replayOrThrow<TestAnswerAckDto>(
      scope,
      submissionRequestId,
      fp,
    );
    if (cached != null) return cached;

    final attempt = _testAttempts[attemptId];
    if (attempt == null) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.notFound,
        statusCode: 404,
      );
    }
    if (attempt.status == AttemptStatus.submitted) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.attemptSubmitted,
        statusCode: 409,
      );
    }
    if (sequence < 1 || sequence > attempt.snapshots.length) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.validationError,
        statusCode: 400,
      );
    }

    _enforceLinearSequence(attempt, sequence);

    final snapshot = attempt.snapshots[sequence - 1];
    final isCorrect = _evaluateTestSnapshotAnswer(snapshot, answer);

    final answeredAt = _clock().toUtc();
    final startedAt = snapshot.questionStartedAt ?? answeredAt;
    final rawElapsed = answeredAt.difference(startedAt).inSeconds;
    final timeSpentSeconds = rawElapsed < 0 ? 0 : rawElapsed;

    attempt.answers[sequence] = _TestAnswerRecord(
      studentAnswer: answer,
      isCorrect: isCorrect,
      timeSpentSeconds: timeSpentSeconds,
      answeredAt: answeredAt,
    );
    attempt.currentSequence = sequence + 1;

    final nextSequence =
        sequence < attempt.snapshots.length ? sequence + 1 : null;
    final ack = TestAnswerAckDto(
      attemptId: attemptId,
      sequence: sequence,
      isRecorded: true,
      answeredAt: answeredAt,
      nextSequence: nextSequence,
    );
    _saveIdempotency(scope, submissionRequestId, fp, ack);
    return ack;
  }

  @override
  Future<TestActiveQuestionDto> resumeTestAttempt(String attemptId) async {
    _ensureOnline();
    final attempt = _testAttempts[attemptId];
    if (attempt == null) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.notFound,
        statusCode: 404,
      );
    }
    if (attempt.status == AttemptStatus.submitted) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.attemptSubmitted,
        statusCode: 409,
      );
    }

    _TestQuestionSnapshot? activeSnapshot;
    for (final snapshot in attempt.snapshots) {
      if (!attempt.answers.containsKey(snapshot.sequence)) {
        activeSnapshot = snapshot;
        break;
      }
    }
    activeSnapshot ??= attempt.snapshots.last;
    activeSnapshot.questionStartedAt ??= _clock().toUtc();

    return TestActiveQuestionDto(
      sequence: activeSnapshot.sequence,
      totalQuestions: attempt.snapshots.length,
      questionText: activeSnapshot.questionText,
      questionType: activeSnapshot.questionType,
      options: activeSnapshot.options,
      questionStartedAt: activeSnapshot.questionStartedAt!,
    );
  }

  @override
  Future<TestAttemptResultDto> submitTestAttempt({
    required String attemptId,
    required String idempotencyKey,
  }) async {
    _ensureOnline();
    _requireNonEmptyKey(idempotencyKey);

    const scope = 'submit_test_attempt';
    final fp = _fingerprint(<String, Object?>{'attempt_id': attemptId});
    final cached = _replayOrThrow<TestAttemptResultDto>(
      scope,
      idempotencyKey,
      fp,
    );
    if (cached != null) return cached;

    final attempt = _testAttempts[attemptId];
    if (attempt == null) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.notFound,
        statusCode: 404,
      );
    }
    if (attempt.status == AttemptStatus.submitted) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.alreadySubmitted,
        statusCode: 409,
      );
    }
    if (attempt.answers.length < attempt.snapshots.length) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.incompleteAnswers,
        statusCode: 409,
      );
    }

    final total = attempt.snapshots.length;
    final correctCount = attempt.answers.values
        .where((record) => record.isCorrect)
        .length;
    final score = (correctCount / total) * 100.0;
    final submittedAt = _clock().toUtc();
    final rawDuration = submittedAt.difference(attempt.startedAt).inSeconds;
    final totalDuration = rawDuration < 0 ? 0 : rawDuration;

    final items = attempt.snapshots.map((snapshot) {
      final answer = attempt.answers[snapshot.sequence]!;
      return TestResultItemDto(
        sequence: snapshot.sequence,
        questionText: snapshot.questionText,
        questionType: snapshot.questionType,
        isCorrect: answer.isCorrect,
        timeSpentSeconds: answer.timeSpentSeconds,
      );
    }).toList();

    final result = TestAttemptResultDto(
      attemptId: attempt.attemptId,
      testId: attempt.test.testId,
      testType: attempt.test.testType,
      status: AttemptStatus.submitted,
      score: score,
      totalDurationSeconds: totalDuration,
      startedAt: attempt.startedAt,
      submittedAt: submittedAt,
      items: List<TestResultItemDto>.unmodifiable(items),
    );

    attempt.status = AttemptStatus.submitted;
    attempt.score = score;
    attempt.submittedAt = submittedAt;
    attempt.result = result;

    if (attempt.test.testType == TestType.pre && _profile != null) {
      _profile = _profile!.copyWith(preTestSubmitted: true);
    }

    _saveIdempotency(scope, idempotencyKey, fp, result);
    return result;
  }

  @override
  Future<TestAttemptResultDto> getTestAttemptResult(String attemptId) async {
    _ensureOnline();
    final attempt = _testAttempts[attemptId];
    if (attempt == null) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.notFound,
        statusCode: 404,
      );
    }
    if (attempt.status != AttemptStatus.submitted || attempt.result == null) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.invalidStateTransition,
        statusCode: 409,
      );
    }
    return attempt.result!;
  }

  // 4.5 AI Learning Assistant

  @override
  Future<AiQuotaDto> getAiQuota() async {
    _ensureOnline();
    _refreshQuotaWindow();
    return AiQuotaDto(
      remainingQuota: _remainingAiQuota,
      dailyLimit: dailyAiQuotaLimit,
      usageDate: _quotaUsageDate,
    );
  }

  @override
  Future<AiAskResponseDto> askAi({
    required AiAskRequestDto request,
    required String requestId,
  }) async {
    _ensureOnline();
    _refreshQuotaWindow();

    if (request.question.trim().isEmpty || requestId.trim().isEmpty) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.validationError,
        statusCode: 400,
      );
    }

    final fp = _fingerprint(request.toJson());
    final existing = _aiIdempotencyStore[requestId];
    if (existing != null) {
      if (existing.fingerprint != fp) {
        throw PlasApiException.fromApiCode(
          ApiErrorCodes.idempotencyConflict,
          statusCode: 409,
        );
      }
      if (existing.succeeded) {
        return AiAskResponseDto(
          status: AiAskStatus.alreadyProcessed,
          answer: null,
          hintLevel: null,
          remainingQuota: _remainingAiQuota,
        );
      }
    }

    if (_remainingAiQuota <= 0) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.quotaExceeded,
        statusCode: 403,
      );
    }

    if (simulateAiFailure) {
      _aiIdempotencyStore[requestId] = _AiIdempotencyEntry(
        fingerprint: fp,
        succeeded: false,
      );
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.aiServiceError,
        statusCode: 502,
      );
    }

    _aiUsedToday++;
    _aiIdempotencyStore[requestId] = _AiIdempotencyEntry(
      fingerprint: fp,
      succeeded: true,
    );

    final reply = _buildSocraticAiReply(request);
    return AiAskResponseDto(
      status: AiAskStatus.success,
      answer: reply,
      hintLevel: request.hintLevel,
      remainingQuota: _remainingAiQuota,
    );
  }

  // 4.6 Progres & Aktivitas

  @override
  Future<ProgressSummaryDto> getProgress() async {
    _ensureOnline();
    _refreshQuotaWindow();

    final completed = _completedExerciseCount();
    final total = MockSeedData.materials.length;

    final preId = _testAttemptIdByTestId[MockSeedData.preTest.testId];
    final preAttempt = preId != null ? _testAttempts[preId] : null;
    final postId = _testAttemptIdByTestId[MockSeedData.postTest.testId];
    final postAttempt = postId != null ? _testAttempts[postId] : null;

    return ProgressSummaryDto(
      completedMaterials: completed,
      totalMaterials: total,
      completedExercises: completed,
      totalExercises: total,
      preTestStatus: _toOverviewStatus(preAttempt),
      preTestScore: preAttempt?.status == AttemptStatus.submitted
          ? preAttempt?.score
          : null,
      postTestStatus: _toOverviewStatus(postAttempt),
      postTestScore: postAttempt?.status == AttemptStatus.submitted
          ? postAttempt?.score
          : null,
      isPostTestEligible: completed == total,
      aiQuota: AiQuotaDto(
        remainingQuota: _remainingAiQuota,
        dailyLimit: dailyAiQuotaLimit,
        usageDate: _quotaUsageDate,
      ),
    );
  }

  @override
  Future<List<ActivityItemDto>> getActivities() async {
    _ensureOnline();
    final items = _exerciseAttempts.values.toList()
      ..sort((a, b) {
        final cmp = b.startedAt.compareTo(a.startedAt);
        if (cmp != 0) return cmp;
        return b.attemptId.compareTo(a.attemptId);
      });

    return List<ActivityItemDto>.unmodifiable(
      items.map(
        (attempt) => ActivityItemDto(
          attemptId: attempt.attemptId,
          exerciseId: attempt.material.exerciseId,
          materialTitle: attempt.material.title,
          submaterialTitle: attempt.material.submaterialTitle,
          questionType: attempt.material.questionType,
          attemptNumber: attempt.attemptNumber,
          status: attempt.status,
          score: attempt.score,
          createdAt: attempt.startedAt,
          submittedAt: attempt.submittedAt,
        ),
      ),
    );
  }

  // Offline Sync Replay

  @override
  Future<void> replayPendingSyncItem(PendingSyncItem item) async {
    _ensureOnline();
    if (item.method.toUpperCase() != 'POST') {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.validationError,
        statusCode: 400,
        serverMessage: 'Unsupported sync method: ${item.method}',
      );
    }

    final path =
        item.path.startsWith('/api/') ? item.path.substring(4) : item.path;

    final exAnsMatch = _exerciseAnswerPathPattern.firstMatch(path);
    if (exAnsMatch != null) {
      final attemptId = exAnsMatch.group(1)!;
      final attempt = _exerciseAttempts[attemptId];
      if (attempt == null) {
        throw PlasApiException.fromApiCode(
          ApiErrorCodes.notFound,
          statusCode: 404,
        );
      }
      final questionId = item.body['question_id'];
      if (questionId is! String || questionId.trim().isEmpty) {
        throw PlasApiException.fromApiCode(
          ApiErrorCodes.validationError,
          statusCode: 400,
        );
      }
      final seedQuestion = attempt.findQuestion(questionId);
      if (seedQuestion == null) {
        throw PlasApiException.fromApiCode(
          ApiErrorCodes.notFound,
          statusCode: 404,
        );
      }
      final rawAnswer = item.body['answer'];
      if (rawAnswer is! Map) {
        throw PlasApiException.fromApiCode(
          ApiErrorCodes.invalidAnswer,
          statusCode: 422,
        );
      }
      final answer = StudentAnswer.fromJson(
        seedQuestion.questionType,
        Map<String, dynamic>.from(rawAnswer),
      );
      final rawTimeSpent = item.body['time_spent_seconds'];
      final timeSpentSeconds = rawTimeSpent is num ? rawTimeSpent.toInt() : 0;

      await submitExerciseAnswer(
        attemptId: attemptId,
        questionId: questionId,
        answer: answer,
        timeSpentSeconds: timeSpentSeconds,
        submissionRequestId: item.idempotencyKey,
      );
      return;
    }

    final exSubmitMatch = _exerciseSubmitPathPattern.firstMatch(path);
    if (exSubmitMatch != null) {
      final attemptId = exSubmitMatch.group(1)!;
      await submitExerciseAttempt(
        attemptId: attemptId,
        idempotencyKey: item.idempotencyKey,
      );
      return;
    }

    final testAnsMatch = _testAnswerPathPattern.firstMatch(path);
    if (testAnsMatch != null) {
      final attemptId = testAnsMatch.group(1)!;
      final sequence = int.parse(testAnsMatch.group(2)!);
      final attempt = _testAttempts[attemptId];
      if (attempt == null) {
        throw PlasApiException.fromApiCode(
          ApiErrorCodes.notFound,
          statusCode: 404,
        );
      }
      if (sequence < 1 || sequence > attempt.snapshots.length) {
        throw PlasApiException.fromApiCode(
          ApiErrorCodes.validationError,
          statusCode: 400,
        );
      }
      final snapshot = attempt.snapshots[sequence - 1];
      final rawAnswer = item.body['answer'];
      if (rawAnswer is! Map) {
        throw PlasApiException.fromApiCode(
          ApiErrorCodes.invalidAnswer,
          statusCode: 422,
        );
      }
      final answer = StudentAnswer.fromJson(
        snapshot.questionType,
        Map<String, dynamic>.from(rawAnswer),
      );

      await submitTestAnswer(
        attemptId: attemptId,
        sequence: sequence,
        answer: answer,
        submissionRequestId: item.idempotencyKey,
      );
      return;
    }

    final testSubmitMatch = _testSubmitPathPattern.firstMatch(path);
    if (testSubmitMatch != null) {
      final attemptId = testSubmitMatch.group(1)!;
      await submitTestAttempt(
        attemptId: attemptId,
        idempotencyKey: item.idempotencyKey,
      );
      return;
    }

    throw PlasApiException.fromApiCode(
      ApiErrorCodes.validationError,
      statusCode: 400,
      serverMessage: 'Unsupported sync path: $path',
    );
  }

  // Helpers

  List<_ExerciseAttemptState> _attemptsForExercise(String exerciseId) {
    final ids = _exerciseAttemptIdsByExercise[exerciseId] ?? const <String>[];
    return ids.map((id) => _exerciseAttempts[id]!).toList(growable: false);
  }

  bool _hasSubmittedExercise(String exerciseId) {
    return _attemptsForExercise(exerciseId)
        .any((attempt) => attempt.status == AttemptStatus.submitted);
  }

  int _completedExerciseCount() {
    var count = 0;
    for (final material in MockSeedData.materials) {
      if (_hasSubmittedExercise(material.exerciseId)) {
        count++;
      }
    }
    return count;
  }

  TestOverviewItemDto _buildTestOverview(
    MockSeedTest seedTest, {
    required bool isEligible,
    required int completedExercises,
    required int totalExercises,
  }) {
    final attemptId = _testAttemptIdByTestId[seedTest.testId];
    final attempt = attemptId != null ? _testAttempts[attemptId] : null;
    return TestOverviewItemDto(
      testId: seedTest.testId,
      testType: seedTest.testType,
      title: seedTest.title,
      questionCount: seedTest.questions.length,
      status: _toOverviewStatus(attempt),
      activeAttemptId: attempt?.attemptId,
      score: attempt?.status == AttemptStatus.submitted ? attempt?.score : null,
      isEligible: isEligible,
      completedExercises: completedExercises,
      totalExercises: totalExercises,
    );
  }

  TestOverviewStatus _toOverviewStatus(_TestAttemptState? attempt) {
    if (attempt == null) return TestOverviewStatus.notStarted;
    return attempt.status == AttemptStatus.submitted
        ? TestOverviewStatus.submitted
        : TestOverviewStatus.inProgress;
  }

  void _requireNonEmptyKey(String key) {
    if (key.trim().isEmpty) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.validationError,
        statusCode: 400,
      );
    }
  }

  T? _replayOrThrow<T>(String scope, String key, String fingerprint) {
    final entry = _idempotencyStore[(scope, key)];
    if (entry == null) return null;
    if (entry.fingerprint != fingerprint) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.idempotencyConflict,
        statusCode: 409,
      );
    }
    return entry.response as T;
  }

  void _saveIdempotency(
    String scope,
    String key,
    String fingerprint,
    Object response,
  ) {
    _idempotencyStore[(scope, key)] = _IdempotencyEntry(
      fingerprint: fingerprint,
      response: response,
    );
  }

  String _fingerprint(Map<String, Object?> payload) {
    return jsonEncode(_canonicalJson(payload));
  }

  Object? _canonicalJson(Object? value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return <String, Object?>{
        for (final entry in entries)
          entry.key.toString(): _canonicalJson(entry.value),
      };
    }
    if (value is List) {
      return value.map(_canonicalJson).toList();
    }
    return value;
  }

  bool _evaluateExerciseAnswer(
    MockSeedExerciseQuestion question,
    StudentAnswer answer,
  ) {
    return _evaluateAnswer(
      type: question.questionType,
      options: question.options,
      correctOptionId: question.correctOptionId,
      correctBoolean: question.correctBoolean,
      correctText: question.correctText,
      answer: answer,
    );
  }

  bool _evaluateTestSnapshotAnswer(
    _TestQuestionSnapshot snapshot,
    StudentAnswer answer,
  ) {
    return _evaluateAnswer(
      type: snapshot.questionType,
      options: snapshot.options,
      correctOptionId: snapshot.correctOptionId,
      correctBoolean: snapshot.correctBoolean,
      correctText: snapshot.correctText,
      answer: answer,
    );
  }

  bool _evaluateAnswer({
    required QuestionType type,
    required List<QuestionOptionDto> options,
    required String? correctOptionId,
    required bool? correctBoolean,
    required String? correctText,
    required StudentAnswer answer,
  }) {
    switch (type) {
      case QuestionType.mc:
        if (answer is! McAnswer) {
          throw PlasApiException.fromApiCode(
            ApiErrorCodes.typeMismatch,
            statusCode: 422,
          );
        }
        final optionExists = options.any((o) => o.optionId == answer.optionId);
        if (!optionExists) {
          throw PlasApiException.fromApiCode(
            ApiErrorCodes.invalidOption,
            statusCode: 422,
          );
        }
        return answer.optionId == correctOptionId;

      case QuestionType.tf:
        if (answer is! TfAnswer) {
          throw PlasApiException.fromApiCode(
            ApiErrorCodes.typeMismatch,
            statusCode: 422,
          );
        }
        return answer.value == correctBoolean;

      case QuestionType.fib:
        if (answer is! FibAnswer) {
          throw PlasApiException.fromApiCode(
            ApiErrorCodes.typeMismatch,
            statusCode: 422,
          );
        }
        return evaluateFibAnswer(answer.value, correctText ?? '');
    }
  }

  void _enforceLinearSequence(_TestAttemptState attempt, int sequence) {
    if (attempt.answers.containsKey(sequence) ||
        sequence < attempt.currentSequence) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.alreadyAnswered,
        statusCode: 409,
      );
    }
    if (sequence > attempt.currentSequence) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.wrongSequence,
        statusCode: 409,
      );
    }
  }

  List<QuestionOptionDto> _shuffleOptionsOnce(
    List<QuestionOptionDto> options,
    int seed,
  ) {
    final copy = List<QuestionOptionDto>.of(options);
    copy.shuffle(Random(seed));
    return List<QuestionOptionDto>.unmodifiable(
      <QuestionOptionDto>[
        for (var i = 0; i < copy.length; i++)
          QuestionOptionDto(
            optionId: copy[i].optionId,
            text: copy[i].text,
            sequence: i + 1,
          ),
      ],
    );
  }

  String _buildSocraticAiReply(AiAskRequestDto request) {
    final material = request.submaterialId != null
        ? MockSeedData.findBySubmaterialId(request.submaterialId!)
        : null;
    final question = request.exerciseQuestionId != null
        ? MockSeedData.findExerciseQuestion(request.exerciseQuestionId!)
        : null;

    final topic = material?.title ?? 'dasar pemrograman TypeScript';
    final contextHint = question?.hint;

    switch (request.hintLevel) {
      case AiHintLevel.konsepDasar:
        final extra = contextHint != null
            ? ' Petunjuk awal: $contextHint'
            : '';
        return '[Level 1: Konsep Dasar] Pada topik $topic, tinjau kembali aturan tipe dan peran sintaks utama yang dibahas pada materi.$extra Menurut Anda, konsep mana yang paling relevan dengan pertanyaan Anda?';
      case AiHintLevel.strategi:
        return '[Level 2: Strategi] Untuk menyelesaikan soal pada topik $topic, uraikan dulu tipe input yang diminta dan periksa apakah deklarasi atau operatornya konsisten. Langkah apa yang dapat Anda uji lebih dulu pada contoh kode singkat?';
      case AiHintLevel.penalaran:
        return '[Level 3: Penalaran] Coba telusuri alur eksekusi serta pemeriksaan tipe TypeScript baris demi baris terkait pertanyaan Anda. Jika nilai atau tipe pada contoh diubah, dampak apa yang akan ditolak oleh kompiler tsc?';
    }
  }
}

class _ExerciseAnswerRecord {
  const _ExerciseAnswerRecord({
    required this.studentAnswer,
    required this.isCorrect,
    required this.timeSpentSeconds,
    required this.answeredAt,
  });

  final StudentAnswer studentAnswer;
  final bool isCorrect;
  final int timeSpentSeconds;
  final DateTime answeredAt;
}

class _ExerciseAttemptState {
  _ExerciseAttemptState({
    required this.attemptId,
    required this.material,
    required this.attemptNumber,
    required this.startedAt,
  });

  final String attemptId;
  final MockSeedMaterial material;
  final int attemptNumber;
  final DateTime startedAt;
  AttemptStatus status = AttemptStatus.inProgress;
  double? score;
  DateTime? submittedAt;
  final Map<String, _ExerciseAnswerRecord> answers =
      <String, _ExerciseAnswerRecord>{};

  MockSeedExerciseQuestion? findQuestion(String questionId) {
    for (final q in material.questions) {
      if (q.questionId == questionId) return q;
    }
    return null;
  }

  ExerciseAttemptDto toAttemptDto() {
    return ExerciseAttemptDto(
      attemptId: attemptId,
      exerciseId: material.exerciseId,
      attemptNumber: attemptNumber,
      status: status,
      score: score,
      startedAt: startedAt,
      submittedAt: submittedAt,
      questions: List<ExerciseQuestionDto>.unmodifiable(
        material.questions.map((q) => q.toExerciseQuestionDto()),
      ),
    );
  }
}

class _TestQuestionSnapshot {
  _TestQuestionSnapshot({
    required this.questionId,
    required this.sequence,
    required this.questionText,
    required this.questionType,
    required this.options,
    required this.correctOptionId,
    required this.correctBoolean,
    required this.correctText,
  });

  final String questionId;
  final int sequence;
  final String questionText;
  final QuestionType questionType;
  final List<QuestionOptionDto> options;
  final String? correctOptionId;
  final bool? correctBoolean;
  final String? correctText;
  DateTime? questionStartedAt;
}

class _TestAnswerRecord {
  const _TestAnswerRecord({
    required this.studentAnswer,
    required this.isCorrect,
    required this.timeSpentSeconds,
    required this.answeredAt,
  });

  final StudentAnswer studentAnswer;
  final bool isCorrect;
  final int timeSpentSeconds;
  final DateTime answeredAt;
}

class _TestAttemptState {
  _TestAttemptState({
    required this.attemptId,
    required this.test,
    required this.startedAt,
    required this.snapshots,
  });

  final String attemptId;
  final MockSeedTest test;
  final DateTime startedAt;
  final List<_TestQuestionSnapshot> snapshots;
  AttemptStatus status = AttemptStatus.inProgress;
  int currentSequence = 1;
  double? score;
  DateTime? submittedAt;
  TestAttemptResultDto? result;
  final Map<int, _TestAnswerRecord> answers = <int, _TestAnswerRecord>{};
}

class _IdempotencyEntry {
  const _IdempotencyEntry({
    required this.fingerprint,
    required this.response,
  });

  final String fingerprint;
  final Object response;
}

class _AiIdempotencyEntry {
  const _AiIdempotencyEntry({
    required this.fingerprint,
    required this.succeeded,
  });

  final String fingerprint;
  final bool succeeded;
}
