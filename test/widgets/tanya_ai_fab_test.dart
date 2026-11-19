import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/theme/plas_theme.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/shared/widgets/owl_bracket_mascot.dart';
import 'package:plasmobile/shared/widgets/tanya_ai_fab.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: buildPlasTheme(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('TanyaAiFab', () {
    testWidgets(
      'renders Tanya AI with OwlBracketMascot, >= 48dp height, and triggers onPressed when not in assessment mode',
      (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          _wrap(
            TanyaAiFab(
              onPressed: () {
                tapped = true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Tanya AI'), findsOneWidget);
        expect(find.byType(OwlBracketMascot), findsOneWidget);
        expect(
          find.bySemanticsLabel('Buka AI Learning Assistant'),
          findsOneWidget,
        );

        final fabSize = tester.getSize(find.byType(TanyaAiFab));
        expect(fabSize.height, greaterThanOrEqualTo(48.0));
        expect(fabSize.width, greaterThanOrEqualTo(48.0));

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(TanyaAiFab),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, PlasColors.codeBg);

        await tester.tap(find.byType(TanyaAiFab));
        await tester.pump();
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'returns SizedBox.shrink() and hides Tanya AI and OwlBracketMascot when isAssessmentMode is true (P12)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            TanyaAiFab(
              isAssessmentMode: true,
              onPressed: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Tanya AI'), findsNothing);
        expect(find.byType(OwlBracketMascot), findsNothing);
        expect(find.byType(InkWell), findsNothing);

        final fabSize = tester.getSize(find.byType(TanyaAiFab));
        expect(fabSize, Size.zero);
      },
    );
  });
}
