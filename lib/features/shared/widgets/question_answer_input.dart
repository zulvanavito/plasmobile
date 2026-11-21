import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/core/utils/levenshtein.dart';
import 'package:plasmobile/data/dto/exercise_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/shared/widgets/plas_markdown_view.dart';

class QuestionAnswerInput extends StatefulWidget {
  const QuestionAnswerInput({
    super.key,
    required this.questionType,
    this.options = const <QuestionOptionDto>[],
    this.value,
    required this.onChanged,
    this.enabled = true,
    this.fieldHint,
  });

  final QuestionType questionType;
  final List<QuestionOptionDto> options;
  final StudentAnswer? value;
  final ValueChanged<StudentAnswer?> onChanged;
  final bool enabled;
  final String? fieldHint;

  @override
  State<QuestionAnswerInput> createState() => _QuestionAnswerInputState();
}

class _QuestionAnswerInputState extends State<QuestionAnswerInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initialText = widget.value is FibAnswer
        ? (widget.value! as FibAnswer).value
        : '';
    _controller = TextEditingController(text: initialText);
  }

  @override
  void didUpdateWidget(covariant QuestionAnswerInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.questionType != QuestionType.fib) {
      if (_controller.text.isNotEmpty) {
        _syncControllerText('');
      }
      return;
    }

    final incomingText = widget.value is FibAnswer
        ? (widget.value! as FibAnswer).value
        : '';
    if (oldWidget.questionType != widget.questionType) {
      _syncControllerText(incomingText);
      return;
    }

    if (widget.value != oldWidget.value) {
      if (widget.value is FibAnswer) {
        if (_controller.text != incomingText) {
          _syncControllerText(incomingText);
        }
      } else if (widget.value == null && oldWidget.value != null) {
        _syncControllerText('');
      }
    }
  }

  void _syncControllerText(String nextText) {
    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleFibChanged(String rawText) {
    setState(() {});
    if (rawText.trim().isEmpty) {
      widget.onChanged(null);
    } else {
      widget.onChanged(FibAnswer(rawText));
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.questionType) {
      QuestionType.mc => _buildMcInput(),
      QuestionType.tf => _buildTfInput(),
      QuestionType.fib => _buildFibInput(),
    };
  }

  Widget _buildMcInput() {
    final selectedOptionId = widget.value is McAnswer
        ? (widget.value! as McAnswer).optionId
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.options.length; i++) ...[
          if (i > 0) const SizedBox(height: PlasSpacing.space3),
          _SelectableAnswerCard(
            cardKey: ValueKey('question_mc_option_${widget.options[i].optionId}'),
            label: widget.options[i].text,
            selected: selectedOptionId == widget.options[i].optionId,
            enabled: widget.enabled,
            useInlineMarkdown: true,
            onTap: () => widget.onChanged(
              McAnswer(widget.options[i].optionId),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTfInput() {
    final selectedBool = widget.value is TfAnswer
        ? (widget.value! as TfAnswer).value
        : null;

    final trueCard = _SelectableAnswerCard(
      cardKey: const ValueKey('question_tf_true'),
      label: 'Benar',
      selected: selectedBool == true,
      enabled: widget.enabled,
      useInlineMarkdown: false,
      onTap: () => widget.onChanged(const TfAnswer(true)),
    );
    final falseCard = _SelectableAnswerCard(
      cardKey: const ValueKey('question_tf_false'),
      label: 'Salah',
      selected: selectedBool == false,
      enabled: widget.enabled,
      useInlineMarkdown: false,
      onTap: () => widget.onChanged(const TfAnswer(false)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final useEqualRow = constraints.maxWidth >= 280 && textScale < 1.5;

        if (useEqualRow) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: trueCard),
              const SizedBox(width: PlasSpacing.space3),
              Expanded(child: falseCard),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            trueCard,
            const SizedBox(height: PlasSpacing.space3),
            falseCard,
          ],
        );
      },
    );
  }

  Widget _buildFibInput() {
    final len = _controller.text.length;
    final hint = widget.fieldHint?.trim();
    final helperText = (hint != null && hint.isNotEmpty)
        ? hint
        : 'Ketik jawaban singkat Anda (maksimal 255 karakter).';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('question_fib_field'),
          controller: _controller,
          enabled: widget.enabled,
          maxLength: kMaxFibLength,
          minLines: 1,
          maxLines: 3,
          autocorrect: false,
          enableSuggestions: false,
          style: PlasTypography.code.copyWith(
            color: widget.enabled
                ? PlasColors.textPrimary
                : PlasColors.disabledText,
          ),
          buildCounter: (
            _, {
            required currentLength,
            required isFocused,
            maxLength,
          }) =>
              null,
          decoration: InputDecoration(
            hintText: 'Tulis jawaban kode atau kata kunci di sini...',
            hintStyle: PlasTypography.body.copyWith(
              color: PlasColors.textMuted,
            ),
            filled: true,
            fillColor: widget.enabled
                ? PlasColors.bgSurface
                : PlasColors.disabledBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: PlasSpacing.space4,
              vertical: PlasSpacing.space3,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PlasRadii.md),
              borderSide: const BorderSide(color: PlasColors.borderInteractive),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PlasRadii.md),
              borderSide: const BorderSide(color: PlasColors.borderInteractive),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PlasRadii.md),
              borderSide: const BorderSide(
                color: PlasColors.brandPrimary,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PlasRadii.md),
              borderSide: const BorderSide(color: PlasColors.disabledBorder),
            ),
          ),
          onChanged: _handleFibChanged,
        ),
        const SizedBox(height: PlasSpacing.space2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                helperText,
                style: PlasTypography.caption,
              ),
            ),
            const SizedBox(width: PlasSpacing.space2),
            Text(
              '$len / $kMaxFibLength',
              key: const ValueKey('question_fib_counter'),
              style: PlasTypography.codeMeta.copyWith(
                color: PlasColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SelectableAnswerCard extends StatelessWidget {
  const _SelectableAnswerCard({
    required this.cardKey,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.useInlineMarkdown,
    required this.onTap,
  });

  final Key cardKey;
  final String label;
  final bool selected;
  final bool enabled;
  final bool useInlineMarkdown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(PlasRadii.md);
    final Color bgColor;
    final Color borderColor;
    final Color textColor;

    if (!enabled && !selected) {
      bgColor = PlasColors.disabledBg;
      borderColor = PlasColors.disabledBorder;
      textColor = PlasColors.disabledText;
    } else if (selected) {
      bgColor = PlasColors.brandTint;
      borderColor = PlasColors.brandPrimary;
      textColor = PlasColors.textPrimary;
    } else {
      bgColor = PlasColors.bgSurface;
      borderColor = PlasColors.borderInteractive;
      textColor = PlasColors.textPrimary;
    }

    final textStyle = PlasTypography.body.copyWith(
      color: textColor,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
    );

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: Container(
        key: cardKey,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: radius,
          border: Border.all(
            color: borderColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            focusColor: const Color(0x1F1D4ED8),
            overlayColor: const WidgetStatePropertyAll(Color(0x141D4ED8)),
            onTap: enabled ? onTap : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PlasSpacing.space4,
                  vertical: PlasSpacing.space3,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _RadioIndicator(selected: selected, enabled: enabled),
                    const SizedBox(width: PlasSpacing.space3),
                    Expanded(
                      child: useInlineMarkdown
                          ? Text.rich(
                              TextSpan(
                                style: textStyle,
                                children: buildInlineSpans(label, textStyle),
                              ),
                            )
                          : Text(label, style: textStyle),
                    ),
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

class _RadioIndicator extends StatelessWidget {
  const _RadioIndicator({required this.selected, required this.enabled});

  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ringColor = selected
        ? PlasColors.brandPrimary
        : (enabled ? PlasColors.borderInteractive : PlasColors.disabledText);

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? PlasColors.bgSurface : Colors.transparent,
        border: Border.all(
          color: ringColor,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: PlasColors.brandPrimary,
              ),
            )
          : null,
    );
  }
}
