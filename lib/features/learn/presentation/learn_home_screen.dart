import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/router/app_routes.dart';
import 'package:plasmobile/core/sync/pending_sync_queue.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/data/dto/material_dto.dart';
import 'package:plasmobile/data/dto/progress_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/data/dto/student_profile_dto.dart';
import 'package:plasmobile/data/dto/test_dto.dart';
import 'package:plasmobile/features/auth/application/session_controller.dart';
import 'package:plasmobile/features/shared/providers/plas_providers.dart';
import 'package:plasmobile/shared/widgets/plas_state_views.dart';
import 'package:plasmobile/shared/widgets/plas_status_badge.dart';

class LearnHomeScreen extends ConsumerWidget {
  const LearnHomeScreen({super.key});

  Future<void> _handleRefresh(WidgetRef ref) async {
    ref.invalidate(progressSummaryProvider);
    ref.invalidate(testsOverviewProvider);
    ref.invalidate(materialsProvider);
    ref.invalidate(aiQuotaProvider);

    await Future.wait<void>([
      ref.read(progressSummaryProvider.future).then((_) {}).catchError((_) {}),
      ref.read(testsOverviewProvider.future).then((_) {}).catchError((_) {}),
      ref.read(materialsProvider.future).then((_) {}).catchError((_) {}),
      ref
          .read(sessionControllerProvider.notifier)
          .refreshProfile()
          .catchError((_) {}),
    ]);
  }

  Future<void> _handleRetrySync(BuildContext context, WidgetRef ref) async {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final pendingItems = ref.watch(pendingSyncProvider);
    final isSyncing = ref.watch(isSyncingPendingProvider);
    final progressAsync = ref.watch(progressSummaryProvider);
    final testsAsync = ref.watch(testsOverviewProvider);
    final materialsAsync = ref.watch(materialsProvider);

    return Scaffold(
      backgroundColor: PlasColors.bgCanvas,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StudentGreetingHeader(profile: session.profile),
                    if (pendingItems.isNotEmpty) ...[
                      const SizedBox(height: PlasSpacing.space4),
                      PlasOfflineSyncBanner(
                        pendingCount: pendingItems.length,
                        isSyncing: isSyncing,
                        onRetry: () => _handleRetrySync(context, ref),
                      ),
                    ],
                    const SizedBox(height: PlasSpacing.space4),
                    progressAsync.when(
                      loading: () => const PlasLoadingSkeleton(
                        message: 'Memuat ringkasan progres belajar...',
                        cardCount: 1,
                      ),
                      error: (error, _) => PlasErrorView(
                        title: 'Gagal Memuat Progres',
                        message: _errorMessage(error),
                        onRetry: () => ref.invalidate(progressSummaryProvider),
                      ),
                      data: (progress) => _HeroProgressBanner(
                        progress: progress,
                      ),
                    ),
                    const SizedBox(height: PlasSpacing.space6),
                    const Text(
                      'Gerbang Tes',
                      style: PlasTypography.heading,
                    ),
                    const SizedBox(height: PlasSpacing.space3),
                    testsAsync.when(
                      loading: () => const PlasLoadingSkeleton(
                        message: 'Memuat status Pre-Test dan Post-Test...',
                        cardCount: 2,
                      ),
                      error: (error, _) => PlasErrorView(
                        title: 'Gagal Memuat Gerbang Tes',
                        message: _errorMessage(error),
                        onRetry: () => ref.invalidate(testsOverviewProvider),
                      ),
                      data: (tests) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _PreTestCard(item: tests.preTest),
                          const SizedBox(height: PlasSpacing.space3),
                          _PostTestCard(item: tests.postTest),
                        ],
                      ),
                    ),
                    const SizedBox(height: PlasSpacing.space6),
                    _MaterialsSectionHeader(materialsAsync: materialsAsync),
                    const SizedBox(height: PlasSpacing.space3),
                    materialsAsync.when(
                      loading: () => const PlasLoadingSkeleton(
                        message: 'Memuat daftar materi TypeScript...',
                        cardCount: 3,
                      ),
                      error: (error, _) => PlasErrorView(
                        title: 'Gagal Memuat Daftar Materi',
                        message: _errorMessage(error),
                        onRetry: () => ref.invalidate(materialsProvider),
                      ),
                      data: (materials) {
                        if (materials.isEmpty) {
                          return PlasEmptyView(
                            title: 'Belum Ada Materi TypeScript',
                            description:
                                'Materi pembelajaran belum tersedia saat ini. Muat ulang untuk memeriksa kembali.',
                            actionLabel: 'Muat Ulang',
                            onAction: () => ref.invalidate(materialsProvider),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < materials.length; i++) ...[
                              if (i > 0)
                                const SizedBox(height: PlasSpacing.space3),
                              _MaterialListCard(material: materials[i]),
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

class _StudentGreetingHeader extends StatelessWidget {
  const _StudentGreetingHeader({required this.profile});

  final StudentProfileDto? profile;

  @override
  Widget build(BuildContext context) {
    final nama = profile?.nama.trim();
    final greetingName =
        (nama != null && nama.isNotEmpty) ? nama : 'Mahasiswa';
    final initials = _computeInitials(nama);
    final kelas = profile?.kelas;

    return Container(
      key: const ValueKey('learn_header_card'),
      padding: const EdgeInsets.all(PlasSpacing.space4),
      decoration: BoxDecoration(
        color: PlasColors.bgSurface,
        borderRadius: BorderRadius.circular(PlasRadii.lg),
        border: Border.all(color: PlasColors.borderDivider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: const ValueKey('learn_avatar_initials'),
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: PlasColors.brandTint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: PlasTypography.title.copyWith(
                color: PlasColors.brandPrimary,
              ),
            ),
          ),
          const SizedBox(width: PlasSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, $greetingName',
                  style: PlasTypography.heading,
                ),
                const SizedBox(height: PlasSpacing.space2),
                Wrap(
                  spacing: PlasSpacing.space2,
                  runSpacing: PlasSpacing.space2,
                  children: [
                    if (kelas != null)
                      PlasStatusBadge(
                        key: const ValueKey('learn_class_badge'),
                        label: kelas.kode,
                        variant: PlasBadgeVariant.brand,
                        icon: Symbols.school,
                      )
                    else
                      const PlasStatusBadge(
                        key: ValueKey('learn_class_badge'),
                        label: 'Pengguna Umum',
                        variant: PlasBadgeVariant.neutral,
                        icon: Symbols.person,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroProgressBanner extends StatelessWidget {
  const _HeroProgressBanner({required this.progress});

  final ProgressSummaryDto progress;

  @override
  Widget build(BuildContext context) {
    final total = progress.totalExercises;
    final completed = progress.completedExercises;
    final ratio = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    final percent = (ratio * 100).round();

    return Container(
      key: const ValueKey('learn_hero_progress_card'),
      padding: const EdgeInsets.all(PlasSpacing.space5),
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
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'PROGRES BELAJAR',
                style: PlasTypography.codeMeta,
              ),
              Text(
                '$percent%',
                style: PlasTypography.title.copyWith(
                  color: PlasColors.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: PlasSpacing.space2),
          Text(
            '$completed/$total Materi Selesai',
            style: PlasTypography.display,
          ),
          const SizedBox(height: PlasSpacing.space3),
          ClipRRect(
            borderRadius: BorderRadius.circular(PlasRadii.full),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: PlasColors.borderSubtle,
              valueColor: const AlwaysStoppedAnimation<Color>(
                PlasColors.brandPrimary,
              ),
              borderRadius: BorderRadius.circular(PlasRadii.full),
              stopIndicatorColor: Colors.transparent,
              trackGap: 0,
              semanticsLabel: 'Progres belajar TypeScript',
              semanticsValue: '$percent%',
            ),
          ),
          const SizedBox(height: PlasSpacing.space3),
          Wrap(
            spacing: PlasSpacing.space2,
            runSpacing: PlasSpacing.space2,
            children: [
              PlasStatusBadge(
                label:
                    'Kuota AI: ${progress.aiQuota.remainingQuota}/${progress.aiQuota.dailyLimit} WITA',
                variant: progress.aiQuota.remainingQuota <= 0
                    ? PlasBadgeVariant.error
                    : PlasBadgeVariant.brand,
                icon: Symbols.schedule,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreTestCard extends StatelessWidget {
  const _PreTestCard({required this.item});

  final TestOverviewItemDto item;

  @override
  Widget build(BuildContext context) {
    final statusBadge = switch (item.status) {
      TestOverviewStatus.notStarted => const PlasStatusBadge(
        label: 'Belum Mulai',
        variant: PlasBadgeVariant.neutral,
        icon: Symbols.schedule,
      ),
      TestOverviewStatus.inProgress => const PlasStatusBadge(
        label: 'Sedang Berjalan',
        variant: PlasBadgeVariant.warning,
        icon: Symbols.schedule,
      ),
      TestOverviewStatus.submitted => const PlasStatusBadge(
        label: 'SUBMITTED',
        variant: PlasBadgeVariant.success,
        icon: Symbols.check_circle,
      ),
    };

    final ctaLabel = switch (item.status) {
      TestOverviewStatus.notStarted => 'Mulai Pre-Test ->',
      TestOverviewStatus.inProgress => 'Lanjutkan Pre-Test ->',
      TestOverviewStatus.submitted => 'Lihat Hasil Pre-Test',
    };

    VoidCallback? onPressed;
    if (item.status == TestOverviewStatus.submitted) {
      final attemptId = item.activeAttemptId;
      onPressed = attemptId != null
          ? () => context.push(AppRoutes.testResult(attemptId))
          : null;
    } else {
      onPressed = () => context.push(AppRoutes.testSession(item.testId));
    }

    return Container(
      key: const ValueKey('learn_pre_test_card'),
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
                  color: PlasColors.brandTint,
                  borderRadius: BorderRadius.circular(PlasRadii.md),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Symbols.assignment,
                  size: 20,
                  color: PlasColors.brandPrimary,
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
                      '${item.questionCount} soal evaluasi awal',
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
                  label: 'Skor: ${_formatScore(item.score!)}',
                  variant: PlasBadgeVariant.brand,
                  icon: Symbols.check_circle,
                ),
            ],
          ),
          const SizedBox(height: PlasSpacing.space4),
          ElevatedButton(
            key: const ValueKey('learn_pre_test_cta'),
            onPressed: onPressed,
            child: Text(ctaLabel, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _PostTestCard extends StatelessWidget {
  const _PostTestCard({required this.item});

  final TestOverviewItemDto item;

  @override
  Widget build(BuildContext context) {
    final isLocked =
        !item.isEligible && item.status != TestOverviewStatus.submitted;

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
          label: 'Terbuka',
          variant: PlasBadgeVariant.brand,
          icon: Symbols.quiz,
        ),
        TestOverviewStatus.inProgress => const PlasStatusBadge(
          label: 'Sedang Berjalan',
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
      ctaLabel = 'Lihat Hasil Post-Test';
      final attemptId = item.activeAttemptId;
      onPressed = attemptId != null
          ? () => context.push(AppRoutes.testResult(attemptId))
          : null;
    } else if (item.status == TestOverviewStatus.inProgress) {
      ctaLabel = 'Lanjutkan Post-test ->';
      onPressed = () => context.push(AppRoutes.testSession(item.testId));
    } else {
      ctaLabel = 'Mulai Post-test ->';
      onPressed = () => context.push(AppRoutes.testSession(item.testId));
    }

    return Container(
      key: const ValueKey('learn_post_test_card'),
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
                  color: isLocked
                      ? PlasColors.disabledBg
                      : PlasColors.brandTint,
                  borderRadius: BorderRadius.circular(PlasRadii.md),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isLocked ? Symbols.lock : Symbols.quiz,
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
                      '${item.questionCount} soal evaluasi akhir',
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
                  label: 'Skor: ${_formatScore(item.score!)}',
                  variant: PlasBadgeVariant.brand,
                  icon: Symbols.check_circle,
                ),
            ],
          ),
          if (isLocked) ...[
            const SizedBox(height: PlasSpacing.space3),
            Container(
              key: const ValueKey('learn_post_test_lock_banner'),
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
            key: const ValueKey('learn_post_test_cta'),
            onPressed: onPressed,
            child: Text(ctaLabel, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _MaterialsSectionHeader extends StatelessWidget {
  const _MaterialsSectionHeader({required this.materialsAsync});

  final AsyncValue<List<MaterialSummaryDto>> materialsAsync;

  @override
  Widget build(BuildContext context) {
    final count = materialsAsync.valueOrNull?.length;
    return Wrap(
      spacing: PlasSpacing.space2,
      runSpacing: PlasSpacing.space2,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Daftar Materi TypeScript',
          style: PlasTypography.heading,
        ),
        if (count != null)
          PlasStatusBadge(
            label: '$count Materi',
            variant: PlasBadgeVariant.neutral,
            icon: Symbols.menu_book,
          ),
      ],
    );
  }
}

class _MaterialListCard extends StatelessWidget {
  const _MaterialListCard({required this.material});

  final MaterialSummaryDto material;

  @override
  Widget build(BuildContext context) {
    final codeTag = 'Materi ${material.sequence.toString().padLeft(2, '0')}';
    final isDone = material.submaterialCount > 0 &&
        material.completedExercises >= material.submaterialCount;

    return Material(
      key: ValueKey('learn_material_card_${material.materialId}'),
      color: PlasColors.bgSurface,
      borderRadius: BorderRadius.circular(PlasRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(PlasRadii.lg),
        onTap: () =>
            context.push(AppRoutes.materialDetail(material.materialId)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            padding: const EdgeInsets.all(PlasSpacing.space4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PlasRadii.lg),
              border: Border.all(color: PlasColors.borderDivider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: PlasColors.brandTint,
                    borderRadius: BorderRadius.circular(PlasRadii.md),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Symbols.code,
                    size: 20,
                    color: PlasColors.brandPrimary,
                  ),
                ),
                const SizedBox(width: PlasSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: PlasSpacing.space2,
                        runSpacing: PlasSpacing.space1,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(codeTag, style: PlasTypography.codeMeta),
                          PlasStatusBadge(
                            label: isDone
                                ? 'Selesai'
                                : '${material.completedExercises}/${material.submaterialCount} Latihan',
                            variant: isDone
                                ? PlasBadgeVariant.success
                                : PlasBadgeVariant.neutral,
                            icon: isDone
                                ? Symbols.check_circle
                                : Symbols.schedule,
                          ),
                        ],
                      ),
                      const SizedBox(height: PlasSpacing.space2),
                      Text(material.title, style: PlasTypography.title),
                      const SizedBox(height: PlasSpacing.space1),
                      Text(
                        material.description,
                        style: PlasTypography.body,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: PlasSpacing.space2),
                const Padding(
                  padding: EdgeInsets.only(top: PlasSpacing.space2),
                  child: Icon(
                    Symbols.chevron_right,
                    size: 20,
                    color: PlasColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _computeInitials(String? fullName) {
  final trimmed = fullName?.trim() ?? '';
  if (trimmed.isEmpty) return 'M';
  final parts =
      trimmed.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}'
      .toUpperCase();
}

String _formatScore(double score) {
  if (score == score.roundToDouble()) {
    return score.round().toString();
  }
  return score.toStringAsFixed(1);
}

String _errorMessage(Object error) {
  if (error is PlasApiException) {
    return error.message;
  }
  return plasErrorMessage(ApiErrorCodes.serverError, fallback: error.toString());
}
