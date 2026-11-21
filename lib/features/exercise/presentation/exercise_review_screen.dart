import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/router/app_routes.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/data/dto/exercise_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/features/shared/providers/plas_providers.dart';
import 'package:plasmobile/shared/widgets/plas_accuracy_ring.dart';
import 'package:plasmobile/shared/widgets/plas_markdown_view.dart';
import 'package:plasmobile/shared/widgets/plas_state_views.dart';
import 'package:plasmobile/shared/widgets/plas_status_badge.dart';

class ExerciseReviewScreen extends ConsumerWidget {
  const ExerciseReviewScreen({
    super.key,
    required this.attemptId,
  });

  final String attemptId;

  Future<void> _handleRefresh(WidgetRef ref) async {
    ref.invalidate(exerciseAttemptDetailProvider(attemptId));
    try {
      await ref.read(exerciseAttemptDetailProvider(attemptId).future);
    } catch (_) {}
  }

  void _navigateBackToMaterial(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.learn);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(exerciseAttemptDetailProvider(attemptId));
    final title = detailAsync.valueOrNull?.exerciseTitle ?? 'Review Latihan';

    return Scaffold(
      backgroundColor: PlasColors.bgCanvas,
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('review_back_button'),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          tooltip: 'Kembali',
          onPressed: () => _navigateBackToMaterial(context),
          icon: const Icon(Symbols.arrow_back, size: 22),
        ),
        title: Text(
          title,
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
                    message: 'Memuat ringkasan dan pembahasan latihan...',
                    cardCount: 3,
                  ),
                  error: (error, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PlasErrorView(
                        title: 'Gagal Memuat Review Latihan',
                        message: _errorMessage(error),
                        onRetry: () => ref.invalidate(
                          exerciseAttemptDetailProvider(attemptId),
                        ),
                      ),
                      const SizedBox(height: PlasSpacing.space4),
                      OutlinedButton(
                        onPressed: () => _navigateBackToMaterial(context),
                        child: const Text(
                          'Kembali ke Materi',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  data: (detail) {
                    if (detail.status != AttemptStatus.submitted) {
                      return _InProgressGuardView(
                        detail: detail,
                        onBack: () => _navigateBackToMaterial(context),
                      );
                    }
                    return _SubmittedReviewContent(
                      detail: detail,
                      onBackToMaterial: () => _navigateBackToMaterial(context),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InProgressGuardView extends StatelessWidget {
  const _InProgressGuardView({
    required this.detail,
    required this.onBack,
  });

  final ExerciseAttemptDetailDto detail;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('review_in_progress_guard'),
          padding: const EdgeInsets.all(PlasSpacing.space5),
          decoration: BoxDecoration(
            color: PlasColors.warningBg,
            borderRadius: BorderRadius.circular(PlasRadii.lg),
            border: Border.all(color: PlasColors.warningBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: PlasSpacing.space2,
                runSpacing: PlasSpacing.space2,
                children: [
                  const PlasStatusBadge(
                    label: 'IN_PROGRESS',
                    variant: PlasBadgeVariant.warning,
                    icon: Symbols.schedule,
                  ),
                  PlasStatusBadge(
                    label: 'Attempt ${detail.attemptNumber}/3',
                    variant: PlasBadgeVariant.neutral,
                    icon: Symbols.history,
                  ),
                ],
              ),
              const SizedBox(height: PlasSpacing.space3),
              Text(
                'Latihan Belum Dikumpulkan',
                style: PlasTypography.heading.copyWith(
                  color: PlasColors.warningText,
                ),
              ),
              const SizedBox(height: PlasSpacing.space2),
              Text(
                'Pembahasan konsep dan hasil evaluasi hanya tersedia setelah seluruh soal diselesaikan dan attempt dikumpulkan.',
                style: PlasTypography.body.copyWith(
                  color: PlasColors.warningText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: PlasSpacing.space4),
        ElevatedButton(
          key: const ValueKey('review_resume_session_button'),
          onPressed: () => context.pushReplacement(
            AppRoutes.exerciseSession(detail.exerciseId),
          ),
          child: const Text(
            'Lanjutkan Latihan ->',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: PlasSpacing.space3),
        OutlinedButton(
          key: const ValueKey('review_guard_back_button'),
          onPressed: onBack,
          child: const Text(
            'Kembali ke Materi',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _SubmittedReviewContent extends StatelessWidget {
  const _SubmittedReviewContent({
    required this.detail,
    required this.onBackToMaterial,
  });

  final ExerciseAttemptDetailDto detail;
  final VoidCallback onBackToMaterial;

  @override
  Widget build(BuildContext context) {
    final sortedItems = List<ExerciseReviewItemDto>.from(detail.items)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    final totalCount = sortedItems.length;
    final correctCount =
        sortedItems.where((item) => item.isCorrect == true).length;
    final wrongCount = totalCount - correctCount;
    final accuracyPercentage = detail.score ??
        (totalCount > 0 ? (correctCount / totalCount) * 100.0 : 0.0);

    final sumItemSeconds = sortedItems.fold<int>(
      0,
      (sum, item) => sum + item.timeSpentSeconds,
    );
    final diffSeconds = detail.submittedAt != null
        ? detail.submittedAt!.difference(detail.startedAt).inSeconds
        : 0;
    final totalDurationSeconds = diffSeconds > 0 ? diffSeconds : sumItemSeconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReviewSummaryCard(
          detail: detail,
          accuracyPercentage: accuracyPercentage,
          correctCount: correctCount,
          wrongCount: wrongCount,
          totalDurationSeconds: totalDurationSeconds,
        ),
        const SizedBox(height: PlasSpacing.space5),
        const Text(
          'Rincian Jawaban & Pembahasan',
          style: PlasTypography.heading,
        ),
        const SizedBox(height: PlasSpacing.space3),
        if (sortedItems.isEmpty)
          const PlasEmptyView(
            title: 'Rincian Soal Kosong',
            description: 'Belum ada data butir soal untuk attempt ini.',
          )
        else
          for (var i = 0; i < sortedItems.length; i++) ...[
            if (i > 0) const SizedBox(height: PlasSpacing.space4),
            _ReviewQuestionCard(item: sortedItems[i]),
          ],
        const SizedBox(height: PlasSpacing.space5),
        ElevatedButton(
          key: const ValueKey('review_back_to_material_button'),
          onPressed: onBackToMaterial,
          child: const Text(
            'Kembali ke Materi',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: PlasSpacing.space4),
      ],
    );
  }
}

class _ReviewSummaryCard extends StatelessWidget {
  const _ReviewSummaryCard({
    required this.detail,
    required this.accuracyPercentage,
    required this.correctCount,
    required this.wrongCount,
    required this.totalDurationSeconds,
  });

  final ExerciseAttemptDetailDto detail;
  final double accuracyPercentage;
  final int correctCount;
  final int wrongCount;
  final int totalDurationSeconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('review_summary_card'),
      padding: const EdgeInsets.all(PlasSpacing.space5),
      decoration: BoxDecoration(
        color: PlasColors.bgSurface,
        borderRadius: BorderRadius.circular(PlasRadii.lg),
        border: Border.all(color: PlasColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: PlasAccuracyRing(
              percentage: accuracyPercentage,
              arcColor: PlasColors.successBorder,
              trackColor: PlasColors.borderSubtle,
              label: 'Akurasi',
            ),
          ),
          const SizedBox(height: PlasSpacing.space4),
          Text(
            detail.exerciseTitle,
            style: PlasTypography.heading,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PlasSpacing.space2),
          Wrap(
            spacing: PlasSpacing.space2,
            runSpacing: PlasSpacing.space2,
            alignment: WrapAlignment.center,
            children: [
              PlasStatusBadge(
                label: 'Attempt ${detail.attemptNumber}/3',
                variant: PlasBadgeVariant.brand,
                icon: Symbols.history,
              ),
              const PlasStatusBadge(
                label: 'SUBMITTED',
                variant: PlasBadgeVariant.success,
                icon: Symbols.check_circle,
              ),
            ],
          ),
          const SizedBox(height: PlasSpacing.space4),
          const Divider(height: 1, color: PlasColors.borderSubtle),
          const SizedBox(height: PlasSpacing.space4),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1.0);
              final useRow = constraints.maxWidth >= 300 && textScale < 1.5;

              final correctTile = _StatTile(
                key: const ValueKey('review_stat_correct'),
                label: 'Benar',
                value: '$correctCount',
                bgColor: PlasColors.successBg,
                borderColor: PlasColors.successBorder,
                textColor: PlasColors.successText,
                icon: Symbols.check_circle,
              );
              final wrongTile = _StatTile(
                key: const ValueKey('review_stat_wrong'),
                label: 'Salah',
                value: '$wrongCount',
                bgColor: PlasColors.errorBg,
                borderColor: PlasColors.errorBorder,
                textColor: PlasColors.errorText,
                icon: Symbols.cancel,
              );
              final durationTile = _StatTile(
                key: const ValueKey('review_stat_duration'),
                label: 'Durasi',
                value: _formatDuration(totalDurationSeconds),
                bgColor: PlasColors.bgSubtle,
                borderColor: PlasColors.borderDivider,
                textColor: PlasColors.textPrimary,
                icon: Symbols.schedule,
              );

              if (useRow) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: correctTile),
                    const SizedBox(width: PlasSpacing.space2),
                    Expanded(child: wrongTile),
                    const SizedBox(width: PlasSpacing.space2),
                    Expanded(child: durationTile),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  correctTile,
                  const SizedBox(height: PlasSpacing.space2),
                  wrongTile,
                  const SizedBox(height: PlasSpacing.space2),
                  durationTile,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.icon,
  });

  final String label;
  final String value;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PlasSpacing.space3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(PlasRadii.md),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: PlasSpacing.space1),
              Flexible(
                child: Text(
                  label,
                  style: PlasTypography.caption.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PlasSpacing.space1),
          Text(
            value,
            style: PlasTypography.title.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

class _ReviewQuestionCard extends StatelessWidget {
  const _ReviewQuestionCard({required this.item});

  final ExerciseReviewItemDto item;

  @override
  Widget build(BuildContext context) {
    final isCorrect = item.isCorrect == true;
    final answerBg = isCorrect ? PlasColors.successBg : PlasColors.errorBg;
    final answerBorder =
        isCorrect ? PlasColors.successBorder : PlasColors.errorBorder;
    final answerFg = isCorrect ? PlasColors.successText : PlasColors.errorText;
    final explanation = item.explanation?.trim();

    return Container(
      key: ValueKey('review_item_${item.questionId}'),
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
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                'Soal ${item.sequence}',
                style: PlasTypography.title,
              ),
              Wrap(
                spacing: PlasSpacing.space2,
                runSpacing: PlasSpacing.space2,
                children: [
                  PlasStatusBadge(
                    label: isCorrect ? 'Benar' : 'Salah',
                    variant: isCorrect
                        ? PlasBadgeVariant.success
                        : PlasBadgeVariant.error,
                    icon: isCorrect ? Symbols.check_circle : Symbols.cancel,
                  ),
                  PlasStatusBadge(
                    label: _formatDuration(item.timeSpentSeconds),
                    variant: PlasBadgeVariant.neutral,
                    icon: Symbols.schedule,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: PlasSpacing.space3),
          PlasMarkdownView(
            markdown: item.questionText,
            selectableCode: true,
          ),
          const SizedBox(height: PlasSpacing.space4),
          Container(
            key: ValueKey('review_student_answer_${item.questionId}'),
            padding: const EdgeInsets.all(PlasSpacing.space3),
            decoration: BoxDecoration(
              color: answerBg,
              borderRadius: BorderRadius.circular(PlasRadii.md),
              border: Border.all(color: answerBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jawaban Anda',
                  style: PlasTypography.label.copyWith(color: answerFg),
                ),
                const SizedBox(height: PlasSpacing.space1),
                _buildStudentAnswerValue(item, answerFg),
              ],
            ),
          ),
          if (explanation != null && explanation.isNotEmpty) ...[
            const SizedBox(height: PlasSpacing.space3),
            Container(
              key: ValueKey('review_explanation_${item.questionId}'),
              padding: const EdgeInsets.all(PlasSpacing.space4),
              decoration: BoxDecoration(
                color: PlasColors.brandTint,
                borderRadius: BorderRadius.circular(PlasRadii.md),
                border: Border.all(color: PlasColors.brandPrimary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Symbols.menu_book,
                        size: 18,
                        color: PlasColors.brandHover,
                      ),
                      const SizedBox(width: PlasSpacing.space2),
                      Expanded(
                        child: Text(
                          'Pembahasan Konsep',
                          style: PlasTypography.label.copyWith(
                            color: PlasColors.brandHover,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: PlasSpacing.space2),
                  PlasMarkdownView(
                    markdown: explanation,
                    selectableCode: true,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentAnswerValue(
    ExerciseReviewItemDto item,
    Color textColor,
  ) {
    final answer = item.studentAnswer;
    final bodyStyle = PlasTypography.body.copyWith(
      color: textColor,
      fontWeight: FontWeight.w500,
    );

    if (answer == null) {
      return Text('Belum dijawab', style: bodyStyle);
    }

    switch (answer) {
      case McAnswer(:final optionId):
        QuestionOptionDto? matched;
        for (final option in item.options) {
          if (option.optionId == optionId) {
            matched = option;
            break;
          }
        }
        final displayText = matched?.text ?? 'Opsi tidak ditemukan';
        return Text.rich(
          TextSpan(
            style: bodyStyle,
            children: buildInlineSpans(displayText, bodyStyle),
          ),
        );
      case TfAnswer(:final value):
        return Text(value ? 'Benar' : 'Salah', style: bodyStyle);
      case FibAnswer(:final value):
        return Text(
          value,
          style: PlasTypography.code.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        );
    }
  }
}

String _formatDuration(int totalSeconds) {
  final clamped = totalSeconds < 0 ? 0 : totalSeconds;
  if (clamped < 60) {
    return '$clamped detik';
  }
  final minutes = clamped ~/ 60;
  final seconds = (clamped % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _errorMessage(Object error) {
  if (error is PlasApiException) {
    return error.message;
  }
  return plasErrorMessage(ApiErrorCodes.serverError, fallback: error.toString());
}
