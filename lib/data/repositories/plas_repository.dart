import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plasmobile/core/config/app_env.dart';
import 'package:plasmobile/core/network/dio_client.dart';
import 'package:plasmobile/core/sync/pending_sync_queue.dart';
import 'package:plasmobile/data/dto/ai_dto.dart';
import 'package:plasmobile/data/dto/exercise_dto.dart';
import 'package:plasmobile/data/dto/material_dto.dart';
import 'package:plasmobile/data/dto/progress_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/data/dto/student_profile_dto.dart';
import 'package:plasmobile/data/dto/test_dto.dart';
import 'package:plasmobile/data/repositories/api_plas_repository.dart';
import 'package:plasmobile/data/repositories/mock_plas_repository.dart';

/// Unified student mobile data boundary covering the 24 PLAS REST endpoints
/// (API Spec 4.1-4.6) plus offline sync replay.
abstract interface class PlasRepository {
  // 4.1 Profil, Onboarding, & Kelas
  Future<StudentProfileDto> getMe();
  Future<StudentProfileDto> createProfile(CreateProfileRequest request);
  Future<List<ClassInfoDto>> getClasses();
  Future<StudentProfileDto> updateClass(String? kelasId);

  // 4.2 Materi
  Future<List<MaterialSummaryDto>> getMaterials();
  Future<MaterialDetailDto> getMaterialDetail(String materialId);
  Future<SubMaterialDetailDto> getSubMaterial(String submaterialId);

  // 4.3 Exercise
  Future<ExerciseDetailDto> getExercise(String submaterialId);
  Future<ExerciseAttemptDto> createExerciseAttempt({
    required String exerciseId,
    required String creationRequestId,
  });
  Future<ExerciseAnswerResponseDto> submitExerciseAnswer({
    required String attemptId,
    required String questionId,
    required StudentAnswer answer,
    required int timeSpentSeconds,
    required String submissionRequestId,
  });
  Future<ExerciseAttemptDto> submitExerciseAttempt({
    required String attemptId,
    required String idempotencyKey,
  });
  Future<List<ExerciseAttemptDto>> getExerciseAttempts(String exerciseId);
  Future<ExerciseAttemptDetailDto> getExerciseAttemptDetail(String attemptId);

  // 4.4 Pre-Test / Post-Test
  Future<TestsOverviewDto> getTests();
  Future<TestAttemptStartDto> createTestAttempt({
    required String testId,
    required String creationRequestId,
  });
  Future<TestActiveQuestionDto> startTestQuestion({
    required String attemptId,
    required int sequence,
    String? idempotencyKey,
  });
  Future<TestAnswerAckDto> submitTestAnswer({
    required String attemptId,
    required int sequence,
    required StudentAnswer answer,
    required String submissionRequestId,
  });
  Future<TestActiveQuestionDto> resumeTestAttempt(String attemptId);
  Future<TestAttemptResultDto> submitTestAttempt({
    required String attemptId,
    required String idempotencyKey,
  });
  Future<TestAttemptResultDto> getTestAttemptResult(String attemptId);

  // 4.5 AI Learning Assistant
  Future<AiQuotaDto> getAiQuota();
  Future<AiAskResponseDto> askAi({
    required AiAskRequestDto request,
    required String requestId,
  });

  // 4.6 Progres & Aktivitas
  Future<ProgressSummaryDto> getProgress();
  Future<List<ActivityItemDto>> getActivities();

  // Offline Sync Replay
  Future<void> replayPendingSyncItem(PendingSyncItem item);
}

final plasRepositoryProvider = Provider<PlasRepository>((ref) {
  if (AppEnv.useMock) {
    return MockPlasRepository();
  }
  return ApiPlasRepository(dio: ref.watch(dioProvider));
});
