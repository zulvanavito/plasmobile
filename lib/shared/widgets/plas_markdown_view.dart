import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/shared/widgets/plas_code_block.dart';

sealed class PlasMarkdownBlock {
  const PlasMarkdownBlock();
}

final class HeadingBlock extends PlasMarkdownBlock {
  const HeadingBlock({required this.level, required this.text});

  final int level;
  final String text;
}

final class ParagraphBlock extends PlasMarkdownBlock {
  const ParagraphBlock({required this.text});

  final String text;
}

final class BulletListBlock extends PlasMarkdownBlock {
  const BulletListBlock({required this.items});

  final List<String> items;
}

final class OrderedListBlock extends PlasMarkdownBlock {
  const OrderedListBlock({required this.items});

  final List<String> items;
}

final class CodeFenceBlock extends PlasMarkdownBlock {
  const CodeFenceBlock({
    required this.code,
    this.language,
    this.filename,
  });

  final String code;
  final String? language;
  final String? filename;
}

final RegExp _fenceClosePattern = RegExp(r'^\s*`{3,}\s*$');
final RegExp _fenceTitlePattern = RegExp(r'''title=(?:"([^"]+)"|'([^']+)')''');
final RegExp _orderedListPattern = RegExp(r'^(\d+)\.\s+(.*)$');
final RegExp _inlineSpanPattern = RegExp(
  r'`([^`]+)`|\*\*(.+?)\*\*|(?<!\*)\*([^*]+?)\*(?!\*)',
);

bool _isHeadingLine(String trimmed) {
  return trimmed.startsWith('### ') ||
      trimmed.startsWith('## ') ||
      trimmed.startsWith('# ');
}

bool _isBulletLine(String trimmed) {
  return trimmed.startsWith('- ') || trimmed.startsWith('* ');
}

bool _isSpecialLine(String line) {
  final trimmed = line.trimLeft();
  return trimmed.startsWith('```') ||
      _isHeadingLine(trimmed) ||
      _isBulletLine(trimmed) ||
      _orderedListPattern.hasMatch(trimmed);
}

({String? language, String? filename}) _parseFenceInfo(String info) {
  var remaining = info.trim();
  if (remaining.isEmpty) return (language: null, filename: null);

  String? filename;
  final titleMatch = _fenceTitlePattern.firstMatch(remaining);
  if (titleMatch != null) {
    filename = titleMatch.group(1) ?? titleMatch.group(2);
    remaining = remaining.replaceFirst(_fenceTitlePattern, '').trim();
  }

  final tokens = remaining.isEmpty
      ? const <String>[]
      : remaining.split(RegExp(r'\s+'));
  final language = tokens.isNotEmpty ? tokens.first : null;
  if (filename == null && tokens.length >= 2 && tokens[1].contains('.')) {
    filename = tokens[1];
  }

  return (language: language, filename: filename);
}

List<PlasMarkdownBlock> parseMarkdownBlocks(String raw) {
  if (raw.trim().isEmpty) return const <PlasMarkdownBlock>[];

  final lines = raw.replaceAll('\r\n', '\n').split('\n');
  final blocks = <PlasMarkdownBlock>[];

  var i = 0;
  while (i < lines.length) {
    final trimmed = lines[i].trimLeft();
    if (trimmed.isEmpty) {
      i++;
      continue;
    }

    if (trimmed.startsWith('```')) {
      final info = _parseFenceInfo(trimmed.substring(3));
      final codeLines = <String>[];
      i++;
      while (i < lines.length) {
        if (_fenceClosePattern.hasMatch(lines[i])) {
          i++;
          break;
        }
        codeLines.add(lines[i]);
        i++;
      }
      blocks.add(
        CodeFenceBlock(
          code: codeLines.join('\n'),
          language: info.language,
          filename: info.filename,
        ),
      );
      continue;
    }

    if (trimmed.startsWith('### ')) {
      blocks.add(HeadingBlock(level: 3, text: trimmed.substring(4).trim()));
      i++;
      continue;
    }
    if (trimmed.startsWith('## ')) {
      blocks.add(HeadingBlock(level: 2, text: trimmed.substring(3).trim()));
      i++;
      continue;
    }
    if (trimmed.startsWith('# ')) {
      blocks.add(HeadingBlock(level: 1, text: trimmed.substring(2).trim()));
      i++;
      continue;
    }

    if (_isBulletLine(trimmed)) {
      final items = <String>[];
      while (i < lines.length && _isBulletLine(lines[i].trimLeft())) {
        items.add(lines[i].trimLeft().substring(2).trim());
        i++;
      }
      blocks.add(BulletListBlock(items: items));
      continue;
    }

    if (_orderedListPattern.hasMatch(trimmed)) {
      final items = <String>[];
      while (i < lines.length) {
        final match = _orderedListPattern.firstMatch(lines[i].trimLeft());
        if (match == null) break;
        items.add(match.group(2)!.trim());
        i++;
      }
      blocks.add(OrderedListBlock(items: items));
      continue;
    }

    final paragraphLines = <String>[];
    while (i < lines.length &&
        lines[i].trim().isNotEmpty &&
        !_isSpecialLine(lines[i])) {
      paragraphLines.add(lines[i].trim());
      i++;
    }
    blocks.add(ParagraphBlock(text: paragraphLines.join(' ')));
  }

  return blocks;
}

/// Parses inline markdown (`code`, **bold**, *italic*) into [TextSpan]s.
List<TextSpan> buildInlineSpans(String text, TextStyle baseStyle) {
  if (text.isEmpty) return const <TextSpan>[];

  final spans = <TextSpan>[];
  var cursor = 0;

  for (final match in _inlineSpanPattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(
        TextSpan(text: text.substring(cursor, match.start), style: baseStyle),
      );
    }

    final codeGroup = match.group(1);
    final boldGroup = match.group(2);
    final italicGroup = match.group(3);

    if (codeGroup != null) {
      spans.add(
        TextSpan(
          text: codeGroup,
          style: PlasTypography.code.copyWith(
            color: PlasColors.textPrimary,
            backgroundColor: PlasColors.bgSubtle,
          ),
        ),
      );
    } else if (boldGroup != null) {
      spans.add(
        TextSpan(
          text: boldGroup,
          style: baseStyle.copyWith(fontWeight: FontWeight.w700),
        ),
      );
    } else if (italicGroup != null) {
      spans.add(
        TextSpan(
          text: italicGroup,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ),
      );
    }

    cursor = match.end;
  }

  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
  }

  return spans;
}

class PlasMarkdownView extends StatelessWidget {
  const PlasMarkdownView({
    super.key,
    required this.markdown,
    this.selectableCode = true,
  });

  final String markdown;
  final bool selectableCode;

  double _gapBetween(PlasMarkdownBlock prev, PlasMarkdownBlock next) {
    if (prev is CodeFenceBlock ||
        next is CodeFenceBlock ||
        next is HeadingBlock) {
      return PlasSpacing.space4;
    }
    return PlasSpacing.space3;
  }

  Widget _buildBlock(PlasMarkdownBlock block) {
    return switch (block) {
      HeadingBlock(:final level, :final text) => _buildHeading(level, text),
      ParagraphBlock(:final text) => _buildInlineText(text, PlasTypography.body),
      BulletListBlock(:final items) => _buildList(items, ordered: false),
      OrderedListBlock(:final items) => _buildList(items, ordered: true),
      CodeFenceBlock(:final code, :final language, :final filename) =>
        PlasCodeBlock(
          code: code,
          filename: filename,
          languageLabel: language,
          selectable: selectableCode,
        ),
    };
  }

  Widget _buildHeading(int level, String text) {
    final style = switch (level) {
      1 => PlasTypography.display,
      2 => PlasTypography.heading,
      _ => PlasTypography.title,
    };
    return _buildInlineText(text, style);
  }

  Widget _buildInlineText(String text, TextStyle style) {
    return Text.rich(
      TextSpan(
        style: style,
        children: buildInlineSpans(text, style),
      ),
    );
  }

  Widget _buildList(List<String> items, {required bool ordered}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: PlasSpacing.space2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: PlasSpacing.space2),
                child: Text(
                  ordered ? '${i + 1}.' : '\u2022',
                  style: PlasTypography.body.copyWith(
                    fontWeight: ordered ? FontWeight.w600 : FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: _buildInlineText(items[i], PlasTypography.body),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final blocks = parseMarkdownBlocks(markdown);
    if (blocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: _gapBetween(blocks[i - 1], blocks[i])),
          _buildBlock(blocks[i]),
        ],
      ],
    );
  }
}
