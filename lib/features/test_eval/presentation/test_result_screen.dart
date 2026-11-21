import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/router/app_routes.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/data/dto/test_dto.dart';
import 'package:plasmobile/features/shared/providers/plas_providers.dart';
import 'package:plasmobile/shared/widgets/plas_accuracy_ring.dart';
import 'package:plasmobile/shared/widgets/plas_markdown_view.dart';
import 'package:plasmobile/shared/widgets/plas_state_views.dart';
import 'package:plasmobile/shared/widgets/plas_status_badge.dart';

class TestResultScreen extends ConsumerWidget {
  const TestResultScreen({
    super.key,
    required this.attemptId,
  });

  final String attemptId;

  Future<void> _handleRefresh(WidgetRef ref) async {
    ref.invalidate(testAttemptResultProvider(attemptId));
    try {
      await ref.read(testAttemptResultProvider(attemptId).future);
    } catch (_) {}
  }

  void _navigateHome(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.learn);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(testAttemptResultProvider(attemptId));
    final loadedResult = resultAsync.valueOrNull;
    final appBarTitle = switch (loadedResult?.testType) {
      TestType.pre => 'Hasil Pre-Test',
      TestType.post => 'Hasil Post-Test',
      null => 'Hasil Tes',
    };

    return Scaffold(
      backgroundColor: PlasColors.bgCanvas,
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('test_result_back_button'),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          tooltip: 'Kembali ke Beranda',
          onPressed: () => _navigateHome(context),
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
                child: resultAsync.when(
                  loading: () => const PlasLoadingSkeleton(
                    message: 'Memuat ringkasan hasil tes...',
                    cardCount: 3,
                  ),
                  error: (error, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PlasErrorView(
                        key: const ValueKey('test_result_error_view'),
                        title: 'Gagal Memuat Hasil Tes',
                        message: _errorMessage(error),
                        onRetry: () => ref.invalidate(
                          testAttemptResultProvider(attemptId),
                        ),
                      ),
                      const SizedBox(height: PlasSpacing.space4),
                      OutlinedButton(
                        key: const ValueKey('test_result_error_home_button'),
                        onPressed: () => _navigateHome(context),
                        child: const Text(
                          'Kembali ke Beranda',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  data: (result) => _TestResultBody(
                    result: result,
                    onBackHome: () => _navigateHome(context),
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

class _TestResultBody extends StatelessWidget {
  const _TestResultBody({
    required this.result,
    required this.onBackHome,
  });

  final TestAttemptResultDto result;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    final sortedItems = List<TestResultItemDto>.from(result.items)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    final correctCount = sortedItems.where((item) => item.isCorrect).length;
    final wrongCount = sortedItems.length - correctCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultSummaryCard(
          result: result,
          correctCount: correctCount,
          wrongCount: wrongCount,
        ),
        if (result.testType == TestType.pre) ...[
          const SizedBox(height: PlasSpacing.space4),
          Container(
            key: const ValueKey('test_result_class_lock_note'),
            padding: const EdgeInsets.all(PlasSpacing.space4),
            decoration: BoxDecoration(
              color: PlasColors.brandTint,
              borderRadius: BorderRadius.circular(PlasRadii.lg),
              border: Border.all(color: PlasColors.brandPrimary),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Symbols.lock,
                  size: 20,
                  color: PlasColors.brandHover,
                ),
                const SizedBox(width: PlasSpacing.space3),
                Expanded(
                  child: Text(
                    'Kelas Anda terkunci setelah Pre-Test dikumpulkan (DBR-14).',
                    style: PlasTypography.body.copyWith(
                      color: PlasColors.brandHover,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: PlasSpacing.space5),
        const Text(
          'Ringkasan Hasil Per Soal',
          style: PlasTypography.heading,
        ),
        const SizedBox(height: PlasSpacing.space3),
        if (sortedItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(PlasSpacing.space4),
            decoration: BoxDecoration(
              color: PlasColors.bgSurface,
              borderRadius: BorderRadius.circular(PlasRadii.lg),
              border: Border.all(color: PlasColors.borderDivider),
            ),
            child: const Text(
              'Belum ada rincian butir soal untuk hasil tes ini.',
              style: PlasTypography.body,
            ),
          )
        else
          for (var i = 0; i < sortedItems.length; i++) ...[
            if (i > 0) const SizedBox(height: PlasSpacing.space3),
            _ResultQuestionCard(item: sortedItems[i]),
          ],
        const SizedBox(height: PlasSpacing.space5),
        ElevatedButton(
          key: const ValueKey('test_result_home_button'),
          onPressed: onBackHome,
          child: const Text(
            'Kembali ke Beranda',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: PlasSpacing.space4),
      ],
    );
  }
}

class _ResultSummaryCard extends StatelessWidget {
  const _ResultSummaryCard({
    required this.result,
    required this.correctCount,
    required this.wrongCount,
  });

  final TestAttemptResultDto result;
  final int correctCount;
  final int wrongCount;

  @override
  Widget build(BuildContext context) {
    final safeScore = result.score.isFinite
        ? result.score.clamp(0.0, 100.0).toDouble()
        : 0.0;
    final roundedScore = safeScore.round();
    final testLabel =
        result.testType == TestType.pre ? 'Pre-Test' : 'Post-Test';

    return Container(
      key: const ValueKey('test_result_summary_card'),
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
              percentage: safeScore,
              arcColor: PlasColors.brandPrimary,
              trackColor: PlasColors.borderSubtle,
              label: 'Skor',
            ),
          ),
          const SizedBox(height: PlasSpacing.space4),
          Text(
            result.testType == TestType.pre
                ? 'Hasil Pre-Test'
                : 'Hasil Post-Test',
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
                label: testLabel,
                variant: PlasBadgeVariant.neutral,
                icon: Symbols.assignment,
              ),
              const PlasStatusBadge(
                label: 'SUBMITTED',
                variant: PlasBadgeVariant.success,
                icon: Symbols.check_circle,
              ),
              PlasStatusBadge(
                label: 'Skor: $roundedScore%',
                variant: PlasBadgeVariant.brand,
                icon: Symbols.analytics,
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

              final correctTile = _ResultStatTile(
                key: const ValueKey('test_result_stat_correct'),
                label: 'Benar',
                value: '$correctCount',
                bgColor: PlasColors.successBg,
                borderColor: PlasColors.successBorder,
                textColor: PlasColors.successText,
                icon: Symbols.check_circle,
              );
              final wrongTile = _ResultStatTile(
                key: const ValueKey('test_result_stat_wrong'),
                label: 'Salah',
                value: '$wrongCount',
                bgColor: PlasColors.errorBg,
                borderColor: PlasColors.errorBorder,
                textColor: PlasColors.errorText,
                icon: Symbols.cancel,
              );
              final durationTile = _ResultStatTile(
                key: const ValueKey('test_result_stat_duration'),
                label: 'Durasi Total',
                value: _formatTotalDuration(result.totalDurationSeconds),
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

class _ResultStatTile extends StatelessWidget {
  const _ResultStatTile({
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

class _ResultQuestionCard extends StatelessWidget {
  const _ResultQuestionCard({required this.item});

  final TestResultItemDto item;

  @override
  Widget build(BuildContext context) {
    final safeSeconds = item.timeSpentSeconds < 0 ? 0 : item.timeSpentSeconds;

    return Container(
      key: ValueKey('test_result_item_${item.sequence}'),
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
              Wrap(
                spacing: PlasSpacing.space2,
                runSpacing: PlasSpacing.space1,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Soal ${item.sequence}',
                    style: PlasTypography.title,
                  ),
                  PlasStatusBadge(
                    label: item.questionType.apiValue,
                    variant: PlasBadgeVariant.brand,
                    icon: Symbols.quiz,
                  ),
                ],
              ),
              Wrap(
                spacing: PlasSpacing.space2,
                runSpacing: PlasSpacing.space1,
                children: [
                  PlasStatusBadge(
                    label: item.isCorrect ? 'Benar' : 'Salah',
                    variant: item.isCorrect
                        ? PlasBadgeVariant.success
                        : PlasBadgeVariant.error,
                    icon: item.isCorrect ? Symbols.check_circle : Symbols.cancel,
                  ),
                  PlasStatusBadge(
                    label: '$safeSeconds detik',
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
        ],
      ),
    );
  }
}

String _formatTotalDuration(int totalSeconds) {
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
