import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/theme/plas_theme.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/shared/widgets/owl_bracket_mascot.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: buildPlasTheme(),
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  group('OwlBracketMascot & brand SVG widgets', () {
    testWidgets('OwlBracketMascot filled renders at exact size without exceptions', (tester) async {
      await tester.pumpWidget(_wrap(const OwlBracketMascot()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final svgFinder = find.byType(SvgPicture);
      expect(svgFinder, findsOneWidget);
      expect(tester.getSize(svgFinder), const Size(40, 40));

      final svg = tester.widget<SvgPicture>(svgFinder);
      expect(svg.excludeFromSemantics, isTrue);
      expect(svg.semanticsLabel, isNull);
    });

    testWidgets('OwlBracketMascot outline renders at custom size with semanticLabel', (tester) async {
      const label = 'Maskot Owl Bracket';
      await tester.pumpWidget(
        _wrap(
          const OwlBracketMascot(
            size: 56,
            variant: OwlMascotVariant.outline,
            semanticLabel: label,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final svgFinder = find.byType(SvgPicture);
      expect(svgFinder, findsOneWidget);
      expect(tester.getSize(svgFinder), const Size(56, 56));

      final svg = tester.widget<SvgPicture>(svgFinder);
      expect(svg.excludeFromSemantics, isFalse);
      expect(svg.semanticsLabel, label);
      expect(find.bySemanticsLabel(label), findsOneWidget);
    });

    testWidgets('PlasAppLogo renders at exact size and propagates semanticLabel', (tester) async {
      const label = 'Logo PLAS TypeScript';
      await tester.pumpWidget(
        _wrap(
          const PlasAppLogo(
            size: 64,
            semanticLabel: label,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final svgFinder = find.byType(SvgPicture);
      expect(svgFinder, findsOneWidget);
      expect(tester.getSize(svgFinder), const Size(64, 64));

      final svg = tester.widget<SvgPicture>(svgFinder);
      expect(svg.excludeFromSemantics, isFalse);
      expect(svg.semanticsLabel, label);
      expect(find.bySemanticsLabel(label), findsOneWidget);
    });

    testWidgets('PlasAppLogo defaults to 48px and excludes decorative semantics', (tester) async {
      await tester.pumpWidget(_wrap(const PlasAppLogo()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final svgFinder = find.byType(SvgPicture);
      expect(tester.getSize(svgFinder), const Size(48, 48));
      expect(tester.widget<SvgPicture>(svgFinder).excludeFromSemantics, isTrue);
    });

    testWidgets('PlasGoogleLogo renders at exact size without exceptions', (tester) async {
      await tester.pumpWidget(_wrap(const PlasGoogleLogo(size: 24)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final svgFinder = find.byType(SvgPicture);
      expect(svgFinder, findsOneWidget);
      expect(tester.getSize(svgFinder), const Size(24, 24));
      expect(tester.widget<SvgPicture>(svgFinder).excludeFromSemantics, isTrue);
    });
  });

  group('buildPlasTheme', () {
    test('configures light brightness, canvas scaffold, and chrome themes', () {
      final theme = buildPlasTheme();

      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, PlasColors.bgCanvas);
      expect(theme.appBarTheme.systemOverlayStyle, isNotNull);
      expect(
        theme.appBarTheme.systemOverlayStyle?.systemNavigationBarColor,
        PlasColors.bgSurface,
      );
      expect(theme.progressIndicatorTheme.color, PlasColors.brandPrimary);
      expect(
        theme.progressIndicatorTheme.linearTrackColor,
        PlasColors.borderSubtle,
      );
      expect(theme.dividerTheme.color, PlasColors.borderSubtle);
      expect(theme.textSelectionTheme.cursorColor, PlasColors.brandPrimary);
      expect(theme.snackBarTheme.backgroundColor, PlasColors.textPrimary);
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    });
  });
}
