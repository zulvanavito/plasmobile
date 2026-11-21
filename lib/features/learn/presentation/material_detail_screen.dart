import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/router/app_routes.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/core/utils/wita_clock.dart';
import 'package:plasmobile/data/dto/exercise_dto.dart';
import 'package:plasmobile/data/dto/material_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/features/shared/providers/plas_providers.dart';
import 'package:plasmobile/shared/widgets/plas_state_views.dart';
import 'package:plasmobile/shared/widgets/plas_status_badge.dart';

class MaterialDetailScreen extends ConsumerWidget {
  const MaterialDetailScreen({
    super.key,
    required this.materialId,
  });

  final String materialId;

  Future<void> _handleRefresh(WidgetRef ref) async {
    final currentDetail = ref.read(materialDetailProvider(materialId)).valueOrNull;
    ref.invalidate(materialDetailProvider(materialId));
    if (currentDetail != null) {
      for (final sub in currentDetail.submaterials) {
        final subDetail =
            ref.read(subMaterialDetailProvider(sub.submaterialId)).valueOrNull;
        ref.invalidate(subMaterialDetailProvider(sub.submaterialId));
        if (subDetail != null) {
          ref.invalidate(exerciseAttemptsProvider(subDetail.exercise.exerciseId));
        }
      }
    }
    try {
      await ref.read(materialDetailProvider(materialId).future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(materialDetailProvider(materialId));
    final appBarTitle = detailAsync.valueOrNull?.title ?? 'Detail Materi';

    return Scaffold(
      backgroundColor: PlasColors.bgCanvas,
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('material_detail_back_button'),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          tooltip: 'Kembali',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.learn);
            }
          },
          icon: const Icon(Symbols.arrow_back, size: 22),
        ),
        title: Text(
          appBarTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: PlasColors.brandPrimary,
          onRefresh: () => _handleRefresh(ref),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(PlasSpacing.space4),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: detailAsync.when(
                  loading: () => const PlasLoadingSkeleton(
                    message: 'Memuat detail materi dan daftar latihan...',
                    cardCount: 3,
                  ),
                  error: (error, _) => PlasErrorView(
                    title: 'Gagal Memuat Detail Materi',
                    message: _errorMessage(error),
                    onRetry: () =>
                        ref.invalidate(materialDetailProvider(materialId)),
                  ),
                  data: (detail) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MaterialHeaderCard(detail: detail),
                      const SizedBox(height: PlasSpacing.space5),
                      const Text(
                        'SubMateri & Latihan',
                        style: PlasTypography.heading,
                      ),
                      const SizedBox(height: PlasSpacing.space3),
                      if (detail.submaterials.isEmpty)
                        PlasEmptyView(
                          title: 'Belum Ada SubMateri',
                          description:
                              'SubMateri pada modul ini belum tersedia saat ini.',
                          actionLabel: 'Kembali ke Daftar Materi',
                          onAction: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(AppRoutes.learn);
                            }
                          },
                        )
                      else
                        for (var i = 0; i < detail.submaterials.length; i++) ...[
                          if (i > 0) const SizedBox(height: PlasSpacing.space4),
                          _SubMaterialExerciseCard(
                            submaterial: detail.submaterials[i],
                          ),
                        ],
                      const SizedBox(height: PlasSpacing.space4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MaterialHeaderCard extends StatelessWidget {
  const _MaterialHeaderCard({required this.detail});

  final MaterialDetailDto detail;

  @override
  Widget build(BuildContext context) {
    final codeTag = 'Materi ${detail.sequence.toString().padLeft(2, '0')}';

    return Container(
      key: ValueKey('material_header_${detail.materialId}'),
      padding: const EdgeInsets.all(PlasSpacing.space5),
      decoration: BoxDecoration(
        color: PlasColors.bgSurface,
        borderRadius: BorderRadius.circular(PlasRadii.lg),
        border: Border.all(color: PlasColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: PlasSpacing.space2,
            runSpacing: PlasSpacing.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(codeTag, style: PlasTypography.codeMeta),
              PlasStatusBadge(
                label: '${detail.submaterials.length} SubMateri',
                variant: PlasBadgeVariant.brand,
                icon: Symbols.menu_book,
              ),
            ],
          ),
          const SizedBox(height: PlasSpacing.space2),
          Text(detail.title, style: PlasTypography.display),
          const SizedBox(height: PlasSpacing.space2),
          Text(detail.description, style: PlasTypography.body),
        ],
      ),
    );
  }
}

class _SubMaterialExerciseCard extends ConsumerWidget {
  const _SubMaterialExerciseCard({required this.submaterial});

  final SubMaterialSummaryDto submaterial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subDetailAsync =
        ref.watch(subMaterialDetailProvider(submaterial.submaterialId));

    final PlasStatusBadge subStatusBadge;
    if (submaterial.hasSubmittedExercise) {
      subStatusBadge = const PlasStatusBadge(
        label: 'Latihan Selesai',
        variant: PlasBadgeVariant.success,
        icon: Symbols.check_circle,
      );
    } else if (submaterial.attemptsUsed > 0) {
      subStatusBadge = const PlasStatusBadge(
        label: 'Sedang Berjalan',
        variant: PlasBadgeVariant.warning,
        icon: Symbols.schedule,
      );
    } else {
      subStatusBadge = const PlasStatusBadge(
        label: 'Belum Dikerjakan',
        variant: PlasBadgeVariant.neutral,
        icon: Symbols.schedule,
      );
    }

    return Container(
      key: ValueKey('submaterial_card_${submaterial.submaterialId}'),
      padding: const EdgeInsets.all(PlasSpacing.space4),
      decoration: BoxDecoration(
        color: PlasColors.bgSurface,
        borderRadius: BorderRadius.circular(PlasRadii.lg),
        border: Border.all(color: PlasColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: PlasSpacing.space2,
            runSpacing: PlasSpacing.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'SubMateri ${submaterial.sequence.toString().padLeft(2, '0')}',
                style: PlasTypography.codeMeta,
              ),
              subStatusBadge,
            ],
          ),
          const SizedBox(height: PlasSpacing.space2),
          Text(submaterial.title, style: PlasTypography.heading),
          const SizedBox(height: PlasSpacing.space3),
          OutlinedButton(
            key: ValueKey('read_submaterial_${submaterial.submaterialId}'),
            onPressed: () => context.push(
              AppRoutes.subMaterialRead(submaterial.submaterialId),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Symbols.menu_book, size: 20),
                SizedBox(width: PlasSpacing.space2),
                Flexible(
                  child: Text('Baca Materi', textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
          const SizedBox(height: PlasSpacing.space4),
          const Divider(height: 1, color: PlasColors.borderSubtle),
          const SizedBox(height: PlasSpacing.space4),
          subDetailAsync.when(
            loading: () => const PlasLoadingSkeleton(
              message: 'Memuat informasi latihan...',
              cardCount: 1,
            ),
            error: (error, _) => PlasErrorView(
              title: 'Gagal Memuat Latihan',
              message: _errorMessage(error),
              onRetry: () => ref.invalidate(
                subMaterialDetailProvider(submaterial.submaterialId),
              ),
            ),
            data: (subDetail) => _ExerciseAndAttemptsSection(
              submaterialId: submaterial.submaterialId,
              exercise: subDetail.exercise,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseAndAttemptsSection extends ConsumerWidget {
  const _ExerciseAndAttemptsSection({
    required this.submaterialId,
    required this.exercise,
  });

  final String submaterialId;
  final ExerciseOverviewDto exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attemptsAsync = ref.watch(exerciseAttemptsProvider(exercise.exerciseId));
    final isLimitReached = exercise.attemptsUsed >= exercise.maxAttempts &&
        exercise.latestAttemptStatus != AttemptStatus.inProgress;
    final isInProgress =
        exercise.latestAttemptStatus == AttemptStatus.inProgress;

    final String ctaLabel;
    final VoidCallback? ctaAction;
    if (isLimitReached) {
      ctaLabel = 'Buka Latihan';
      ctaAction = null;
    } else if (isInProgress) {
      ctaLabel = 'Lanjutkan Latihan ->';
      ctaAction = () => context.push(
            AppRoutes.exerciseSession(
              exercise.exerciseId,
              submaterialId: submaterialId,
            ),
          );
    } else {
      ctaLabel = 'Buka Latihan';
      ctaAction = () => context.push(
            AppRoutes.exerciseSession(
              exercise.exerciseId,
              submaterialId: submaterialId,
            ),
          );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(PlasSpacing.space4),
          decoration: BoxDecoration(
            color: PlasColors.bgSubtle,
            borderRadius: BorderRadius.circular(PlasRadii.md),
            border: Border.all(color: PlasColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(exercise.title, style: PlasTypography.title),
              const SizedBox(height: PlasSpacing.space2),
              Wrap(
                spacing: PlasSpacing.space2,
                runSpacing: PlasSpacing.space2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PlasStatusBadge(
                    label: exercise.questionType.apiValue,
                    variant: PlasBadgeVariant.brand,
                    icon: Symbols.quiz,
                  ),
                  PlasStatusBadge(
                    label:
                        'Attempt ${exercise.attemptsUsed}/${exercise.maxAttempts}',
                    variant: isLimitReached
                        ? PlasBadgeVariant.error
                        : PlasBadgeVariant.neutral,
                    icon: isLimitReached ? Symbols.lock : Symbols.history,
                  ),
                  if (exercise.bestScore != null)
                    PlasStatusBadge(
                      label: 'Skor Terbaik: ${_formatScore(exercise.bestScore!)}',
                      variant: PlasBadgeVariant.success,
                      icon: Symbols.check_circle,
                    ),
                ],
              ),
              if (isLimitReached) ...[
                const SizedBox(height: PlasSpacing.space3),
                Container(
                  key: ValueKey('attempt_limit_banner_${exercise.exerciseId}'),
                  padding: const EdgeInsets.all(PlasSpacing.space3),
                  decoration: BoxDecoration(
                    color: PlasColors.errorBg,
                    borderRadius: BorderRadius.circular(PlasRadii.md),
                    border: Border.all(color: PlasColors.errorBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Symbols.error,
                        size: 20,
                        color: PlasColors.errorText,
                      ),
                      const SizedBox(width: PlasSpacing.space2),
                      Expanded(
                        child: Text(
                          plasErrorMessage(ApiErrorCodes.attemptLimitReached),
                          style: PlasTypography.body.copyWith(
                            color: PlasColors.errorText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: PlasSpacing.space3),
              ElevatedButton(
                key: ValueKey('open_exercise_${exercise.exerciseId}'),
                onPressed: ctaAction,
                child: Text(ctaLabel, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
        const SizedBox(height: PlasSpacing.space4),
        const Text('Riwayat Attempt', style: PlasTypography.title),
        const SizedBox(height: PlasSpacing.space2),
        attemptsAsync.when(
          loading: () => const PlasLoadingSkeleton(
            message: 'Memuat riwayat attempt...',
            cardCount: 1,
          ),
          error: (error, _) => PlasErrorView(
            title: 'Gagal Memuat Riwayat Attempt',
            message: _errorMessage(error),
            onRetry: () => ref.invalidate(
              exerciseAttemptsProvider(exercise.exerciseId),
            ),
          ),
          data: (attempts) {
            if (attempts.isEmpty) {
              return const PlasEmptyView(
                title: 'Belum Ada Riwayat Latihan',
                description:
                    'Belum ada riwayat latihan pada SubMateri ini. Buka latihan untuk memulai percobaan pertama Anda.',
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < attempts.length; i++) ...[
                  if (i > 0) const SizedBox(height: PlasSpacing.space2),
                  _AttemptHistoryRow(
                    attempt: attempts[i],
                    maxAttempts: exercise.maxAttempts,
                    onTap: () {
                      final attempt = attempts[i];
                      if (attempt.status == AttemptStatus.submitted) {
                        context.push(
                          AppRoutes.exerciseReview(attempt.attemptId),
                        );
                      } else {
                        context.push(
                          AppRoutes.exerciseSession(
                            exercise.exerciseId,
                            submaterialId: submaterialId,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AttemptHistoryRow extends StatelessWidget {
  const _AttemptHistoryRow({
    required this.attempt,
    required this.maxAttempts,
    required this.onTap,
  });

  final ExerciseAttemptDto attempt;
  final int maxAttempts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSubmitted = attempt.status == AttemptStatus.submitted;
    final statusBadge = isSubmitted
        ? const PlasStatusBadge(
            label: 'SUBMITTED',
            variant: PlasBadgeVariant.success,
            icon: Symbols.check_circle,
          )
        : const PlasStatusBadge(
            label: 'IN_PROGRESS',
            variant: PlasBadgeVariant.warning,
            icon: Symbols.schedule,
          );

    final durationText = attempt.submittedAt != null
        ? 'Durasi: ${_formatDuration(attempt.submittedAt!.difference(attempt.startedAt))}'
        : 'Mulai ${_formatWitaTime(attempt.startedAt)} WITA';

    return Material(
      key: ValueKey('attempt_history_${attempt.attemptId}'),
      color: PlasColors.bgSurface,
      borderRadius: BorderRadius.circular(PlasRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(PlasRadii.md),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            padding: const EdgeInsets.all(PlasSpacing.space3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PlasRadii.md),
              border: Border.all(color: PlasColors.borderDivider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: PlasSpacing.space2,
                        runSpacing: PlasSpacing.space1,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Attempt ${attempt.attemptNumber}/$maxAttempts',
                            style: PlasTypography.label,
                          ),
                          statusBadge,
                        ],
                      ),
                      const SizedBox(height: PlasSpacing.space2),
                      Wrap(
                        spacing: PlasSpacing.space3,
                        runSpacing: PlasSpacing.space1,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (isSubmitted && attempt.score != null)
                            Text(
                              'Skor: ${_formatScore(attempt.score!)}',
                              style: PlasTypography.caption.copyWith(
                                color: PlasColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          Text(
                            durationText,
                            style: PlasTypography.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: PlasSpacing.space2),
                const Icon(
                  Symbols.chevron_right,
                  size: 20,
                  color: PlasColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatScore(double score) {
  if (score == score.roundToDouble()) {
    return score.round().toString();
  }
  return score.toStringAsFixed(1);
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  if (minutes == 0) {
    return '$seconds detik';
  }
  if (seconds == 0) {
    return '$minutes menit';
  }
  return '${minutes}m ${seconds}d';
}

String _formatWitaTime(DateTime utcOrLocal) {
  final wita = utcOrLocal.toUtc().add(kWitaOffset);
  final hh = wita.hour.toString().padLeft(2, '0');
  final mm = wita.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String _errorMessage(Object error) {
  if (error is PlasApiException) {
    return error.message;
  }
  return plasErrorMessage(ApiErrorCodes.serverError, fallback: error.toString());
}
