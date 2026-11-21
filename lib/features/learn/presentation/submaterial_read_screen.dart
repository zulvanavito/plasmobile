import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/router/app_routes.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/data/dto/material_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/features/ai/presentation/ai_assistant_sheet.dart';
import 'package:plasmobile/features/shared/providers/plas_providers.dart';
import 'package:plasmobile/shared/widgets/plas_markdown_view.dart';
import 'package:plasmobile/shared/widgets/plas_state_views.dart';
import 'package:plasmobile/shared/widgets/plas_status_badge.dart';
import 'package:plasmobile/shared/widgets/tanya_ai_fab.dart';

class SubMaterialReadScreen extends ConsumerWidget {
  const SubMaterialReadScreen({
    super.key,
    required this.submaterialId,
  });

  final String submaterialId;

  Future<void> _handleRefresh(WidgetRef ref) async {
    ref.invalidate(subMaterialDetailProvider(submaterialId));
    try {
      await ref.read(subMaterialDetailProvider(submaterialId).future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(subMaterialDetailProvider(submaterialId));
    final detail = detailAsync.valueOrNull;

    return Scaffold(
      backgroundColor: PlasColors.bgCanvas,
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('submaterial_back_button'),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          tooltip: 'Kembali',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else if (detail != null) {
              context.go(AppRoutes.materialDetail(detail.materialId));
            } else {
              context.go(AppRoutes.learn);
            }
          },
          icon: const Icon(Symbols.arrow_back, size: 22),
        ),
        title: Text(
          detail?.title ?? 'Baca SubMateri',
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
            padding: const EdgeInsets.fromLTRB(
              PlasSpacing.space4,
              PlasSpacing.space4,
              PlasSpacing.space4,
              112,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: detailAsync.when(
                  loading: () => const PlasLoadingSkeleton(
                    message: 'Memuat isi submateri TypeScript...',
                    cardCount: 3,
                  ),
                  error: (error, _) => PlasErrorView(
                    title: 'Gagal Memuat SubMateri',
                    message: _errorMessage(error),
                    onRetry: () => ref.invalidate(
                      subMaterialDetailProvider(submaterialId),
                    ),
                  ),
                  data: (subDetail) => _SubMaterialBody(detail: subDetail),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: detail == null
          ? null
          : TanyaAiFab(
              key: const ValueKey('submaterial_tanya_ai_fab'),
              onPressed: () => showAiAssistantSheet(
                context,
                submaterialId: detail.submaterialId,
                topicTitle: detail.title,
              ),
            ),
      bottomNavigationBar: detail == null
          ? null
          : _SubMaterialBottomBar(detail: detail),
    );
  }
}

class _SubMaterialBody extends StatelessWidget {
  const _SubMaterialBody({required this.detail});

  final SubMaterialDetailDto detail;

  @override
  Widget build(BuildContext context) {
    final ex = detail.exercise;
    final hasContent = detail.contentMarkdown.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(PlasSpacing.space4),
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
                  Text(
                    'SubMateri ${detail.sequence.toString().padLeft(2, '0')}',
                    style: PlasTypography.codeMeta,
                  ),
                  PlasStatusBadge(
                    label: ex.questionType.apiValue,
                    variant: PlasBadgeVariant.brand,
                    icon: Symbols.quiz,
                  ),
                  PlasStatusBadge(
                    label: 'Attempt ${ex.attemptsUsed}/${ex.maxAttempts}',
                    variant: PlasBadgeVariant.neutral,
                    icon: Symbols.history,
                  ),
                ],
              ),
              const SizedBox(height: PlasSpacing.space2),
              Text(detail.title, style: PlasTypography.heading),
              const SizedBox(height: PlasSpacing.space1),
              Text(ex.title, style: PlasTypography.caption),
            ],
          ),
        ),
        const SizedBox(height: PlasSpacing.space4),
        if (!hasContent)
          const PlasEmptyView(
            title: 'Konten Belum Tersedia',
            description:
                'Isi materi untuk SubMateri ini belum tersedia saat ini.',
          )
        else
          Container(
            padding: const EdgeInsets.all(PlasSpacing.space4),
            decoration: BoxDecoration(
              color: PlasColors.bgSurface,
              borderRadius: BorderRadius.circular(PlasRadii.lg),
              border: Border.all(color: PlasColors.borderDivider),
            ),
            child: PlasMarkdownView(
              markdown: detail.contentMarkdown,
              selectableCode: true,
            ),
          ),
      ],
    );
  }
}

class _SubMaterialBottomBar extends StatelessWidget {
  const _SubMaterialBottomBar({required this.detail});

  final SubMaterialDetailDto detail;

  @override
  Widget build(BuildContext context) {
    final ex = detail.exercise;
    final isLimitReached = ex.attemptsUsed >= ex.maxAttempts &&
        ex.latestAttemptStatus != AttemptStatus.inProgress;
    final isInProgress = ex.latestAttemptStatus == AttemptStatus.inProgress;

    final String label;
    final VoidCallback? onPressed;
    if (isLimitReached) {
      label = 'Batas Attempt Tercapai (${ex.attemptsUsed}/${ex.maxAttempts})';
      onPressed = null;
    } else if (isInProgress) {
      label = 'Lanjutkan Latihan ->';
      onPressed = () => context.push(
            AppRoutes.exerciseSession(
              ex.exerciseId,
              submaterialId: detail.submaterialId,
            ),
          );
    } else {
      label = 'Mulai Latihan ->';
      onPressed = () => context.push(
            AppRoutes.exerciseSession(
              ex.exerciseId,
              submaterialId: detail.submaterialId,
            ),
          );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: PlasColors.bgSurface,
        border: Border(top: BorderSide(color: PlasColors.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(PlasSpacing.space4),
          child: Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const ValueKey('submaterial_start_exercise_button'),
                  onPressed: onPressed,
                  child: Text(label, textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _errorMessage(Object error) {
  if (error is PlasApiException) {
    return error.message;
  }
  return plasErrorMessage(ApiErrorCodes.serverError, fallback: error.toString());
}
