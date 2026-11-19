import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/theme/plas_theme.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/shared/widgets/plas_code_block.dart';

Widget _wrap(
  Widget child, {
  double width = 390,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    theme: buildPlasTheme(),
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 844),
        textScaler: textScaler,
      ),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

void main() {
  group('tokenizeTypeScriptLine', () {
    test('returns empty list for empty line', () {
      expect(tokenizeTypeScriptLine(''), isEmpty);
    });

    test('assigns keyword, type, string, number, and comment colors', () {
      const line =
          'const user: UserProfile = "andi"; // age: number = 42, ok = true';
      final spans = tokenizeTypeScriptLine(line);

      TextSpan spanFor(String text) {
        return spans.firstWhere((span) => span.text == text);
      }

      expect(spanFor('const').style?.color, PlasColors.codeKeyword);
      expect(spanFor('UserProfile').style?.color, PlasColors.codeType);
      expect(spanFor('"andi"').style?.color, PlasColors.codeString);
      expect(
        spanFor('// age: number = 42, ok = true').style?.color,
        PlasColors.codeComment,
      );
    });

    test('highlights built-in types, hex/float numbers, booleans, and escapes', () {
      const line =
          r"let count: number = 0xFF + 3.5; const msg: string = 'it\'s'; return false;";
      final spans = tokenizeTypeScriptLine(line);

      TextSpan spanFor(String text) {
        return spans.firstWhere((span) => span.text == text);
      }

      expect(spanFor('let').style?.color, PlasColors.codeKeyword);
      expect(spanFor('number').style?.color, PlasColors.codeType);
      expect(spanFor('0xFF').style?.color, PlasColors.codeNumber);
      expect(spanFor('3.5').style?.color, PlasColors.codeNumber);
      expect(spanFor('const').style?.color, PlasColors.codeKeyword);
      expect(spanFor('string').style?.color, PlasColors.codeType);
      expect(spanFor(r"'it\'s'").style?.color, PlasColors.codeString);
      expect(spanFor('return').style?.color, PlasColors.codeKeyword);
      expect(spanFor('false').style?.color, PlasColors.codeNumber);
    });

    test('does not treat // inside string literal as comment', () {
      const line = 'const url = "https://plas.dev/ts";';
      final spans = tokenizeTypeScriptLine(line);

      expect(
        spans.any(
          (span) =>
              span.text == '"https://plas.dev/ts"' &&
              span.style?.color == PlasColors.codeString,
        ),
        isTrue,
      );
      expect(
        spans.any((span) => span.style?.color == PlasColors.codeComment),
        isFalse,
      );
    });

    test('does not treat all-uppercase constants as PascalCase types', () {
      const line = 'const MAX_LIMIT: Promise<void> = get(API);';
      final spans = tokenizeTypeScriptLine(line);

      expect(
        spans.any(
          (span) =>
              span.text == 'Promise' && span.style?.color == PlasColors.codeType,
        ),
        isTrue,
      );
      expect(
        spans.any(
          (span) =>
              span.text == 'void' && span.style?.color == PlasColors.codeType,
        ),
        isTrue,
      );
      expect(
        spans.any(
          (span) =>
              span.text?.contains('MAX_LIMIT') == true &&
              span.style?.color == PlasColors.codeType,
        ),
        isFalse,
      );
    });
  });

  group('PlasCodeBlock widget', () {
    testWidgets('falls back to TYPESCRIPT when languageLabel is omitted or blank', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const PlasCodeBlock(code: 'const x = 1;')),
      );

      expect(find.text('TYPESCRIPT'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(const PlasCodeBlock(code: 'const x = 1;', languageLabel: '   ')),
      );

      expect(find.text('TYPESCRIPT'), findsOneWidget);
    });

    testWidgets('renders uppercased languageLabel and filename when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const PlasCodeBlock(
            code: 'const x = 1;',
            filename: 'contoh.ts',
            languageLabel: 'ts',
          ),
        ),
      );

      expect(find.text('contoh.ts'), findsOneWidget);
      expect(find.text('TS'), findsOneWidget);
    });

    testWidgets('renders line numbers when showLineNumbers is true and omits when false', (
      tester,
    ) async {
      const snippet = 'const a = 1;\nconst b = 2;\nconst c = 3;';

      await tester.pumpWidget(
        _wrap(const PlasCodeBlock(code: snippet, showLineNumbers: true)),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(const PlasCodeBlock(code: snippet, showLineNumbers: false)),
      );

      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(find.text('3'), findsNothing);
    });

    testWidgets('wraps code body in SelectionArea only when selectable is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const PlasCodeBlock(code: 'const a = 1;', selectable: false)),
      );
      expect(find.byType(SelectionArea), findsNothing);

      await tester.pumpWidget(
        _wrap(const PlasCodeBlock(code: 'const a = 1;', selectable: true)),
      );
      expect(find.byType(SelectionArea), findsOneWidget);
    });

    testWidgets(
      'renders 150-char line at 390px and 2.0x text scale without overflow and scrolls horizontally',
      (tester) async {
        final longLine =
            'const veryLongIdentifierName = "${List.filled(120, 'a').join()}";';
        expect(longLine.length, greaterThanOrEqualTo(150));

        await tester.pumpWidget(
          _wrap(
            PlasCodeBlock(
              code: longLine,
              filename: 'very/long/nested/module/path/contoh_panjang.ts',
              languageLabel: 'typescript',
              selectable: true,
            ),
            width: 390,
            textScaler: const TextScaler.linear(2.0),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final scrollableFinder = find.byType(SingleChildScrollView);
        expect(scrollableFinder, findsOneWidget);

        final scrollWidget = tester.widget<SingleChildScrollView>(
          scrollableFinder,
        );
        expect(scrollWidget.scrollDirection, Axis.horizontal);

        await tester.drag(scrollableFinder, const Offset(-200, 0));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
