import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/router/app_routes.dart';
import 'package:plasmobile/core/sync/pending_sync_queue.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/data/dto/exercise_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/data/repositories/plas_repository.dart';
import 'package:plasmobile/features/ai/presentation/ai_assistant_sheet.dart';
import 'package:plasmobile/features/shared/providers/plas_providers.dart';
import 'package:plasmobile/features/shared/widgets/question_answer_input.dart';
import 'package:plasmobile/shared/widgets/confirm_dialog.dart';
import 'package:plasmobile/shared/widgets/plas_markdown_view.dart';
import 'package:plasmobile/shared/widgets/plas_state_views.dart';
import 'package:plasmobile/shared/widgets/plas_status_badge.dart';
import 'package:plasmobile/shared/widgets/tanya_ai_fab.dart';
import 'package:uuid/uuid.dart';

class ExerciseSessionScreen extends ConsumerStatefulWidget {
  const ExerciseSessionScreen({
    super.key,
    required this.exerciseId,
    this.submaterialId,
  });

  final String exerciseId;
  final String? submaterialId;

  @override
  ConsumerState<ExerciseSessionScreen> createState() =>
      _ExerciseSessionScreenState();
}

class _ExerciseSessionScreenState extends ConsumerState<ExerciseSessionScreen> {
  static const Uuid _uuid = Uuid();

  bool _isLoading = true;
  String? _loadError;
  bool _isAttemptLimitReached = false;

  ExerciseAttemptDto? _attempt;
  List<ExerciseQuestionDto> _questions = const <ExerciseQuestionDto>[];
  String? _title;

  int _currentIndex = 0;
  StudentAnswer? _selectedAnswer;
  bool _showHint = false;
  bool _isSubmitting = false;
  String? _submissionError;
  String? _offlineNotice;
  bool _hasPendingSubmit = false;

  String? _creationRequestId;
  String? _submitAttemptKey;
  final Map<String, String> _submissionKeys = <String, String>{};
  final Set<String> _answeredQuestionIds = <String>{};
  final Map<String, StudentAnswer> _recordedAnswers = <String, StudentAnswer>{};

  DateTime _questionShownAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  String _normalizeSyncPath(String path) {
    return path.startsWith('/api/') ? path.substring(4) : path;
  }

  List<PendingSyncItem> _pendingItemsForAttempt(
    List<PendingSyncItem> items,
    String attemptId,
  ) {
    final answerPath = '/exercise-attempts/$attemptId/answers';
    final submitPath = '/exercise-attempts/$attemptId/submit';
    return items.where((item) {
      final path = _normalizeSyncPath(item.path);
      return path == answerPath || path == submitPath;
    }).toList(growable: false);
  }

  bool _hasPendingSubmitForAttempt(
    List<PendingSyncItem> items,
    String attemptId,
  ) {
    final submitPath = '/exercise-attempts/$attemptId/submit';
    return items.any((item) => _normalizeSyncPath(item.path) == submitPath);
  }

  void _navigateBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final subId = widget.submaterialId;
    if (subId != null && subId.isNotEmpty) {
      context.go(AppRoutes.subMaterialRead(subId));
      return;
    }
    context.go(AppRoutes.learn);
  }

  Future<void> _loadSession() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _isAttemptLimitReached = false;
    });

    try {
      final repo = ref.read(plasRepositoryProvider);
      final attempts = await repo.getExerciseAttempts(widget.exerciseId);

      ExerciseAttemptDto? inProgress;
      for (final attempt in attempts) {
        if (attempt.status == AttemptStatus.inProgress) {
          inProgress = attempt;
          break;
        }
      }

      String? resolvedTitle;
      final subId = widget.submaterialId;
      if (subId != null && subId.isNotEmpty) {
        final cachedExercise =
            ref.read(exerciseDetailProvider(subId)).valueOrNull;
        if (cachedExercise != null && cachedExercise.title.trim().isNotEmpty) {
          resolvedTitle = cachedExercise.title;
        } else {
          final cachedSub =
              ref.read(subMaterialDetailProvider(subId)).valueOrNull;
          if (cachedSub != null &&
              cachedSub.exercise.title.trim().isNotEmpty) {
            resolvedTitle = cachedSub.exercise.title;
          }
        }
      }

      late final ExerciseAttemptDto activeAttempt;
      late final List<ExerciseQuestionDto> questions;
      final answeredIds = <String>{};
      final recorded = <String, StudentAnswer>{};

      if (inProgress != null) {
        final detail = await repo.getExerciseAttemptDetail(inProgress.attemptId);
        resolvedTitle ??= detail.exerciseTitle;
        activeAttempt = inProgress;

        if (detail.items.isNotEmpty) {
          final sortedItems = List<ExerciseReviewItemDto>.from(detail.items)
            ..sort((a, b) => a.sequence.compareTo(b.sequence));
          questions = sortedItems
              .map(
                (item) => ExerciseQuestionDto(
                  questionId: item.questionId,
                  sequence: item.sequence,
                  questionText: item.questionText,
                  questionType: item.questionType,
                  hint: item.hint,
                  options: item.options,
                ),
              )
              .toList(growable: false);
          for (final item in sortedItems) {
            if (item.studentAnswer != null) {
              answeredIds.add(item.questionId);
              recorded[item.questionId] = item.studentAnswer!;
            }
          }
        } else {
          questions = List<ExerciseQuestionDto>.from(inProgress.questions)
            ..sort((a, b) => a.sequence.compareTo(b.sequence));
        }
      } else {
        _creationRequestId ??= _uuid.v4();
        final created = await repo.createExerciseAttempt(
          exerciseId: widget.exerciseId,
          creationRequestId: _creationRequestId!,
        );
        activeAttempt = created;
        questions = List<ExerciseQuestionDto>.from(created.questions)
          ..sort((a, b) => a.sequence.compareTo(b.sequence));

        if (resolvedTitle == null && subId != null && subId.isNotEmpty) {
          try {
            final exDetail = await repo.getExercise(subId);
            resolvedTitle = exDetail.title;
          } catch (_) {
            // Non-fatal: fallback title allows session execution to continue.
          }
        }
      }

      final questionTypeById = <String, QuestionType>{
        for (final q in questions) q.questionId: q.questionType,
      };
      final pendingItems = ref.read(pendingSyncProvider);
      var hasPendingSubmit = false;
      for (final item in pendingItems) {
        final path = _normalizeSyncPath(item.path);
        if (path == '/exercise-attempts/${activeAttempt.attemptId}/answers') {
          final qId = item.body['question_id'];
          if (qId is String && qId.isNotEmpty) {
            answeredIds.add(qId);
            _submissionKeys[qId] = item.idempotencyKey;
            final qType = questionTypeById[qId];
            final rawAnswer = item.body['answer'];
            if (qType != null && rawAnswer is Map) {
              try {
                recorded[qId] = StudentAnswer.fromJson(
                  qType,
                  Map<String, dynamic>.from(rawAnswer),
                );
              } catch (_) {}
            }
          }
        } else if (path ==
            '/exercise-attempts/${activeAttempt.attemptId}/submit') {
          hasPendingSubmit = true;
          _submitAttemptKey = item.idempotencyKey;
        }
      }

      var initialIndex = 0;
      if (questions.isNotEmpty) {
        final firstUnanswered = questions.indexWhere(
          (q) => !answeredIds.contains(q.questionId),
        );
        initialIndex =
            firstUnanswered >= 0 ? firstUnanswered : questions.length - 1;
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = null;
        _isAttemptLimitReached = false;
        _attempt = activeAttempt;
        _questions = questions;
        _title = resolvedTitle ?? 'Sesi Latihan';
        _answeredQuestionIds
          ..clear()
          ..addAll(answeredIds);
        _recordedAnswers
          ..clear()
          ..addAll(recorded);
        _hasPendingSubmit = hasPendingSubmit;
        _currentIndex = initialIndex;
        _selectedAnswer = null;
        _showHint = false;
        _submissionError = null;
        _questionShownAt = DateTime.now();
      });
    } on PlasApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.message;
        _isAttemptLimitReached =
            error.code == ApiErrorCodes.attemptLimitReached;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = plasErrorMessage(
          ApiErrorCodes.serverError,
          fallback: error.toString(),
        );
        _isAttemptLimitReached = false;
      });
    }
  }

  Future<void> _handlePrimaryAction() async {
    final attempt = _attempt;
    if (attempt == null || _questions.isEmpty || _isSubmitting) return;
    if (_hasPendingSubmit) return;

    final currentQuestion = _questions[_currentIndex];
    final isAlreadyAnswered =
        _answeredQuestionIds.contains(currentQuestion.questionId);

    if (isAlreadyAnswered) {
      await _advanceOrConfirmSubmit();
      return;
    }

    final answer = _selectedAnswer;
    if (answer == null) return;

    final elapsedRaw = DateTime.now().difference(_questionShownAt).inSeconds;
    final elapsed = elapsedRaw < 0 ? 0 : elapsedRaw;
    final submissionKey =
        _submissionKeys[currentQuestion.questionId] ??= _uuid.v4();

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      await ref.read(plasRepositoryProvider).submitExerciseAnswer(
            attemptId: attempt.attemptId,
            questionId: currentQuestion.questionId,
            answer: answer,
            timeSpentSeconds: elapsed,
            submissionRequestId: submissionKey,
          );
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _answeredQuestionIds.add(currentQuestion.questionId);
        _recordedAnswers[currentQuestion.questionId] = answer;
        _submissionError = null;
      });

      await _advanceOrConfirmSubmit();
    } on PlasApiException catch (error) {
      if (!mounted) return;

      if (error.isOffline) {
        await ref.read(pendingSyncProvider.notifier).enqueue(
              PendingSyncItem(
                idempotencyKey: submissionKey,
                method: 'POST',
                path: '/exercise-attempts/${attempt.attemptId}/answers',
                body: <String, dynamic>{
                  'question_id': currentQuestion.questionId,
                  'answer': answer.toJson(),
                  'time_spent_seconds': elapsed,
                },
                createdAtIso: DateTime.now().toUtc().toIso8601String(),
                operationLabel:
                    'Kirim jawaban soal ${currentQuestion.sequence}',
              ),
            );
        if (!mounted) return;

        setState(() {
          _isSubmitting = false;
          _answeredQuestionIds.add(currentQuestion.questionId);
          _recordedAnswers[currentQuestion.questionId] = answer;
          _submissionError = null;
          _offlineNotice =
              'Koneksi terputus. Jawaban soal ${currentQuestion.sequence} disimpan sementara dan siap dikirim ulang.';
        });

        await _advanceOrConfirmSubmit();
        return;
      }

      if (error.code == ApiErrorCodes.alreadyAnswered) {
        setState(() {
          _isSubmitting = false;
          _answeredQuestionIds.add(currentQuestion.questionId);
          _recordedAnswers[currentQuestion.questionId] = answer;
          _submissionError = null;
        });
        await _advanceOrConfirmSubmit();
        return;
      }

      if (error.code == ApiErrorCodes.alreadySubmitted ||
          error.code == ApiErrorCodes.attemptSubmitted) {
        setState(() {
          _isSubmitting = false;
        });
        invalidateLearningData(ref);
        context.pushReplacement(AppRoutes.exerciseReview(attempt.attemptId));
        return;
      }

      setState(() {
        _isSubmitting = false;
        _submissionError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submissionError = plasErrorMessage(
          ApiErrorCodes.serverError,
          fallback: error.toString(),
        );
      });
    }
  }

  Future<void> _advanceOrConfirmSubmit() async {
    if (!mounted) return;

    if (_currentIndex + 1 < _questions.length) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _showHint = false;
        _submissionError = null;
        _questionShownAt = DateTime.now();
      });
      return;
    }

    await _confirmAndSubmitAttempt();
  }

  Future<void> _confirmAndSubmitAttempt() async {
    final attempt = _attempt;
    if (attempt == null || !mounted) return;

    final confirmed = await showSubmitExerciseConfirmDialog(
      context,
      answeredCount: _answeredQuestionIds.length,
      totalCount: _questions.length,
    );
    if (!confirmed || !mounted) return;

    final submitKey = _submitAttemptKey ??= _uuid.v4();
    final pendingForAttempt = _pendingItemsForAttempt(
      ref.read(pendingSyncProvider),
      attempt.attemptId,
    );

    if (pendingForAttempt.isNotEmpty) {
      await _enqueueSubmitAttempt(
        attemptId: attempt.attemptId,
        submitKey: submitKey,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      final submitted =
          await ref.read(plasRepositoryProvider).submitExerciseAttempt(
                attemptId: attempt.attemptId,
                idempotencyKey: submitKey,
              );
      if (!mounted) return;
      invalidateLearningData(ref);
      context.pushReplacement(AppRoutes.exerciseReview(submitted.attemptId));
    } on PlasApiException catch (error) {
      if (!mounted) return;

      if (error.isOffline) {
        setState(() {
          _isSubmitting = false;
        });
        await _enqueueSubmitAttempt(
          attemptId: attempt.attemptId,
          submitKey: submitKey,
        );
        return;
      }

      if (error.code == ApiErrorCodes.alreadySubmitted ||
          error.code == ApiErrorCodes.attemptSubmitted) {
        setState(() {
          _isSubmitting = false;
        });
        invalidateLearningData(ref);
        context.pushReplacement(AppRoutes.exerciseReview(attempt.attemptId));
        return;
      }

      setState(() {
        _isSubmitting = false;
        _submissionError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submissionError = plasErrorMessage(
          ApiErrorCodes.serverError,
          fallback: error.toString(),
        );
      });
    }
  }

  Future<void> _enqueueSubmitAttempt({
    required String attemptId,
    required String submitKey,
  }) async {
    await ref.read(pendingSyncProvider.notifier).enqueue(
          PendingSyncItem(
            idempotencyKey: submitKey,
            method: 'POST',
            path: '/exercise-attempts/$attemptId/submit',
            body: const <String, dynamic>{},
            createdAtIso: DateTime.now().toUtc().toIso8601String(),
            operationLabel: 'Kumpulkan latihan',
          ),
        );
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _hasPendingSubmit = true;
      _submissionError = null;
      _offlineNotice =
          'Koneksi terputus. Pengumpulan latihan tersimpan sementara dengan kunci idempotensi aman.';
    });
  }

  Future<void> _handleRetrySync() async {
    final attempt = _attempt;
    if (attempt == null) return;

    final hadPendingSubmit = _hasPendingSubmit ||
        _hasPendingSubmitForAttempt(
          ref.read(pendingSyncProvider),
          attempt.attemptId,
        );

    setState(() {
      _submissionError = null;
    });

    try {
      await retryPendingSyncQueue(ref);
      if (!mounted) return;

      final remainingForAttempt = _pendingItemsForAttempt(
        ref.read(pendingSyncProvider),
        attempt.attemptId,
      );

      if (remainingForAttempt.isEmpty) {
        setState(() {
          _offlineNotice = null;
          _hasPendingSubmit = false;
        });
        if (hadPendingSubmit) {
          invalidateLearningData(ref);
          context.pushReplacement(AppRoutes.exerciseReview(attempt.attemptId));
        }
      }
    } on PlasApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _submissionError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submissionError = plasErrorMessage(
          ApiErrorCodes.serverError,
          fallback: error.toString(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingItems = ref.watch(pendingSyncProvider);
    final isSyncing = ref.watch(isSyncingPendingProvider);
    final hasCurrentQuestion =
        !_isLoading && _loadError == null && _questions.isNotEmpty;
    final currentQuestion =
        hasCurrentQuestion ? _questions[_currentIndex] : null;

    return Scaffold(
      backgroundColor: PlasColors.bgCanvas,
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('exercise_back_button'),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          tooltip: 'Kembali',
          onPressed: () => _navigateBack(context),
          icon: const Icon(Symbols.arrow_back, size: 22),
        ),
        title: Text(
          _title ?? 'Sesi Latihan',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            PlasSpacing.space4,
            PlasSpacing.space4,
            PlasSpacing.space4,
            hasCurrentQuestion ? 104 : PlasSpacing.space6,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: _buildBody(
                context: context,
                allPendingItems: pendingItems,
                isSyncing: isSyncing,
                currentQuestion: currentQuestion,
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: currentQuestion == null
          ? null
          : TanyaAiFab(
              key: const ValueKey('exercise_tanya_ai_fab'),
              isAssessmentMode: false,
              onPressed: () => showAiAssistantSheet(
                context,
                submaterialId: widget.submaterialId,
                exerciseQuestionId: currentQuestion.questionId,
                topicTitle: _title,
              ),
            ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required List<PendingSyncItem> allPendingItems,
    required bool isSyncing,
    required ExerciseQuestionDto? currentQuestion,
  }) {
    if (_isLoading) {
      return const PlasLoadingSkeleton(
        message: 'Menyiapkan sesi soal latihan...',
        cardCount: 3,
      );
    }

    if (_loadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlasErrorView(
            key: const ValueKey('exercise_load_error_view'),
            title: _isAttemptLimitReached
                ? 'Batas Percobaan Tercapai'
                : 'Gagal Memuat Sesi Latihan',
            message: _loadError!,
            onRetry: _isAttemptLimitReached ? null : _loadSession,
          ),
          const SizedBox(height: PlasSpacing.space4),
          OutlinedButton(
            key: const ValueKey('exercise_error_back_button'),
            onPressed: () => _navigateBack(context),
            child: const Text(
              'Kembali ke Materi',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    final attempt = _attempt;
    if (attempt == null || currentQuestion == null) {
      return PlasEmptyView(
        title: 'Soal Latihan Belum Tersedia',
        description:
            'Latihan ini belum memiliki daftar soal yang dapat dikerjakan.',
        actionLabel: 'Kembali ke Materi',
        onAction: () => _navigateBack(context),
      );
    }

    final hintText = currentQuestion.hint?.trim();
    final hasHint = hintText != null && hintText.isNotEmpty;
    final isCurrentAnswered =
        _answeredQuestionIds.contains(currentQuestion.questionId);
    final isLastQuestion = _currentIndex == _questions.length - 1;
    final effectiveAnswer =
        _selectedAnswer ?? _recordedAnswers[currentQuestion.questionId];

    final canSubmit = !_isSubmitting &&
        !_hasPendingSubmit &&
        (isCurrentAnswered || _selectedAnswer != null);

    final ctaLabel = _isSubmitting
        ? 'Mengirim Jawaban...'
        : (isLastQuestion ? 'Kirim & Selesai ->' : 'Kirim & Lanjut ->');

    final hintStyle = PlasTypography.body.copyWith(
      color: PlasColors.warningText,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (allPendingItems.isNotEmpty) ...[
          PlasOfflineSyncBanner(
            key: const ValueKey('exercise_offline_sync_banner'),
            pendingCount: allPendingItems.length,
            isSyncing: isSyncing,
            onRetry: _handleRetrySync,
          ),
          const SizedBox(height: PlasSpacing.space4),
        ] else if (_offlineNotice != null) ...[
          Container(
            key: const ValueKey('exercise_offline_notice'),
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
                    _offlineNotice!,
                    style: PlasTypography.body.copyWith(
                      color: PlasColors.warningText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PlasSpacing.space4),
        ],
        Container(
          key: const ValueKey('exercise_session_header'),
          padding: const EdgeInsets.all(PlasSpacing.space4),
          decoration: BoxDecoration(
            color: PlasColors.bgSurface,
            borderRadius: BorderRadius.circular(PlasRadii.lg),
            border: Border.all(color: PlasColors.borderDivider),
          ),
          child: Wrap(
            spacing: PlasSpacing.space2,
            runSpacing: PlasSpacing.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                'Soal ${_currentIndex + 1} dari ${_questions.length}',
                style: PlasTypography.title,
              ),
              Wrap(
                spacing: PlasSpacing.space2,
                runSpacing: PlasSpacing.space2,
                children: [
                  PlasStatusBadge(
                    label: currentQuestion.questionType.apiValue,
                    variant: PlasBadgeVariant.brand,
                    icon: Symbols.quiz,
                  ),
                  PlasStatusBadge(
                    label: 'Attempt ${attempt.attemptNumber}/3',
                    variant: PlasBadgeVariant.neutral,
                    icon: Symbols.history,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: PlasSpacing.space4),
        Container(
          key: ValueKey('exercise_question_card_${currentQuestion.questionId}'),
          padding: const EdgeInsets.all(PlasSpacing.space4),
          decoration: BoxDecoration(
            color: PlasColors.bgSurface,
            borderRadius: BorderRadius.circular(PlasRadii.lg),
            border: Border.all(color: PlasColors.borderDivider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PlasMarkdownView(
                markdown: currentQuestion.questionText,
                selectableCode: true,
              ),
              if (hasHint) ...[
                const SizedBox(height: PlasSpacing.space4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    key: const ValueKey('exercise_hint_toggle'),
                    style: ButtonStyle(
                      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                      backgroundColor: WidgetStatePropertyAll(
                        _showHint ? PlasColors.warningBg : PlasColors.bgSurface,
                      ),
                      foregroundColor: WidgetStatePropertyAll(
                        _showHint
                            ? PlasColors.warningText
                            : PlasColors.textPrimary,
                      ),
                      side: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.focused)) {
                          return const BorderSide(
                            color: PlasColors.focusLight,
                            width: 2,
                          );
                        }
                        return BorderSide(
                          color: _showHint
                              ? PlasColors.warningBorder
                              : PlasColors.borderInteractive,
                        );
                      }),
                    ),
                    onPressed: () {
                      setState(() {
                        _showHint = !_showHint;
                      });
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Symbols.lightbulb, size: 20),
                        SizedBox(width: PlasSpacing.space2),
                        Flexible(
                          child: Text(
                            'Petunjuk Awal',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showHint) ...[
                  const SizedBox(height: PlasSpacing.space3),
                  Container(
                    key: const ValueKey('exercise_hint_card'),
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
                          Symbols.lightbulb,
                          size: 20,
                          color: PlasColors.warningText,
                        ),
                        const SizedBox(width: PlasSpacing.space2),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: hintStyle,
                              children: buildInlineSpans(hintText, hintStyle),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: PlasSpacing.space4),
        QuestionAnswerInput(
          key: ValueKey('exercise_input_${currentQuestion.questionId}'),
          questionType: currentQuestion.questionType,
          options: currentQuestion.options,
          value: effectiveAnswer,
          enabled: !_isSubmitting && !isCurrentAnswered,
          onChanged: (next) {
            setState(() {
              _selectedAnswer = next;
              _submissionError = null;
            });
          },
        ),
        if (_submissionError != null) ...[
          const SizedBox(height: PlasSpacing.space4),
          PlasErrorView(
            key: const ValueKey('exercise_submission_error_view'),
            message: _submissionError!,
          ),
        ],
        const SizedBox(height: PlasSpacing.space5),
        ElevatedButton(
          key: const ValueKey('exercise_submit_cta'),
          onPressed: canSubmit ? _handlePrimaryAction : null,
          child: Text(ctaLabel, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
