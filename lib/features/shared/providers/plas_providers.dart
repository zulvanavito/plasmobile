import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/sync/pending_sync_queue.dart';
import 'package:plasmobile/data/dto/ai_dto.dart';
import 'package:plasmobile/data/dto/exercise_dto.dart';
import 'package:plasmobile/data/dto/material_dto.dart';
import 'package:plasmobile/data/dto/progress_dto.dart';
import 'package:plasmobile/data/dto/student_profile_dto.dart';
import 'package:plasmobile/data/dto/test_dto.dart';
import 'package:plasmobile/data/repositories/plas_repository.dart';

final classesProvider = FutureProvider.autoDispose<List<ClassInfoDto>>((ref) {
  return ref.watch(plasRepositoryProvider).getClasses();
});

final materialsProvider = FutureProvider.autoDispose<List<MaterialSummaryDto>>((
  ref,
) {
  return ref.watch(plasRepositoryProvider).getMaterials();
});

final progressSummaryProvider = FutureProvider.autoDispose<ProgressSummaryDto>((
  ref,
) {
  return ref.watch(plasRepositoryProvider).getProgress();
});

final testsOverviewProvider = FutureProvider.autoDispose<TestsOverviewDto>((
  ref,
) {
  return ref.watch(plasRepositoryProvider).getTests();
});

final activitiesProvider = FutureProvider.autoDispose<List<ActivityItemDto>>((
  ref,
) {
  return ref.watch(plasRepositoryProvider).getActivities();
});

final aiQuotaProvider = FutureProvider.autoDispose<AiQuotaDto>((ref) {
  return ref.watch(plasRepositoryProvider).getAiQuota();
});

final materialDetailProvider = FutureProvider.autoDispose
    .family<MaterialDetailDto, String>((ref, materialId) {
  return ref.watch(plasRepositoryProvider).getMaterialDetail(materialId);
});

final subMaterialDetailProvider = FutureProvider.autoDispose
    .family<SubMaterialDetailDto, String>((ref, submaterialId) {
  return ref.watch(plasRepositoryProvider).getSubMaterial(submaterialId);
});

final exerciseDetailProvider = FutureProvider.autoDispose
    .family<ExerciseDetailDto, String>((ref, submaterialId) {
  return ref.watch(plasRepositoryProvider).getExercise(submaterialId);
});

final exerciseAttemptsProvider = FutureProvider.autoDispose
    .family<List<ExerciseAttemptDto>, String>((ref, exerciseId) {
  return ref.watch(plasRepositoryProvider).getExerciseAttempts(exerciseId);
});

final exerciseAttemptDetailProvider = FutureProvider.autoDispose
    .family<ExerciseAttemptDetailDto, String>((ref, attemptId) {
  return ref.watch(plasRepositoryProvider).getExerciseAttemptDetail(attemptId);
});

final testAttemptResultProvider = FutureProvider.autoDispose
    .family<TestAttemptResultDto, String>((ref, attemptId) {
  return ref.watch(plasRepositoryProvider).getTestAttemptResult(attemptId);
});

final isSyncingPendingProvider = StateProvider<bool>((ref) => false);

void invalidateLearningDataWith(void Function(ProviderOrFamily) invalidate) {
  invalidate(materialsProvider);
  invalidate(progressSummaryProvider);
  invalidate(testsOverviewProvider);
  invalidate(activitiesProvider);
  invalidate(aiQuotaProvider);
  invalidate(materialDetailProvider);
  invalidate(subMaterialDetailProvider);
  invalidate(exerciseDetailProvider);
  invalidate(exerciseAttemptsProvider);
  invalidate(exerciseAttemptDetailProvider);
  invalidate(testAttemptResultProvider);
}

void invalidateLearningData(WidgetRef ref) {
  invalidateLearningDataWith(ref.invalidate);
}

void invalidateLearningDataRef(Ref ref) {
  invalidateLearningDataWith(ref.invalidate);
}

Future<void> retryPendingSyncQueue(WidgetRef ref) async {
  if (ref.read(isSyncingPendingProvider)) return;
  final initialCount = ref.read(pendingSyncProvider).length;
  if (initialCount == 0) return;

  final repository = ref.read(plasRepositoryProvider);
  final pendingNotifier = ref.read(pendingSyncProvider.notifier);
  final syncingState = ref.read(isSyncingPendingProvider.notifier);

  syncingState.state = true;
  var succeededCount = 0;

  try {
    await pendingNotifier.retryAll((item) async {
      await repository.replayPendingSyncItem(item);
      succeededCount++;
    });
  } on PlasApiException catch (error) {
    if (!error.isRetryable) {
      rethrow;
    }
  } finally {
    syncingState.state = false;
    if (ref.context.mounted) {
      final remainingCount = ref.read(pendingSyncProvider).length;
      if (succeededCount > 0 || remainingCount != initialCount) {
        invalidateLearningData(ref);
      }
    }
  }
}
