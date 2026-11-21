import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/router/app_routes.dart';
import 'package:plasmobile/core/sync/pending_sync_queue.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/data/dto/test_dto.dart';
import 'package:plasmobile/data/repositories/plas_repository.dart';
import 'package:plasmobile/features/auth/application/session_controller.dart';
import 'package:plasmobile/features/shared/providers/plas_providers.dart';
import 'package:plasmobile/features/shared/widgets/question_answer_input.dart';
import 'package:plasmobile/shared/widgets/confirm_dialog.dart';
import 'package:plasmobile/shared/widgets/plas_markdown_view.dart';
import 'package:plasmobile/shared/widgets/plas_state_views.dart';
import 'package:plasmobile/shared/widgets/plas_status_badge.dart';
import 'package:uuid/uuid.dart';

class TestSessionScreen extends ConsumerStatefulWidget {
  const TestSessionScreen({
    super.key,
    required this.testId,
  });

  final String testId;

  @override
  ConsumerState<TestSessionScreen> createState() => _TestSessionScreenState();
}

class _TestSessionScreenState extends ConsumerState<TestSessionScreen> {
  static const Uuid _uuid = Uuid();
  static final RegExp _testAnswerSeqPattern = RegExp(
    r'^/test-attempts/[^/]+/questions/(\d+)/answers$',
  );

  bool _isLoading = true;
  String? _loadError;
  bool _isBlockingDomainError = false;

  TestOverviewItemDto? _overview;
  String? _attemptId;
  TestType? _testType;
  int _totalQuestions = 0;

  bool _showResumeGate = false;
  bool _isResumedSession = false;
  bool _isResuming = false;

  TestActiveQuestionDto? _activeQuestion;
  StudentAnswer? _selectedAnswer;
  bool _isSubmitting = false;
  String? _submissionError;
  bool _readyToSubmitFinal = false;
  int? _pendingNextSequence;

  bool _allowDirectPop = false;
  bool _isExitDialogOpen = false;

  String? _creationRequestId;
  String? _submitAttemptKey;
  final Map<int, String> _startKeys = <int, String>{};
  final Map<int, String> _answerKeys = <int, String>{};

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void didUpdateWidget(covariant TestSessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.testId != oldWidget.testId) {
      _creationRequestId = null;
      _submitAttemptKey = null;
      _startKeys.clear();
      _answerKeys.clear();
      _overview = null;
      _attemptId = null;
      _testType = null;
      _totalQuestions = 0;
      _showResumeGate = false;
      _isResumedSession = false;
      _isResuming = false;
      _activeQuestion = null;
      _selectedAnswer = null;
      _isSubmitting = false;
      _submissionError = null;
      _readyToSubmitFinal = false;
      _pendingNextSequence = null;
      _allowDirectPop = false;
      _loadSession();
    }
  }

  String get _testLabel =>
      _testType == TestType.post ? 'Post-Test' : 'Pre-Test';

  bool get _shouldConfirmExit =>
      !_isLoading &&
      _loadError == null &&
      !_showResumeGate &&
      (_activeQuestion != null || _readyToSubmitFinal);

  String _startKeyFor(int sequence) => _startKeys[sequence] ??= _uuid.v4();

  String _normalizeSyncPath(String path) {
    return path.startsWith('/api/') ? path.substring(4) : path;
  }

  List<PendingSyncItem> _pendingItemsForAttempt(
    List<PendingSyncItem> items,
    String attemptId,
  ) {
    final prefix = '/test-attempts/$attemptId/';
    return items
        .where((item) => _normalizeSyncPath(item.path).startsWith(prefix))
        .toList(growable: false);
  }

  bool _hasPendingSubmitForAttempt(
    List<PendingSyncItem> items,
    String attemptId,
  ) {
    final submitPath = '/test-attempts/$attemptId/submit';
    return items.any((item) => _normalizeSyncPath(item.path) == submitPath);
  }

  int? _maxQueuedAnswerSequence(List<PendingSyncItem> items) {
    int? maxSeq;
    for (final item in items) {
      final match =
          _testAnswerSeqPattern.firstMatch(_normalizeSyncPath(item.path));
      if (match == null) continue;
      final seq = int.tryParse(match.group(1)!);
      if (seq != null && (maxSeq == null || seq > maxSeq)) {
        maxSeq = seq;
      }
    }
    return maxSeq;
  }

  void _restorePendingKeysForAttempt(String attemptId) {
    final pendingForAttempt = _pendingItemsForAttempt(
      ref.read(pendingSyncProvider),
      attemptId,
    );
    for (final item in pendingForAttempt) {
      final path = _normalizeSyncPath(item.path);
      final match = _testAnswerSeqPattern.firstMatch(path);
      if (match != null) {
        final seq = int.tryParse(match.group(1)!);
        if (seq != null) {
          _answerKeys[seq] = item.idempotencyKey;
        }
      } else if (path == '/test-attempts/$attemptId/submit') {
        _submitAttemptKey = item.idempotencyKey;
      }
    }
  }

  TestOverviewItemDto? _matchOverview(TestsOverviewDto dto, String testId) {
    if (dto.preTest.testId == testId) return dto.preTest;
    if (dto.postTest.testId == testId) return dto.postTest;
    return null;
  }

  bool _isBlockingLoadError(String code) {
    return code == ApiErrorCodes.prerequisiteNotMet ||
        code == ApiErrorCodes.testEmpty ||
        code == ApiErrorCodes.notFound ||
        code == ApiErrorCodes.forbidden;
  }

  Future<void> _loadSession({bool allowAttemptExistsRecovery = true}) async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _isBlockingDomainError = false;
      _submissionError = null;
    });

    try {
      final repo = ref.read(plasRepositoryProvider);
      final overviewDto = await repo.getTests();
      final matched = _matchOverview(overviewDto, widget.testId);
      if (matched == null) {
        throw PlasApiException.fromApiCode(
          ApiErrorCodes.notFound,
          statusCode: 404,
        );
      }

      if (!matched.isEligible &&
          matched.status != TestOverviewStatus.submitted) {
        throw PlasApiException.fromApiCode(
          ApiErrorCodes.prerequisiteNotMet,
          statusCode: 409,
        );
      }

      if (matched.status == TestOverviewStatus.submitted &&
          matched.activeAttemptId != null) {
        if (!mounted) return;
        _overview = matched;
        _testType = matched.testType;
        _totalQuestions = matched.questionCount;
        _attemptId = matched.activeAttemptId;
        _allowDirectPop = true;
        final resultAttemptId = matched.activeAttemptId!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.pushReplacement(AppRoutes.testResult(resultAttemptId));
        });
        return;
      }

      if (matched.status == TestOverviewStatus.inProgress &&
          matched.activeAttemptId != null) {
        if (!mounted) return;
        final activeAttemptId = matched.activeAttemptId!;
        setState(() {
          _isLoading = false;
          _overview = matched;
          _testType = matched.testType;
          _totalQuestions = matched.questionCount;
          _attemptId = activeAttemptId;
          _showResumeGate = true;
          _activeQuestion = null;
          _readyToSubmitFinal = false;
          _selectedAnswer = null;
          _pendingNextSequence = null;
          _restorePendingKeysForAttempt(activeAttemptId);
        });
        return;
      }

      if (matched.questionCount <= 0) {
        throw PlasApiException.fromApiCode(
          ApiErrorCodes.testEmpty,
          statusCode: 422,
        );
      }

      _creationRequestId ??= _uuid.v4();
      final startDto = await repo.createTestAttempt(
        testId: widget.testId,
        creationRequestId: _creationRequestId!,
      );

      final firstQuestion = startDto.firstQuestion ??
          await repo.startTestQuestion(
            attemptId: startDto.attemptId,
            sequence: startDto.currentSequence,
            idempotencyKey: _startKeyFor(startDto.currentSequence),
          );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _overview = matched;
        _testType = startDto.testType;
        _totalQuestions = startDto.totalQuestions;
        _attemptId = startDto.attemptId;
        _showResumeGate = false;
        _isResumedSession = false;
        _activeQuestion = firstQuestion;
        _readyToSubmitFinal = false;
        _selectedAnswer = null;
        _pendingNextSequence = null;
        _allowDirectPop = false;
      });
    } on PlasApiException catch (error) {
      if (error.code == ApiErrorCodes.attemptExists &&
          allowAttemptExistsRecovery) {
        await _loadSession(allowAttemptExistsRecovery: false);
        return;
      }
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.message;
        _isBlockingDomainError = _isBlockingLoadError(error.code);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = plasErrorMessage(
          ApiErrorCodes.serverError,
          fallback: error.toString(),
        );
        _isBlockingDomainError = false;
      });
    }
  }

  Future<void> _handleExitPressed() async {
    if (_isSubmitting || _isResuming || _isExitDialogOpen) return;
    if (!_shouldConfirmExit) {
      _exitToParent();
      return;
    }

    _isExitDialogOpen = true;
    try {
      final confirmed = await showPlasConfirmDialog(
        context,
        title: 'Keluar Sementara dari Tes?',
        message:
            'Jawaban yang sudah Anda kirim tetap tersimpan pada sesi IN_PROGRESS dan Anda dapat melanjutkan tes nanti dari soal berikutnya.',
        confirmLabel: 'Keluar Sementara',
        cancelLabel: 'Batal',
      );
      if (!confirmed || !mounted) return;
      setState(() {
        _allowDirectPop = true;
      });
      _exitToParent();
    } finally {
      _isExitDialogOpen = false;
    }
  }

  void _exitToParent() {
    if (_attemptId != null) {
      ref.invalidate(testsOverviewProvider);
      ref.invalidate(progressSummaryProvider);
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.learn);
    }
  }

  Future<void> _handleResumePressed() async {
    final attemptId = _attemptId;
    if (attemptId == null || _isResuming) return;

    setState(() {
      _isResuming = true;
      _submissionError = null;
    });

    final repo = ref.read(plasRepositoryProvider);
    final pendingBefore = _pendingItemsForAttempt(
      ref.read(pendingSyncProvider),
      attemptId,
    );
    final hadPendingSubmit =
        _hasPendingSubmitForAttempt(pendingBefore, attemptId);
    final maxQueuedAnswerSeq = _maxQueuedAnswerSequence(pendingBefore);

    try {
      if (pendingBefore.isNotEmpty) {
        await retryPendingSyncQueue(ref);
        if (!mounted) return;

        final remaining = _pendingItemsForAttempt(
          ref.read(pendingSyncProvider),
          attemptId,
        );
        if (remaining.isNotEmpty) {
          setState(() {
            _isResuming = false;
            _submissionError = plasErrorMessage(ApiErrorCodes.networkOffline);
          });
          return;
        }

        if (hadPendingSubmit) {
          await _finishSubmittedSession(attemptId);
          return;
        }

        if (_totalQuestions > 0 && maxQueuedAnswerSeq == _totalQuestions) {
          setState(() {
            _isResuming = false;
            _showResumeGate = false;
            _isResumedSession = true;
            _activeQuestion = null;
            _readyToSubmitFinal = true;
            _selectedAnswer = null;
            _allowDirectPop = false;
          });
          await _promptAndSubmitFinal();
          return;
        }
      }

      final resumed = await repo.resumeTestAttempt(attemptId);
      if (!mounted) return;
      setState(() {
        _isResuming = false;
        _showResumeGate = false;
        _isResumedSession = true;
        _activeQuestion = resumed;
        _totalQuestions = resumed.totalQuestions;
        _readyToSubmitFinal = false;
        _selectedAnswer = null;
        _pendingNextSequence = null;
        _allowDirectPop = false;
      });
    } on PlasApiException catch (error) {
      if (!mounted) return;
      if (error.code == ApiErrorCodes.attemptSubmitted ||
          error.code == ApiErrorCodes.alreadySubmitted) {
        await _finishSubmittedSession(attemptId);
        return;
      }
      setState(() {
        _isResuming = false;
        _submissionError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isResuming = false;
        _submissionError = plasErrorMessage(
          ApiErrorCodes.serverError,
          fallback: error.toString(),
        );
      });
    }
  }

  Future<void> _submitCurrentAnswer() async {
    final attemptId = _attemptId;
    final question = _activeQuestion;
    if (attemptId == null || question == null || _isSubmitting) return;

    final repo = ref.read(plasRepositoryProvider);

    if (_pendingNextSequence != null) {
      setState(() {
        _isSubmitting = true;
        _submissionError = null;
      });
      await _advanceToSequence(attemptId, _pendingNextSequence!);
      return;
    }

    final answer = _selectedAnswer;
    if (answer == null) return;

    final sequence = question.sequence;
    final answerKey = _answerKeys[sequence] ??= _uuid.v4();

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      final ack = await repo.submitTestAnswer(
        attemptId: attemptId,
        sequence: sequence,
        answer: answer,
        submissionRequestId: answerKey,
      );
      if (!mounted) return;

      if (ack.nextSequence != null) {
        _pendingNextSequence = ack.nextSequence;
        await _advanceToSequence(attemptId, ack.nextSequence!);
        return;
      }

      setState(() {
        _isSubmitting = false;
        _readyToSubmitFinal = true;
        _selectedAnswer = null;
        _submissionError = null;
      });
      await _promptAndSubmitFinal();
    } on PlasApiException catch (error) {
      if (!mounted) return;

      if (error.isOffline ||
          error.code == ApiErrorCodes.networkOffline ||
          error.isRetryable) {
        await ref.read(pendingSyncProvider.notifier).enqueue(
              PendingSyncItem(
                idempotencyKey: answerKey,
                method: 'POST',
                path: '/test-attempts/$attemptId/questions/$sequence/answers',
                body: <String, dynamic>{'answer': answer.toJson()},
                createdAtIso: DateTime.now().toUtc().toIso8601String(),
                operationLabel: 'Kirim jawaban soal $sequence',
              ),
            );
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _submissionError = null;
        });
        return;
      }

      if (error.code == ApiErrorCodes.alreadyAnswered) {
        if (sequence < question.totalQuestions) {
          await _advanceToSequence(attemptId, sequence + 1);
        } else {
          setState(() {
            _isSubmitting = false;
            _readyToSubmitFinal = true;
            _selectedAnswer = null;
            _submissionError = null;
          });
          await _promptAndSubmitFinal();
        }
        return;
      }

      if (error.code == ApiErrorCodes.attemptSubmitted ||
          error.code == ApiErrorCodes.alreadySubmitted) {
        await _finishSubmittedSession(attemptId);
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

  Future<void> _advanceToSequence(String attemptId, int nextSequence) async {
    try {
      final nextQuestion =
          await ref.read(plasRepositoryProvider).startTestQuestion(
                attemptId: attemptId,
                sequence: nextSequence,
                idempotencyKey: _startKeyFor(nextSequence),
              );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _pendingNextSequence = null;
        _activeQuestion = nextQuestion;
        _totalQuestions = nextQuestion.totalQuestions;
        _selectedAnswer = null;
        _submissionError = null;
      });
    } on PlasApiException catch (error) {
      if (!mounted) return;
      if (error.code == ApiErrorCodes.attemptSubmitted ||
          error.code == ApiErrorCodes.alreadySubmitted) {
        await _finishSubmittedSession(attemptId);
        return;
      }
      if (error.code == ApiErrorCodes.alreadyAnswered) {
        try {
          final resumed = await ref
              .read(plasRepositoryProvider)
              .resumeTestAttempt(attemptId);
          if (!mounted) return;
          setState(() {
            _isSubmitting = false;
            _pendingNextSequence = null;
            _activeQuestion = resumed;
            _totalQuestions = resumed.totalQuestions;
            _selectedAnswer = null;
            _submissionError = null;
          });
        } on PlasApiException catch (resumeError) {
          if (!mounted) return;
          if (resumeError.code == ApiErrorCodes.attemptSubmitted ||
              resumeError.code == ApiErrorCodes.alreadySubmitted) {
            await _finishSubmittedSession(attemptId);
            return;
          }
          setState(() {
            _isSubmitting = false;
            _submissionError = resumeError.message;
          });
        }
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

  Future<void> _promptAndSubmitFinal() async {
    final attemptId = _attemptId;
    if (attemptId == null || !mounted || _isSubmitting) return;

    final confirmed = await showSubmitTestConfirmDialog(
      context,
      testLabel: _testLabel,
    );
    if (!confirmed || !mounted) return;

    final submitKey = _submitAttemptKey ??= _uuid.v4();
    final pendingForAttempt = _pendingItemsForAttempt(
      ref.read(pendingSyncProvider),
      attemptId,
    );

    if (pendingForAttempt.isNotEmpty) {
      await _enqueueSubmitAttempt(
        attemptId: attemptId,
        submitKey: submitKey,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      final result = await ref.read(plasRepositoryProvider).submitTestAttempt(
            attemptId: attemptId,
            idempotencyKey: submitKey,
          );
      if (!mounted) return;
      await _finishSubmittedSession(result.attemptId);
    } on PlasApiException catch (error) {
      if (!mounted) return;

      if (error.isOffline ||
          error.code == ApiErrorCodes.networkOffline ||
          error.isRetryable) {
        await _enqueueSubmitAttempt(
          attemptId: attemptId,
          submitKey: submitKey,
        );
        return;
      }

      if (error.code == ApiErrorCodes.alreadySubmitted ||
          error.code == ApiErrorCodes.attemptSubmitted) {
        await _finishSubmittedSession(attemptId);
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
            path: '/test-attempts/$attemptId/submit',
            body: const <String, dynamic>{},
            createdAtIso: DateTime.now().toUtc().toIso8601String(),
            operationLabel: 'Kumpulkan $_testLabel',
          ),
        );
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _submissionError = null;
    });
  }

  Future<void> _handleRetrySync() async {
    final attemptId = _attemptId;
    if (attemptId == null) return;

    final pendingBefore = _pendingItemsForAttempt(
      ref.read(pendingSyncProvider),
      attemptId,
    );
    final hadPendingSubmit =
        _hasPendingSubmitForAttempt(pendingBefore, attemptId);
    final maxQueuedAnswerSeq = _maxQueuedAnswerSequence(pendingBefore);

    setState(() {
      _submissionError = null;
    });

    try {
      await retryPendingSyncQueue(ref);
      if (!mounted) return;

      final remainingForAttempt = _pendingItemsForAttempt(
        ref.read(pendingSyncProvider),
        attemptId,
      );
      if (remainingForAttempt.isNotEmpty) {
        return;
      }

      if (hadPendingSubmit) {
        await _finishSubmittedSession(attemptId);
        return;
      }

      if (_showResumeGate) {
        return;
      }

      final isFinalQuestion = (_activeQuestion != null &&
              _activeQuestion!.sequence == _activeQuestion!.totalQuestions) ||
          (_totalQuestions > 0 && maxQueuedAnswerSeq == _totalQuestions);

      if (isFinalQuestion) {
        setState(() {
          _isSubmitting = false;
          _readyToSubmitFinal = true;
          _selectedAnswer = null;
          _submissionError = null;
        });
        await _promptAndSubmitFinal();
        return;
      }

      final resumed =
          await ref.read(plasRepositoryProvider).resumeTestAttempt(attemptId);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _activeQuestion = resumed;
        _totalQuestions = resumed.totalQuestions;
        _selectedAnswer = null;
        _pendingNextSequence = null;
        _submissionError = null;
      });
    } on PlasApiException catch (error) {
      if (!mounted) return;
      if (error.code == ApiErrorCodes.attemptSubmitted ||
          error.code == ApiErrorCodes.alreadySubmitted) {
        await _finishSubmittedSession(attemptId);
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

  Future<void> _finishSubmittedSession(String resultAttemptId) async {
    try {
      await ref.read(sessionControllerProvider.notifier).refreshProfile();
    } catch (_) {
      // Non-fatal if profile refresh fails right after commit; M12 still loads.
    }
    if (!mounted) return;
    invalidateLearningData(ref);
    _allowDirectPop = true;
    context.pushReplacement(AppRoutes.testResult(resultAttemptId));
  }

  @override
  Widget build(BuildContext context) {
    final allPendingItems = ref.watch(pendingSyncProvider);
    final isSyncing = ref.watch(isSyncingPendingProvider);
    final attemptId = _attemptId;
    final pendingForAttempt = attemptId == null
        ? const <PendingSyncItem>[]
        : _pendingItemsForAttempt(allPendingItems, attemptId);

    final canPopDirectly = _allowDirectPop || !_shouldConfirmExit;
    final titleText = _overview?.title ?? _testLabel;

    return PopScope(
      canPop: canPopDirectly,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleExitPressed();
      },
      child: Scaffold(
        backgroundColor: PlasColors.bgCanvas,
        appBar: AppBar(
          leading: IconButton(
            key: const ValueKey('test_exit_button'),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            tooltip: _shouldConfirmExit ? 'Keluar Sementara' : 'Kembali',
            onPressed: _isSubmitting || _isResuming ? null : _handleExitPressed,
            icon: const Icon(Symbols.arrow_back, size: 22),
          ),
          title: Text(
            titleText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PlasSpacing.space4),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: _buildBody(
                  context: context,
                  pendingForAttempt: pendingForAttempt,
                  isSyncing: isSyncing,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required List<PendingSyncItem> pendingForAttempt,
    required bool isSyncing,
  }) {
    if (_isLoading) {
      return const PlasLoadingSkeleton(
        message: 'Menyiapkan sesi evaluasi tes...',
        cardCount: 3,
      );
    }

    if (_loadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlasErrorView(
            key: const ValueKey('test_load_error_view'),
            title: 'Tidak Dapat Membuka Tes',
            message: _loadError!,
            onRetry: _isBlockingDomainError ? null : _loadSession,
          ),
          const SizedBox(height: PlasSpacing.space4),
          OutlinedButton(
            key: const ValueKey('test_error_back_button'),
            onPressed: _exitToParent,
            child: const Text(
              'Kembali ke Beranda',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    if (_showResumeGate) {
      return _buildResumeGateView(
        pendingForAttempt: pendingForAttempt,
        isSyncing: isSyncing,
      );
    }

    if (_readyToSubmitFinal) {
      return _buildReadyToSubmitView(
        pendingForAttempt: pendingForAttempt,
        isSyncing: isSyncing,
      );
    }

    final question = _activeQuestion;
    if (question == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlasErrorView(
            key: const ValueKey('test_load_error_view'),
            title: 'Soal Tes Belum Tersedia',
            message: plasErrorMessage(ApiErrorCodes.testEmpty),
          ),
          const SizedBox(height: PlasSpacing.space4),
          OutlinedButton(
            key: const ValueKey('test_error_back_button'),
            onPressed: _exitToParent,
            child: const Text(
              'Kembali ke Beranda',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return _buildActiveQuestionView(
      question: question,
      pendingForAttempt: pendingForAttempt,
      isSyncing: isSyncing,
    );
  }

  Widget _buildResumeGateView({
    required List<PendingSyncItem> pendingForAttempt,
    required bool isSyncing,
  }) {
    final overview = _overview;
    final questionCount =
        overview?.questionCount ?? (_totalQuestions > 0 ? _totalQuestions : 0);

    return Column(
      key: const ValueKey('test_resume_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pendingForAttempt.isNotEmpty) ...[
          PlasOfflineSyncBanner(
            key: const ValueKey('test_offline_sync_banner'),
            pendingCount: pendingForAttempt.length,
            isSyncing: isSyncing,
            onRetry: _handleRetrySync,
          ),
          const SizedBox(height: PlasSpacing.space4),
        ],
        Container(
          key: const ValueKey('test_resume_warning_card'),
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
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PlasStatusBadge(
                    label: _testLabel,
                    variant: PlasBadgeVariant.brand,
                    icon: Symbols.assignment,
                  ),
                  const PlasStatusBadge(
                    label: 'IN_PROGRESS',
                    variant: PlasBadgeVariant.warning,
                    icon: Symbols.schedule,
                  ),
                ],
              ),
              const SizedBox(height: PlasSpacing.space3),
              Text(
                'Sesi $_testLabel Belum Selesai',
                style: PlasTypography.heading.copyWith(
                  color: PlasColors.warningText,
                ),
              ),
              const SizedBox(height: PlasSpacing.space2),
              Text(
                'Anda memiliki sesi pengerjaan IN_PROGRESS${questionCount > 0 ? ' ($questionCount soal)' : ''}. Progres soal yang sudah dijawab dan urutan opsi pilihan ganda (snapshot) tetap terjaga secara linear.',
                style: PlasTypography.body.copyWith(
                  color: PlasColors.warningText,
                ),
              ),
            ],
          ),
        ),
        if (_submissionError != null) ...[
          const SizedBox(height: PlasSpacing.space4),
          PlasErrorView(
            key: const ValueKey('test_submission_error_view'),
            message: _submissionError!,
          ),
        ],
        const SizedBox(height: PlasSpacing.space5),
        ElevatedButton(
          key: const ValueKey('test_resume_cta'),
          onPressed: _isResuming || isSyncing ? null : _handleResumePressed,
          child: Text(
            _isResuming ? 'Memuat Sesi...' : 'Lanjutkan Tes ->',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: PlasSpacing.space3),
        OutlinedButton(
          key: const ValueKey('test_resume_back_button'),
          onPressed: _isResuming ? null : _exitToParent,
          child: const Text(
            'Kembali',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveQuestionView({
    required TestActiveQuestionDto question,
    required List<PendingSyncItem> pendingForAttempt,
    required bool isSyncing,
  }) {
    final attemptId = _attemptId;
    final hasPendingAnswerForCurrent = pendingForAttempt.any((item) {
      final match =
          _testAnswerSeqPattern.firstMatch(_normalizeSyncPath(item.path));
      return match != null && int.tryParse(match.group(1)!) == question.sequence;
    });
    final hasPendingSubmit = attemptId != null &&
        _hasPendingSubmitForAttempt(pendingForAttempt, attemptId);

    final isLastQuestion = question.sequence == question.totalQuestions;
    final canSubmit = !_isSubmitting &&
        !hasPendingAnswerForCurrent &&
        !hasPendingSubmit &&
        (_pendingNextSequence != null || _selectedAnswer != null);

    final ctaLabel = _isSubmitting
        ? 'Mengirim Jawaban...'
        : (isLastQuestion ? 'Kirim & Selesai ->' : 'Kirim & Lanjut ->');

    final progressRatio = question.totalQuestions > 0
        ? (question.sequence / question.totalQuestions).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isResumedSession) ...[
          Container(
            key: const ValueKey('test_resumed_banner'),
            padding: const EdgeInsets.symmetric(
              horizontal: PlasSpacing.space3,
              vertical: PlasSpacing.space2,
            ),
            decoration: BoxDecoration(
              color: PlasColors.warningBg,
              borderRadius: BorderRadius.circular(PlasRadii.md),
              border: Border.all(color: PlasColors.warningBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Symbols.info,
                  size: 18,
                  color: PlasColors.warningText,
                ),
                const SizedBox(width: PlasSpacing.space2),
                Expanded(
                  child: Text(
                    'Melanjutkan sesi IN_PROGRESS',
                    style: PlasTypography.label.copyWith(
                      color: PlasColors.warningText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PlasSpacing.space3),
        ],
        if (pendingForAttempt.isNotEmpty) ...[
          PlasOfflineSyncBanner(
            key: const ValueKey('test_offline_sync_banner'),
            pendingCount: pendingForAttempt.length,
            isSyncing: isSyncing,
            onRetry: _handleRetrySync,
          ),
          const SizedBox(height: PlasSpacing.space4),
        ],
        Container(
          key: const ValueKey('test_session_header'),
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
                      Text(_testLabel, style: PlasTypography.codeMeta),
                      Text(
                        'Soal ${question.sequence} dari ${question.totalQuestions}',
                        style: PlasTypography.title,
                      ),
                    ],
                  ),
                  PlasStatusBadge(
                    label: question.questionType.apiValue,
                    variant: PlasBadgeVariant.brand,
                    icon: Symbols.quiz,
                  ),
                ],
              ),
              const SizedBox(height: PlasSpacing.space3),
              ClipRRect(
                borderRadius: BorderRadius.circular(PlasRadii.full),
                child: LinearProgressIndicator(
                  value: progressRatio,
                  minHeight: 8,
                  backgroundColor: PlasColors.borderSubtle,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    PlasColors.brandPrimary,
                  ),
                  borderRadius: BorderRadius.circular(PlasRadii.full),
                  stopIndicatorColor: Colors.transparent,
                  trackGap: 0,
                  semanticsLabel:
                      'Progres pengerjaan tes soal ${question.sequence} dari ${question.totalQuestions}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: PlasSpacing.space4),
        Container(
          key: ValueKey('test_question_card_${question.sequence}'),
          padding: const EdgeInsets.all(PlasSpacing.space4),
          decoration: BoxDecoration(
            color: PlasColors.bgSurface,
            borderRadius: BorderRadius.circular(PlasRadii.lg),
            border: Border.all(color: PlasColors.borderDivider),
          ),
          child: PlasMarkdownView(
            markdown: question.questionText,
            selectableCode: true,
          ),
        ),
        const SizedBox(height: PlasSpacing.space4),
        QuestionAnswerInput(
          key: ValueKey('test_input_${question.sequence}'),
          questionType: question.questionType,
          options: question.options,
          value: _selectedAnswer,
          enabled: !_isSubmitting &&
              !hasPendingAnswerForCurrent &&
              !hasPendingSubmit,
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
            key: const ValueKey('test_submission_error_view'),
            message: _submissionError!,
          ),
        ],
        const SizedBox(height: PlasSpacing.space5),
        ElevatedButton(
          key: const ValueKey('test_submit_cta'),
          onPressed: canSubmit ? _submitCurrentAnswer : null,
          child: Text(ctaLabel, textAlign: TextAlign.center),
        ),
      ],
    );
  }

  Widget _buildReadyToSubmitView({
    required List<PendingSyncItem> pendingForAttempt,
    required bool isSyncing,
  }) {
    final attemptId = _attemptId;
    final hasPendingSubmit = attemptId != null &&
        _hasPendingSubmitForAttempt(pendingForAttempt, attemptId);

    return Column(
      key: const ValueKey('test_ready_to_submit_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pendingForAttempt.isNotEmpty) ...[
          PlasOfflineSyncBanner(
            key: const ValueKey('test_offline_sync_banner'),
            pendingCount: pendingForAttempt.length,
            isSyncing: isSyncing,
            onRetry: _handleRetrySync,
          ),
          const SizedBox(height: PlasSpacing.space4),
        ],
        Container(
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
                  PlasStatusBadge(
                    label: _testLabel,
                    variant: PlasBadgeVariant.brand,
                    icon: Symbols.assignment,
                  ),
                  PlasStatusBadge(
                    label: '$_totalQuestions/$_totalQuestions Soal Terjawab',
                    variant: PlasBadgeVariant.success,
                    icon: Symbols.check_circle,
                  ),
                ],
              ),
              const SizedBox(height: PlasSpacing.space4),
              const Text(
                'Semua Soal Terjawab',
                style: PlasTypography.heading,
              ),
              const SizedBox(height: PlasSpacing.space2),
              Text(
                'Seluruh $_totalQuestions soal $_testLabel telah tercatat. Tekan tombol di bawah untuk mengumpulkan $_testLabel. Setelah dikumpulkan, jawaban tidak dapat diubah lagi.',
                style: PlasTypography.body,
              ),
            ],
          ),
        ),
        if (_submissionError != null) ...[
          const SizedBox(height: PlasSpacing.space4),
          PlasErrorView(
            key: const ValueKey('test_submission_error_view'),
            message: _submissionError!,
          ),
        ],
        const SizedBox(height: PlasSpacing.space5),
        ElevatedButton(
          key: const ValueKey('test_final_submit_cta'),
          onPressed:
              (_isSubmitting || hasPendingSubmit) ? null : _promptAndSubmitFinal,
          child: Text(
            _isSubmitting ? 'Mengumpulkan $_testLabel...' : 'Kumpulkan $_testLabel',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
