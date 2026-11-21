import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/data/dto/ai_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/data/repositories/plas_repository.dart';
import 'package:plasmobile/features/shared/providers/plas_providers.dart';
import 'package:plasmobile/shared/widgets/owl_bracket_mascot.dart';
import 'package:plasmobile/shared/widgets/plas_markdown_view.dart';
import 'package:plasmobile/shared/widgets/plas_state_views.dart';
import 'package:plasmobile/shared/widgets/plas_status_badge.dart';
import 'package:uuid/uuid.dart';

Future<void> showAiAssistantSheet(
  BuildContext context, {
  String? submaterialId,
  String? exerciseQuestionId,
  String? topicTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => AiAssistantSheet(
      submaterialId: submaterialId,
      exerciseQuestionId: exerciseQuestionId,
      topicTitle: topicTitle,
    ),
  );
}

class AiAssistantSheet extends ConsumerStatefulWidget {
  const AiAssistantSheet({
    super.key,
    this.submaterialId,
    this.exerciseQuestionId,
    this.topicTitle,
  });

  final String? submaterialId;
  final String? exerciseQuestionId;
  final String? topicTitle;

  @override
  ConsumerState<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends ConsumerState<AiAssistantSheet> {
  static const Uuid _uuid = Uuid();

  final TextEditingController _questionController = TextEditingController();

  AiHintLevel _selectedLevel = AiHintLevel.konsepDasar;
  int? _remainingQuota;
  int _dailyLimit = 10;
  String? _usageDate;
  String? _quotaExceededUsageDate;
  bool _isQuotaExhausted = false;
  bool _isSubmitting = false;

  String? _pendingRequestId;
  String? _pendingFingerprint;
  String? _lastAttemptedQuestion;
  String? _lastSuccessfulQuestion;

  String? _replyAnswer;
  AiHintLevel? _replyLevel;
  String? _alreadyProcessedMessage;
  String? _errorMessage;
  bool _canRetryError = false;

  @override
  void initState() {
    super.initState();
    final initialQuota = ref.read(aiQuotaProvider).valueOrNull;
    if (initialQuota != null) {
      _remainingQuota = initialQuota.remainingQuota;
      _dailyLimit = initialQuota.dailyLimit;
      _usageDate = initialQuota.usageDate;
      _isQuotaExhausted = initialQuota.remainingQuota <= 0;
    }
  }

  @override
  void didUpdateWidget(covariant AiAssistantSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.submaterialId != widget.submaterialId ||
        oldWidget.exerciseQuestionId != widget.exerciseQuestionId) {
      _pendingRequestId = null;
      _pendingFingerprint = null;
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  String _fingerprint({
    required String question,
    required AiHintLevel hintLevel,
  }) {
    return jsonEncode(<String, Object?>{
      'exercise_question_id': widget.exerciseQuestionId,
      'hint_level': hintLevel.level,
      'question': question,
      'submaterial_id': widget.submaterialId,
    });
  }

  String _resolveRequestId(String fingerprint) {
    if (_pendingRequestId != null && _pendingFingerprint == fingerprint) {
      return _pendingRequestId!;
    }
    final nextId = _uuid.v4();
    _pendingRequestId = nextId;
    _pendingFingerprint = fingerprint;
    return nextId;
  }

  bool _isRetryableAiError(PlasApiException error) {
    return error.isRetryable ||
        error.code == ApiErrorCodes.aiServiceError ||
        error.code == ApiErrorCodes.aiTimeout;
  }

  Future<void> _sendCurrentQuestion({String? questionOverride}) async {
    if (_isSubmitting || _isQuotaExhausted) return;

    final rawQuestion = (questionOverride ?? _questionController.text).trim();
    if (rawQuestion.isEmpty) {
      setState(() {
        _errorMessage = 'Tuliskan pertanyaan terlebih dahulu sebelum mengirim.';
        _canRetryError = false;
      });
      return;
    }

    await _executeAsk(question: rawQuestion, level: _selectedLevel);
  }

  Future<void> _requestNextLevelHint() async {
    if (_isSubmitting || _isQuotaExhausted || _selectedLevel.level >= 3) {
      return;
    }

    final nextLevel = AiHintLevel.fromValue(_selectedLevel.level + 1);
    final typedQuestion = _questionController.text.trim();
    final topic = widget.topicTitle?.trim();
    final effectiveQuestion = typedQuestion.isNotEmpty
        ? typedQuestion
        : (_lastSuccessfulQuestion?.trim().isNotEmpty == true
            ? _lastSuccessfulQuestion!.trim()
            : 'Minta petunjuk ${nextLevel.label}${topic != null && topic.isNotEmpty ? ' untuk topik $topic' : ''}.');

    setState(() {
      _selectedLevel = nextLevel;
    });

    await _executeAsk(question: effectiveQuestion, level: nextLevel);
  }

  Future<void> _executeAsk({
    required String question,
    required AiHintLevel level,
  }) async {
    final fingerprint = _fingerprint(question: question, hintLevel: level);
    final requestId = _resolveRequestId(fingerprint);

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _canRetryError = false;
      _alreadyProcessedMessage = null;
      _lastAttemptedQuestion = question;
    });

    try {
      final response = await ref.read(plasRepositoryProvider).askAi(
            request: AiAskRequestDto(
              question: question,
              submaterialId: widget.submaterialId,
              exerciseQuestionId: widget.exerciseQuestionId,
              hintLevel: level,
            ),
            requestId: requestId,
          );
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _errorMessage = null;
        _canRetryError = false;
        _pendingRequestId = null;
        _pendingFingerprint = null;
        _remainingQuota = response.remainingQuota;
        _isQuotaExhausted = response.remainingQuota <= 0;

        if (response.status == AiAskStatus.alreadyProcessed) {
          _alreadyProcessedMessage =
              'Permintaan ini telah diproses sebelumnya.';
          if (response.answer != null && response.answer!.trim().isNotEmpty) {
            _replyAnswer = response.answer;
            _replyLevel = response.hintLevel ?? level;
          }
        } else {
          _alreadyProcessedMessage = null;
          _replyAnswer = response.answer;
          _replyLevel = response.hintLevel ?? level;
          _lastSuccessfulQuestion = question;
        }
      });

      ref.invalidate(aiQuotaProvider);
      ref.invalidate(progressSummaryProvider);
    } on PlasApiException catch (error) {
      if (!mounted) return;

      if (error.code == ApiErrorCodes.quotaExceeded) {
        setState(() {
          _isSubmitting = false;
          _remainingQuota = 0;
          _isQuotaExhausted = true;
          _quotaExceededUsageDate =
              _usageDate ?? ref.read(aiQuotaProvider).valueOrNull?.usageDate ?? '';
          _errorMessage = null;
          _canRetryError = false;
          _pendingRequestId = null;
          _pendingFingerprint = null;
        });
        ref.invalidate(aiQuotaProvider);
        ref.invalidate(progressSummaryProvider);
        return;
      }

      final retryable = _isRetryableAiError(error);
      setState(() {
        _isSubmitting = false;
        _errorMessage = error.message;
        _canRetryError = retryable;
        if (!retryable) {
          _pendingRequestId = null;
          _pendingFingerprint = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = plasErrorMessage(ApiErrorCodes.serverError);
        _canRetryError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AiQuotaDto>>(aiQuotaProvider, (_, next) {
      next.whenData((quota) {
        if (!mounted) return;
        setState(() {
          _dailyLimit = quota.dailyLimit;
          _usageDate = quota.usageDate;
          if (_quotaExceededUsageDate != null &&
              (_quotaExceededUsageDate!.isEmpty ||
                  quota.usageDate == _quotaExceededUsageDate) &&
              quota.remainingQuota > 0) {
            _remainingQuota = 0;
            _isQuotaExhausted = true;
            return;
          }
          _quotaExceededUsageDate = null;
          _remainingQuota = quota.remainingQuota;
          _isQuotaExhausted = quota.remainingQuota <= 0;
        });
      });
    });

    final quotaAsync = ref.watch(aiQuotaProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final effectiveRemaining =
        _remainingQuota ?? quotaAsync.valueOrNull?.remainingQuota;
    final effectiveLimit =
        quotaAsync.valueOrNull?.dailyLimit ?? _dailyLimit;
    final isQuotaOut = _isQuotaExhausted ||
        (effectiveRemaining != null && effectiveRemaining <= 0);
    final canRequestNextLevel =
        _selectedLevel.level < 3 && !isQuotaOut && (effectiveRemaining ?? 1) > 0;
    final topic = widget.topicTitle?.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          key: const ValueKey('ai_assistant_sheet'),
          decoration: const BoxDecoration(
            color: PlasColors.bgSurface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(PlasRadii.xl),
            ),
            boxShadow: PlasShadows.overlay,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  PlasSpacing.space5,
                  PlasSpacing.space4,
                  PlasSpacing.space3,
                  PlasSpacing.space3,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const OwlBracketMascot(
                      size: 40,
                      semanticLabel: 'Maskot Owl Bracket AI Learning Assistant',
                    ),
                    const SizedBox(width: PlasSpacing.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Learning Assistant',
                            style: PlasTypography.heading,
                          ),
                          const SizedBox(height: PlasSpacing.space1),
                          const Text(
                            'Socratic Mode',
                            style: PlasTypography.caption,
                          ),
                          if (topic != null && topic.isNotEmpty) ...[
                            const SizedBox(height: PlasSpacing.space2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: PlasSpacing.space2,
                                vertical: PlasSpacing.space1,
                              ),
                              decoration: BoxDecoration(
                                color: PlasColors.brandTint,
                                borderRadius:
                                    BorderRadius.circular(PlasRadii.sm),
                                border: Border.all(
                                  color: PlasColors.brandPrimary,
                                ),
                              ),
                              child: Text(
                                topic,
                                style: PlasTypography.caption.copyWith(
                                  color: PlasColors.brandHover,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('ai_close_button'),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Symbols.close,
                        size: 22,
                        color: PlasColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: PlasColors.borderSubtle),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(PlasSpacing.space5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildQuotaSection(
                        quotaAsync: quotaAsync,
                        remaining: effectiveRemaining,
                        dailyLimit: effectiveLimit,
                      ),
                      const SizedBox(height: PlasSpacing.space3),
                      Container(
                        key: const ValueKey('ai_socratic_callout'),
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
                                'Asisten membimbing dengan pertanyaan Socratic bertahap tanpa membocorkan kunci jawaban langsung.',
                                style: PlasTypography.body.copyWith(
                                  color: PlasColors.warningText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: PlasSpacing.space4),
                      const Text(
                        'Tingkat Petunjuk Socratic',
                        style: PlasTypography.label,
                      ),
                      const SizedBox(height: PlasSpacing.space2),
                      _SocraticLevelSelector(
                        selectedLevel: _selectedLevel,
                        enabled: !_isSubmitting,
                        onSelected: (level) {
                          setState(() {
                            _selectedLevel = level;
                            _errorMessage = null;
                            _canRetryError = false;
                          });
                        },
                      ),
                      if (isQuotaOut) ...[
                        const SizedBox(height: PlasSpacing.space4),
                        Container(
                          key: const ValueKey('ai_quota_exhausted_banner'),
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
                                  plasErrorMessage(ApiErrorCodes.quotaExceeded),
                                  style: PlasTypography.body.copyWith(
                                    color: PlasColors.errorText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: PlasSpacing.space4),
                      TextField(
                        key: const ValueKey('ai_question_field'),
                        controller: _questionController,
                        enabled: !isQuotaOut && !_isSubmitting,
                        minLines: 2,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          labelText: 'Pertanyaan untuk Asisten',
                          hintText:
                              'Tulis bagian konsep atau kode TypeScript yang ingin ditanyakan...',
                          filled: true,
                          fillColor: isQuotaOut
                              ? PlasColors.disabledBg
                              : PlasColors.bgSurface,
                        ),
                        onChanged: (_) {
                          if (_errorMessage != null) {
                            setState(() {
                              _errorMessage = null;
                              _canRetryError = false;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: PlasSpacing.space3),
                      ElevatedButton(
                        key: const ValueKey('ai_send_button'),
                        onPressed: (!isQuotaOut && !_isSubmitting)
                            ? () => _sendCurrentQuestion()
                            : null,
                        child: Text(
                          _isSubmitting
                              ? 'Menyusun Petunjuk...'
                              : 'Kirim Pertanyaan',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (canRequestNextLevel) ...[
                        const SizedBox(height: PlasSpacing.space2),
                        OutlinedButton(
                          key: const ValueKey('ai_next_level_button'),
                          onPressed:
                              !_isSubmitting ? _requestNextLevelHint : null,
                          child: const Text(
                            'Minta Petunjuk Level berikutnya ->',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      if (_isSubmitting) ...[
                        const SizedBox(height: PlasSpacing.space4),
                        const PlasLoadingSkeleton(
                          message: 'Menyusun petunjuk Socratic AI...',
                          cardCount: 1,
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: PlasSpacing.space4),
                        PlasErrorView(
                          key: const ValueKey('ai_error_banner'),
                          message: _errorMessage!,
                          actionLabel: 'Coba Lagi',
                          onRetry: _canRetryError && !isQuotaOut && !_isSubmitting
                              ? () => _sendCurrentQuestion(
                                    questionOverride: _lastAttemptedQuestion,
                                  )
                              : null,
                        ),
                      ],
                      if (_alreadyProcessedMessage != null ||
                          _replyAnswer != null) ...[
                        const SizedBox(height: PlasSpacing.space4),
                        _buildResponseCard(),
                      ],
                      const SizedBox(height: PlasSpacing.space4),
                      OutlinedButton(
                        key: const ValueKey('ai_footer_close_button'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Tutup', textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuotaSection({
    required AsyncValue<AiQuotaDto> quotaAsync,
    required int? remaining,
    required int dailyLimit,
  }) {
    if (remaining != null) {
      final variant = remaining <= 0
          ? PlasBadgeVariant.error
          : (remaining <= 3
              ? PlasBadgeVariant.warning
              : PlasBadgeVariant.brand);
      return Align(
        alignment: Alignment.centerLeft,
        child: PlasStatusBadge(
          key: const ValueKey('ai_quota_badge'),
          label: 'Sisa kuota hari ini: $remaining/$dailyLimit',
          variant: variant,
          icon: remaining <= 0 ? Symbols.error : Symbols.schedule,
        ),
      );
    }

    if (quotaAsync.hasError) {
      final error = quotaAsync.error;
      final message = error is PlasApiException
          ? error.message
          : plasErrorMessage(ApiErrorCodes.serverError);
      return PlasErrorView(
        title: 'Gagal Memuat Kuota AI',
        message: message,
        onRetry: () => ref.invalidate(aiQuotaProvider),
      );
    }

    return const PlasLoadingSkeleton(
      message: 'Memeriksa sisa kuota AI hari ini...',
      cardCount: 1,
    );
  }

  Widget _buildResponseCard() {
    final level = _replyLevel ?? _selectedLevel;
    return Container(
      key: const ValueKey('ai_response_box'),
      padding: const EdgeInsets.all(PlasSpacing.space4),
      decoration: BoxDecoration(
        color: PlasColors.brandTint,
        borderRadius: BorderRadius.circular(PlasRadii.lg),
        border: Border.all(color: PlasColors.brandPrimary),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: PlasSpacing.space2,
            runSpacing: PlasSpacing.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Petunjuk Level ${level.level}: ${level.label}',
                style: PlasTypography.label.copyWith(
                  color: PlasColors.brandHover,
                ),
              ),
              if (_alreadyProcessedMessage != null)
                PlasStatusBadge(
                  key: const ValueKey('ai_already_processed_note'),
                  label: _alreadyProcessedMessage!,
                  variant: PlasBadgeVariant.brand,
                  icon: Symbols.info,
                ),
            ],
          ),
          if (_replyAnswer != null && _replyAnswer!.trim().isNotEmpty) ...[
            const SizedBox(height: PlasSpacing.space3),
            PlasMarkdownView(
              markdown: _replyAnswer!,
              selectableCode: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _SocraticLevelSelector extends StatelessWidget {
  const _SocraticLevelSelector({
    required this.selectedLevel,
    required this.enabled,
    required this.onSelected,
  });

  final AiHintLevel selectedLevel;
  final bool enabled;
  final ValueChanged<AiHintLevel> onSelected;

  IconData _iconForLevel(AiHintLevel level) {
    return switch (level) {
      AiHintLevel.konsepDasar => Symbols.menu_book,
      AiHintLevel.strategi => Symbols.route,
      AiHintLevel.penalaran => Symbols.account_tree,
    };
  }

  String _labelForLevel(AiHintLevel level) {
    return '${level.level}. ${level.label}';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final useEqualRow = constraints.maxWidth >= 480 && textScale <= 1.2;

        if (useEqualRow) {
          return Row(
            children: [
              for (var i = 0; i < AiHintLevel.values.length; i++) ...[
                if (i > 0) const SizedBox(width: PlasSpacing.space2),
                Expanded(
                  child: _LevelTabPill(
                    key: ValueKey('ai_level_tab_${AiHintLevel.values[i].level}'),
                    label: _labelForLevel(AiHintLevel.values[i]),
                    icon: _iconForLevel(AiHintLevel.values[i]),
                    selected: selectedLevel == AiHintLevel.values[i],
                    enabled: enabled,
                    onTap: () => onSelected(AiHintLevel.values[i]),
                  ),
                ),
              ],
            ],
          );
        }

        return Wrap(
          spacing: PlasSpacing.space2,
          runSpacing: PlasSpacing.space2,
          children: [
            for (final level in AiHintLevel.values)
              _LevelTabPill(
                key: ValueKey('ai_level_tab_${level.level}'),
                label: _labelForLevel(level),
                icon: _iconForLevel(level),
                selected: selectedLevel == level,
                enabled: enabled,
                onTap: () => onSelected(level),
              ),
          ],
        );
      },
    );
  }
}

class _LevelTabPill extends StatelessWidget {
  const _LevelTabPill({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
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
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(PlasRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(PlasRadii.md),
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: PlasSpacing.space3,
                vertical: PlasSpacing.space3,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PlasRadii.md),
                border: Border.all(
                  color: borderColor,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: fgColor),
                  const SizedBox(width: PlasSpacing.space2),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: PlasTypography.label.copyWith(color: fgColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
