import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/theme/plas_theme.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/shared/widgets/plas_code_block.dart';
import 'package:plasmobile/shared/widgets/plas_markdown_view.dart';

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
        body: SingleChildScrollView(
          child: SizedBox(
            width: width,
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('parseMarkdownBlocks', () {
    test('parses headings, paragraphs, bullet/ordered lists, and code fences', () {
      const markdown = '# Judul Utama\r\n'
          '\r\n'
          '## Subjudul\r\n'
          '### Detail Kecil\r\n'
          '\r\n'
          'Baris pertama paragraf\r\n'
          'baris kedua paragraf.\r\n'
          '\r\n'
          '- Item satu\r\n'
          '* Item dua\r\n'
          '\r\n'
          '1. Langkah awal\r\n'
          '2. Langkah lanjut\r\n'
          '\r\n'
          '```ts title="contoh.ts"\r\n'
          'const nama: string = "Plas";\r\n'
          '```\r\n'
          '\r\n'
          '```typescript app.ts\r\n'
          'let umur: number = 20;\r\n'
          '```\r\n'
          '\r\n'
          '```\r\n'
          'plainCode();\r\n'
          '```';

      final blocks = parseMarkdownBlocks(markdown);

      expect(blocks, hasLength(9));

      expect(blocks[0], isA<HeadingBlock>());
      final h1 = blocks[0] as HeadingBlock;
      expect(h1.level, 1);
      expect(h1.text, 'Judul Utama');

      final h2 = blocks[1] as HeadingBlock;
      expect(h2.level, 2);
      expect(h2.text, 'Subjudul');

      final h3 = blocks[2] as HeadingBlock;
      expect(h3.level, 3);
      expect(h3.text, 'Detail Kecil');

      final para = blocks[3] as ParagraphBlock;
      expect(para.text, 'Baris pertama paragraf baris kedua paragraf.');

      final bullets = blocks[4] as BulletListBlock;
      expect(bullets.items, ['Item satu', 'Item dua']);

      final ordered = blocks[5] as OrderedListBlock;
      expect(ordered.items, ['Langkah awal', 'Langkah lanjut']);

      final fenceTitle = blocks[6] as CodeFenceBlock;
      expect(fenceTitle.language, 'ts');
      expect(fenceTitle.filename, 'contoh.ts');
      expect(fenceTitle.code, 'const nama: string = "Plas";');

      final fenceToken = blocks[7] as CodeFenceBlock;
      expect(fenceToken.language, 'typescript');
      expect(fenceToken.filename, 'app.ts');
      expect(fenceToken.code, 'let umur: number = 20;');

      final fencePlain = blocks[8] as CodeFenceBlock;
      expect(fencePlain.language, isNull);
      expect(fencePlain.filename, isNull);
      expect(fencePlain.code, 'plainCode();');
    });

    test('handles unclosed code fence safely until EOF', () {
      const markdown = '```ts\nconst x = 1;\nconst y = 2;';
      final blocks = parseMarkdownBlocks(markdown);

      expect(blocks, hasLength(1));
      final fence = blocks.first as CodeFenceBlock;
      expect(fence.language, 'ts');
      expect(fence.code, 'const x = 1;\nconst y = 2;');
    });
  });

  group('buildInlineSpans', () {
    test('styles inline code, bold, and italic spans cleanly', () {
      final spans = buildInlineSpans(
        'Gunakan `let` untuk **variabel** yang *berubah*.',
        PlasTypography.body,
      );

      final codeSpan = spans.firstWhere((s) => s.text == 'let');
      expect(codeSpan.style?.fontFamily, PlasTypography.fontMono);
      expect(codeSpan.style?.color, PlasColors.textPrimary);
      expect(codeSpan.style?.backgroundColor, PlasColors.bgSubtle);

      final boldSpan = spans.firstWhere((s) => s.text == 'variabel');
      expect(boldSpan.style?.fontWeight, FontWeight.w700);

      final italicSpan = spans.firstWhere((s) => s.text == 'berubah');
      expect(italicSpan.style?.fontStyle, FontStyle.italic);
    });
  });

  group('PlasMarkdownView widget', () {
    testWidgets(
      'renders PlasCodeBlock, inline spans, and lists cleanly at 390px and 2.0x text scale',
      (tester) async {
        const doc = '''
# Pengantar TypeScript

Gunakan `let` untuk nilai yang **bisa berubah** dan *konsisten* di seluruh modul.

- Deklarasi aman dengan tipe statis
- Mendukung pemeriksaan saat kompilasi

1. Tulis variabel dengan tipe eksplisit
2. Jalankan pemeriksaan contoh kode

```ts title="variabel.ts"
let skor: number = 100;
const catatan: string = "Lulus ujian dengan nilai tinggi dan konsisten";
```
''';

        await tester.pumpWidget(
          _wrap(
            const PlasMarkdownView(markdown: doc),
            width: 390,
            textScaler: const TextScaler.linear(2.0),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(PlasCodeBlock), findsOneWidget);
        expect(find.text('variabel.ts'), findsOneWidget);
        expect(find.text('TS'), findsOneWidget);
        expect(find.byType(SelectionArea), findsOneWidget);

        final richTexts = tester.widgetList<RichText>(find.byType(RichText));
        final allSpans = <TextSpan>[];
        void collectSpans(InlineSpan span) {
          if (span is TextSpan) {
            allSpans.add(span);
            span.children?.forEach(collectSpans);
          }
        }

        for (final rt in richTexts) {
          collectSpans(rt.text);
        }

        expect(
          allSpans.any(
            (s) =>
                s.text == 'let' &&
                s.style?.fontFamily == PlasTypography.fontMono &&
                s.style?.backgroundColor == PlasColors.bgSubtle,
          ),
          isTrue,
        );
        expect(
          allSpans.any(
            (s) =>
                s.text == 'bisa berubah' &&
                s.style?.fontWeight == FontWeight.w700,
          ),
          isTrue,
        );
        expect(
          allSpans.any(
            (s) =>
                s.text == 'konsisten' && s.style?.fontStyle == FontStyle.italic,
          ),
          isTrue,
        );
      },
    );

    testWidgets('respects selectableCode: false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PlasMarkdownView(
            markdown: '```ts\nconst ok = true;\n```',
            selectableCode: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PlasCodeBlock), findsOneWidget);
      expect(find.byType(SelectionArea), findsNothing);
    });
  });
}
