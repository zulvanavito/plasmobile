import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';

const Set<String> _tsKeywords = {
  'const',
  'let',
  'var',
  'function',
  'return',
  'if',
  'else',
  'for',
  'while',
  'do',
  'switch',
  'case',
  'break',
  'continue',
  'default',
  'type',
  'interface',
  'enum',
  'class',
  'extends',
  'implements',
  'new',
  'import',
  'export',
  'from',
  'as',
  'typeof',
  'keyof',
  'readonly',
  'async',
  'await',
  'try',
  'catch',
  'throw',
  'in',
  'of',
};

const Set<String> _tsLiteralNumbers = {
  'true',
  'false',
  'null',
  'undefined',
};

const Set<String> _tsBuiltinTypes = {
  'string',
  'number',
  'boolean',
  'void',
  'any',
  'unknown',
  'never',
  'object',
  'bigint',
  'symbol',
  'Array',
  'Promise',
  'Record',
};

final RegExp _hexLiteralPattern = RegExp(r'^0x[0-9a-fA-F]+');
final RegExp _decimalLiteralPattern = RegExp(r'^\d+(?:\.\d+)?');
final RegExp _pascalCasePattern = RegExp(r'^[A-Z][a-zA-Z0-9_]*$');
final RegExp _lowercasePattern = RegExp(r'[a-z]');

bool _isWordStart(int codeUnit) {
  return (codeUnit >= 65 && codeUnit <= 90) || // A-Z
      (codeUnit >= 97 && codeUnit <= 122) || // a-z
      codeUnit == 95 || // _
      codeUnit == 36; // $
}

bool _isDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;

bool _isWordChar(int codeUnit) => _isWordStart(codeUnit) || _isDigit(codeUnit);

bool _isPascalCaseType(String token) {
  return _pascalCasePattern.hasMatch(token) && _lowercasePattern.hasMatch(token);
}

Color _colorForIdentifier(String token) {
  if (_tsKeywords.contains(token)) return PlasColors.codeKeyword;
  if (_tsLiteralNumbers.contains(token)) return PlasColors.codeNumber;
  if (_tsBuiltinTypes.contains(token) || _isPascalCaseType(token)) {
    return PlasColors.codeType;
  }
  return PlasColors.codeText;
}

/// Tokenizes a single line of TypeScript/JavaScript code into colored [TextSpan]s
/// using [PlasColors] IDE dark syntax tokens.
List<TextSpan> tokenizeTypeScriptLine(String line) {
  if (line.isEmpty) return const <TextSpan>[];

  final spans = <TextSpan>[];
  final plainBuffer = StringBuffer();

  void flushPlain() {
    if (plainBuffer.isEmpty) return;
    spans.add(
      TextSpan(
        text: plainBuffer.toString(),
        style: PlasTypography.code,
      ),
    );
    plainBuffer.clear();
  }

  void addStyledToken(String text, Color color) {
    flushPlain();
    spans.add(
      TextSpan(
        text: text,
        style: PlasTypography.code.copyWith(color: color),
      ),
    );
  }

  var i = 0;
  while (i < line.length) {
    final codeUnit = line.codeUnitAt(i);

    // Single-line comment: consumes to end of line.
    if (codeUnit == 47 && i + 1 < line.length && line.codeUnitAt(i + 1) == 47) {
      addStyledToken(line.substring(i), PlasColors.codeComment);
      break;
    }

    // Quoted string literal: '...', "...", or `...` with backslash escapes.
    if (codeUnit == 39 || codeUnit == 34 || codeUnit == 96) {
      var j = i + 1;
      while (j < line.length) {
        final next = line.codeUnitAt(j);
        if (next == 92) {
          j = (j + 2 <= line.length) ? j + 2 : line.length;
        } else if (next == codeUnit) {
          j++;
          break;
        } else {
          j++;
        }
      }
      addStyledToken(line.substring(i, j), PlasColors.codeString);
      i = j;
      continue;
    }

    // Identifiers, keywords, types, and boolean/nullish literals.
    if (_isWordStart(codeUnit)) {
      var j = i + 1;
      while (j < line.length && _isWordChar(line.codeUnitAt(j))) {
        j++;
      }
      final token = line.substring(i, j);
      final color = _colorForIdentifier(token);
      if (color == PlasColors.codeText) {
        plainBuffer.write(token);
      } else {
        addStyledToken(token, color);
      }
      i = j;
      continue;
    }

    // Numeric literals (hex or decimal/float) at word boundaries.
    if (_isDigit(codeUnit) && (i == 0 || !_isWordChar(line.codeUnitAt(i - 1)))) {
      final slice = line.substring(i);
      final match =
          _hexLiteralPattern.firstMatch(slice) ??
          _decimalLiteralPattern.firstMatch(slice);
      if (match != null) {
        final end = i + match.end;
        if (end == line.length || !_isWordChar(line.codeUnitAt(end))) {
          addStyledToken(line.substring(i, end), PlasColors.codeNumber);
          i = end;
          continue;
        }
      }
    }

    plainBuffer.writeCharCode(codeUnit);
    i++;
  }

  flushPlain();
  return spans;
}

class PlasCodeBlock extends StatelessWidget {
  const PlasCodeBlock({
    super.key,
    required this.code,
    this.filename,
    this.languageLabel,
    this.showLineNumbers = true,
    this.selectable = false,
  });

  final String code;
  final String? filename;
  final String? languageLabel;
  final bool showLineNumbers;
  final bool selectable;

  List<String> _splitLines() {
    var normalized = code.replaceAll('\r\n', '\n');
    if (normalized.endsWith('\n')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized.split('\n');
  }

  @override
  Widget build(BuildContext context) {
    final lines = _splitLines();
    final rawFilename = filename?.trim();
    final resolvedFilename =
        (rawFilename != null && rawFilename.isNotEmpty) ? rawFilename : null;
    final rawLanguage = languageLabel?.trim();
    final resolvedLanguage = (rawLanguage != null && rawLanguage.isNotEmpty)
        ? rawLanguage.toUpperCase()
        : 'TYPESCRIPT';
    const metaColor = Color(0xFFCBD5E1);
    final metaStyle = PlasTypography.codeMeta.copyWith(color: metaColor);

    final codeColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          _CodeLine(spans: tokenizeTypeScriptLine(line)),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: PlasColors.codeBg,
        borderRadius: BorderRadius.circular(PlasRadii.lg),
        border: Border.all(color: PlasColors.codeHeader),
        boxShadow: PlasShadows.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ColoredBox(
            color: PlasColors.codeHeader,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PlasSpacing.space4,
                  vertical: PlasSpacing.space2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: resolvedFilename != null
                          ? Text(
                              resolvedFilename,
                              style: metaStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (resolvedFilename != null)
                      const SizedBox(width: PlasSpacing.space3)
                    else
                      const SizedBox(width: PlasSpacing.space2),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        heightFactor: 1.0,
                        child: Text(
                          resolvedLanguage,
                          style: metaStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: PlasSpacing.space3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showLineNumbers)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: PlasSpacing.space4,
                      right: PlasSpacing.space3,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < lines.length; i++)
                          Text(
                            '${i + 1}',
                            style: PlasTypography.code.copyWith(
                              color: PlasColors.codeComment,
                            ),
                            softWrap: false,
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: showLineNumbers ? 0 : PlasSpacing.space4,
                        right: PlasSpacing.space4,
                      ),
                      child: selectable
                          ? SelectionArea(child: codeColumn)
                          : codeColumn,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeLine extends StatelessWidget {
  const _CodeLine({required this.spans});

  final List<TextSpan> spans;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      spans.isEmpty ? const TextSpan(text: '') : TextSpan(children: spans),
      style: PlasTypography.code,
      softWrap: false,
    );
  }
}
