import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/router/app_routes.dart';
import 'package:plasmobile/core/sync/pending_sync_queue.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/core/utils/wita_clock.dart';
import 'package:plasmobile/data/dto/progress_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/data/dto/test_dto.dart';
import 'package:plasmobile/features/shared/providers/plas_providers.dart';
import 'package:plasmobile/shared/widgets/plas_state_views.dart';
import 'package:plasmobile/shared/widgets/plas_status_badge.dart';

enum _ActivityFilter { all, submitted, inProgress }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _ActivityFilter _filter = _ActivityFilter.all;

  Future<void> _handleRefresh() async {
    ref.invalidate(testsOverviewProvider);
    ref.invalidate(activitiesProvider);
    await Future.wait<void>([
      ref.read(testsOverviewProvider.future).then((_) {}).catchError((_) {}),
      ref.read(activitiesProvider.future).then((_) {}).catchError((_) {}),
    ]);
  }

  Future<void> _handleRetrySync(BuildContext context) async {
    try {
      await retryPendingSyncQueue(ref);
    } on PlasApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingItems = ref.watch(pendingSyncProvider);
    final isSyncing = ref.watch(isSyncingPendingProvider);
    final testsAsync = ref.watch(testsOverviewProvider);
    final activitiesAsync = ref.watch(activitiesProvider);

    return Scaffold(
      backgroundColor: PlasColors.bgCanvas,
      body: SafeArea(
        child: RefreshIndicator(
          color: PlasColors.brandPrimary,
          onRefresh: _handleRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(PlasSpacing.space4),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _HistoryHeaderCard(),
                    if (pendingItems.isNotEmpty) ...[
                      const SizedBox(height: PlasSpacing.space4),
                      PlasOfflineSyncBanner(
                        pendingCount: pendingItems.length,
                        isSyncing: isSyncing,
                        onRetry: () => _handleRetrySync(context),
                      ),
                    ],
                    const SizedBox(height: PlasSpacing.space5),
                    const Text(
                      'Evaluasi Pre-Test & Post-Test',
                      style: PlasTypography.heading,
                    ),
                    const SizedBox(height: PlasSpacing.space3),
                    testsAsync.when(
                      loading: () => const PlasLoadingSkeleton(
                        message: 'Memuat ringkasan Pre-Test dan Post-Test...',
                        cardCount: 2,
                      ),
                      error: (error, _) => PlasErrorView(
                        title: 'Gagal Memuat Evaluasi Tes',
                        message: _errorMessage(error),
                        onRetry: () => ref.invalidate(testsOverviewProvider),
                      ),
                      data: (tests) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TestSummaryCard(
                            key: const ValueKey('history_pre_test_card'),
                            ctaKey: const ValueKey('history_pre_test_cta'),
                            item: tests.preTest,
                          ),
                          const SizedBox(height: PlasSpacing.space3),
                          _TestSummaryCard(
                            key: const ValueKey('history_post_test_card'),
                            ctaKey: const ValueKey('history_post_test_cta'),
                            lockBannerKey: const ValueKey(
                              'history_post_test_lock_banner',
                            ),
                            item: tests.postTest,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: PlasSpacing.space6),
                    const Text(
                      'Riwayat Latihan',
                      style: PlasTypography.heading,
                    ),
                    const SizedBox(height: PlasSpacing.space3),
                    Wrap(
                      spacing: PlasSpacing.space2,
                      runSpacing: PlasSpacing.space2,
                      children: [
                        _HistoryFilterPill(
                          key: const ValueKey('history_filter_all'),
                          label: 'Semua',
                          selected: _filter == _ActivityFilter.all,
                          onTap: () => setState(() {
                            _filter = _ActivityFilter.all;
                          }),
                        ),
                        _HistoryFilterPill(
                          key: const ValueKey('history_filter_submitted'),
                          label: 'Selesai',
                          selected: _filter == _ActivityFilter.submitted,
                          onTap: () => setState(() {
                            _filter = _ActivityFilter.submitted;
                          }),
                        ),
                        _HistoryFilterPill(
                          key: const ValueKey('history_filter_in_progress'),
                          label: 'Berlangsung',
                          selected: _filter == _ActivityFilter.inProgress,
                          onTap: () => setState(() {
                            _filter = _ActivityFilter.inProgress;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: PlasSpacing.space3),
                    activitiesAsync.when(
                      loading: () => const PlasLoadingSkeleton(
                        message: 'Memuat riwayat aktivitas latihan...',
                        cardCount: 3,
                      ),
                      error: (error, _) => PlasErrorView(
                        title: 'Gagal Memuat Riwayat Latihan',
                        message: _errorMessage(error),
                        onRetry: () => ref.invalidate(activitiesProvider),
                      ),
                      data: (activities) {
                        if (activities.isEmpty) {
                          return PlasEmptyView(
                            title: 'Belum Ada Riwayat Latihan',
                            description:
                                'Belum ada latihan yang dikerjakan. Mulai belajar materi TypeScript untuk melihat riwayat attempt Anda di sini.',
                            actionLabel: 'Mulai Belajar',
                            onAction: () => context.go(AppRoutes.learn),
                          );
                        }

                        final filtered = switch (_filter) {
                          _ActivityFilter.all => activities,
                          _ActivityFilter.submitted => activities
                              .where(
                                (item) =>
                                    item.status == AttemptStatus.submitted,
                              )
                              .toList(growable: false),
                          _ActivityFilter.inProgress => activities
                              .where(
                                (item) =>
                                    item.status == AttemptStatus.inProgress,
                              )
                              .toList(growable: false),
                        };

                        if (filtered.isEmpty) {
                          return PlasEmptyView(
                            title: 'Tidak Ada Aktivitas pada Filter Ini',
                            description:
                                'Belum ada riwayat latihan yang sesuai dengan filter status yang dipilih.',
                            actionLabel: 'Tampilkan Semua',
                            onAction: () => setState(() {
                              _filter = _ActivityFilter.all;
                            }),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < filtered.length; i++) ...[
                              if (i > 0)
                                const SizedBox(height: PlasSpacing.space3),
                              _ActivityHistoryCard(item: filtered[i]),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: PlasSpacing.space4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryHeaderCard extends StatelessWidget {
  const _HistoryHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('history_header_card'),
      padding: const EdgeInsets.all(PlasSpacing.space4),
      decoration: BoxDecoration(
        color: PlasColors.bgSurface,
        borderRadius: BorderRadius.circular(PlasRadii.lg),
        border: Border.all(color: PlasColors.borderDivider),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CS LAB ENV // RIWAYAT',
            style: PlasTypography.codeMeta,
          ),
          SizedBox(height: PlasSpacing.space1),
          Text(
            'Riwayat Latihan & Tes',
            style: PlasTypography.display,
          ),
          SizedBox(height: PlasSpacing.space2),
          Text(
            'Tinjau hasil Pre-Test, Post-Test, serta seluruh percobaan latihan TypeScript dalam zona waktu WITA.',
            style: PlasTypography.body,
          ),
        ],
      ),
    );
  }
}

class _TestSummaryCard extends StatelessWidget {
  const _TestSummaryCard({
    super.key,
    required this.ctaKey,
    this.lockBannerKey,
    required this.item,
  });

  final Key ctaKey;
  final Key? lockBannerKey;
  final TestOverviewItemDto item;

  @override
  Widget build(BuildContext context) {
    final isLocked = item.testType == TestType.post &&
        !item.isEligible &&
        item.status != TestOverviewStatus.submitted;

    final PlasStatusBadge statusBadge;
    if (isLocked) {
      statusBadge = const PlasStatusBadge(
        label: 'Terkunci',
        variant: PlasBadgeVariant.disabled,
        icon: Symbols.lock,
      );
    } else {
      statusBadge = switch (item.status) {
        TestOverviewStatus.notStarted => const PlasStatusBadge(
            label: 'Belum Mulai',
            variant: PlasBadgeVariant.neutral,
            icon: Symbols.schedule,
          ),
        TestOverviewStatus.inProgress => const PlasStatusBadge(
            label: 'IN_PROGRESS',
            variant: PlasBadgeVariant.warning,
            icon: Symbols.schedule,
          ),
        TestOverviewStatus.submitted => const PlasStatusBadge(
            label: 'SUBMITTED',
            variant: PlasBadgeVariant.success,
            icon: Symbols.check_circle,
          ),
      };
    }

    final String ctaLabel;
    final VoidCallback? onPressed;
    if (isLocked) {
      ctaLabel = 'Mulai Post-test (Terkunci)';
      onPressed = null;
    } else if (item.status == TestOverviewStatus.submitted) {
      ctaLabel = item.testType == TestType.pre
          ? 'Lihat Hasil Pre-Test'
          : 'Lihat Hasil Post-Test';
      final attemptId = item.activeAttemptId;
      onPressed = attemptId != null
          ? () => context.push(AppRoutes.testResult(attemptId))
          : null;
    } else if (item.status == TestOverviewStatus.inProgress) {
      ctaLabel = item.testType == TestType.pre
          ? 'Lanjutkan Pre-Test ->'
          : 'Lanjutkan Post-Test ->';
      onPressed = () => context.push(AppRoutes.testSession(item.testId));
    } else {
      ctaLabel = item.testType == TestType.pre
          ? 'Mulai Pre-Test ->'
          : 'Mulai Post-Test ->';
      onPressed = () => context.push(AppRoutes.testSession(item.testId));
    }

    final headerIcon = isLocked
        ? Symbols.lock
        : (item.testType == TestType.pre ? Symbols.assignment : Symbols.quiz);

    return Container(
      padding: const EdgeInsets.all(PlasSpacing.space4),
      decoration: BoxDecoration(
        color: PlasColors.bgSurface,
        borderRadius: BorderRadius.circular(PlasRadii.lg),
        border: Border.all(color: PlasColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      isLocked ? PlasColors.disabledBg : PlasColors.brandTint,
                  borderRadius: BorderRadius.circular(PlasRadii.md),
                ),
                alignment: Alignment.center,
                child: Icon(
                  headerIcon,
                  size: 20,
                  color: isLocked
                      ? PlasColors.disabledText
                      : PlasColors.brandPrimary,
                ),
              ),
              const SizedBox(width: PlasSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: PlasTypography.title),
                    const SizedBox(height: PlasSpacing.space1),
                    Text(
                      item.testType == TestType.pre
                          ? '${item.questionCount} soal evaluasi awal'
                          : '${item.questionCount} soal evaluasi akhir',
                      style: PlasTypography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: PlasSpacing.space3),
          Wrap(
            spacing: PlasSpacing.space2,
            runSpacing: PlasSpacing.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              statusBadge,
              if (item.status == TestOverviewStatus.submitted &&
                  item.score != null)
                PlasStatusBadge(
                  label: 'Skor: ${_formatScorePercent(item.score!)}',
                  variant: PlasBadgeVariant.brand,
                  icon: Symbols.analytics,
                ),
            ],
          ),
          if (isLocked) ...[
            const SizedBox(height: PlasSpacing.space3),
            Container(
              key: lockBannerKey,
              padding: const EdgeInsets.all(PlasSpacing.space3),
              decoration: BoxDecoration(
                color: PlasColors.warningBg,
                borderRadius: BorderRadius.circular(PlasRadii.md),
                border: Border.all(color: PlasColors.warningBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Symbols.info,
                    size: 20,
                    color: PlasColors.warningText,
                  ),
                  const SizedBox(width: PlasSpacing.space2),
                  Expanded(
                    child: Text(
                      'Selesaikan seluruh latihan (${item.completedExercises}/${item.totalExercises} selesai) untuk membuka Post-test.',
                      style: PlasTypography.body.copyWith(
                        color: PlasColors.warningText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: PlasSpacing.space4),
          ElevatedButton(
            key: ctaKey,
            onPressed: onPressed,
            child: isLocked
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Symbols.lock, size: 18),
                      const SizedBox(width: PlasSpacing.space2),
                      Flexible(
                        child: Text(ctaLabel, textAlign: TextAlign.center),
                      ),
                    ],
                  )
                : Text(ctaLabel, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _HistoryFilterPill extends StatelessWidget {
  const _HistoryFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = selected ? PlasColors.brandTint : PlasColors.bgSurface;
    final fgColor = selected ? PlasColors.brandHover : PlasColors.textSecondary;
    final borderColor =
        selected ? PlasColors.brandPrimary : PlasColors.borderInteractive;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(PlasRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(PlasRadii.md),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: PlasSpacing.space4,
                vertical: PlasSpacing.space3,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PlasRadii.md),
                border: Border.all(
                  color: borderColor,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Center(
                widthFactor: 1.0,
                heightFactor: 1.0,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: PlasTypography.label.copyWith(color: fgColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityHistoryCard extends StatelessWidget {
  const _ActivityHistoryCard({required this.item});

  final ActivityItemDto item;

  @override
  Widget build(BuildContext context) {
    final isSubmitted = item.status == AttemptStatus.submitted;
    final targetTime =
        isSubmitted && item.submittedAt != null ? item.submittedAt! : item.createdAt;
    final timePrefix =
        isSubmitted && item.submittedAt != null ? 'Dikumpulkan' : 'Dimulai';
    final timestampText = '$timePrefix ${_formatWitaDateTime(targetTime)}';

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

    return Material(
      key: ValueKey('history_activity_card_${item.attemptId}'),
      color: PlasColors.bgSurface,
      borderRadius: BorderRadius.circular(PlasRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(PlasRadii.lg),
        onTap: () {
          if (isSubmitted) {
            context.push(AppRoutes.exerciseReview(item.attemptId));
          } else {
            context.push(AppRoutes.exerciseSession(item.exerciseId));
          }
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            padding: const EdgeInsets.all(PlasSpacing.space4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PlasRadii.lg),
              border: Border.all(color: PlasColors.borderDivider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.materialTitle,
                        style: PlasTypography.caption.copyWith(
                          color: PlasColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: PlasSpacing.space1),
                      Text(
                        item.submaterialTitle,
                        style: PlasTypography.title,
                      ),
                      const SizedBox(height: PlasSpacing.space2),
                      Wrap(
                        spacing: PlasSpacing.space2,
                        runSpacing: PlasSpacing.space2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          PlasStatusBadge(
                            label: item.questionType.apiValue,
                            variant: PlasBadgeVariant.brand,
                            icon: Symbols.quiz,
                          ),
                          PlasStatusBadge(
                            label: 'Attempt ${item.attemptNumber}/3',
                            variant: PlasBadgeVariant.neutral,
                            icon: Symbols.history,
                          ),
                          statusBadge,
                          if (isSubmitted && item.score != null)
                            PlasStatusBadge(
                              label: 'Skor: ${_formatScorePercent(item.score!)}',
                              variant: PlasBadgeVariant.success,
                              icon: Symbols.analytics,
                            ),
                        ],
                      ),
                      const SizedBox(height: PlasSpacing.space2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Symbols.schedule,
                            size: 16,
                            color: PlasColors.textMuted,
                          ),
                          const SizedBox(width: PlasSpacing.space1),
                          Expanded(
                            child: Text(
                              timestampText,
                              style: PlasTypography.caption,
                            ),
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

String _formatScorePercent(double score) {
  if (!score.isFinite) return '0%';
  if (score == score.roundToDouble()) {
    return '${score.round()}%';
  }
  return '${score.toStringAsFixed(1)}%';
}

String _formatWitaDateTime(DateTime dateTime) {
  final wita = nowInWita(dateTime);
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final day = wita.day.toString().padLeft(2, '0');
  final month = months[wita.month - 1];
  final year = wita.year.toString().padLeft(4, '0');
  final hour = wita.hour.toString().padLeft(2, '0');
  final minute = wita.minute.toString().padLeft(2, '0');
  return '$day $month $year, $hour:$minute WITA';
}

String _errorMessage(Object error) {
  if (error is PlasApiException) {
    return error.message;
  }
  return plasErrorMessage(ApiErrorCodes.serverError, fallback: error.toString());
}
