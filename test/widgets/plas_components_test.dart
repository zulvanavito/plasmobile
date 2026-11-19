import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/theme/plas_theme.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/shared/widgets/confirm_dialog.dart';
import 'package:plasmobile/shared/widgets/owl_bracket_mascot.dart';
import 'package:plasmobile/shared/widgets/plas_bottom_nav.dart';
import 'package:plasmobile/shared/widgets/plas_state_views.dart';
import 'package:plasmobile/shared/widgets/plas_status_badge.dart';
import 'package:plasmobile/shared/widgets/tanya_ai_fab.dart';

Widget _wrap(Widget child, {MediaQueryData? mediaQuery}) {
  return MaterialApp(
    theme: buildPlasTheme(),
    builder: mediaQuery == null
        ? null
        : (context, appChild) => MediaQuery(
            data: mediaQuery,
            child: appChild!,
          ),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('PlasStatusBadge', () {
    testWidgets('every variant renders both a 16dp Icon and text label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final variant in PlasBadgeVariant.values)
                PlasStatusBadge(
                  label: 'Status ${variant.name}',
                  variant: variant,
                ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (final variant in PlasBadgeVariant.values) {
        final badgeFinder = find.widgetWithText(
          PlasStatusBadge,
          'Status ${variant.name}',
        );
        expect(badgeFinder, findsOneWidget);

        final iconFinder = find.descendant(
          of: badgeFinder,
          matching: find.byType(Icon),
        );
        expect(iconFinder, findsOneWidget);
        expect(tester.widget<Icon>(iconFinder).size, 16);
      }
    });

    testWidgets('supports custom icon override', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PlasStatusBadge(
            label: 'Selesai',
            variant: PlasBadgeVariant.success,
            icon: Symbols.verified,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Symbols.verified);
      expect(icon.size, 16);
    });
  });

  group('PlasConfirmDialog & presets', () {
    testWidgets('tapping confirm returns true and tapping cancel returns false', (
      tester,
    ) async {
      bool? confirmResult;
      bool? cancelResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildPlasTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      confirmResult = await showPlasConfirmDialog(
                        context,
                        title: 'Konfirmasi Aksi',
                        message: 'Apakah kamu yakin?',
                        confirmLabel: 'Lanjutkan',
                      );
                    },
                    child: const Text('Open Confirm'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      cancelResult = await showPlasConfirmDialog(
                        context,
                        title: 'Konfirmasi Batal',
                        message: 'Apakah kamu yakin?',
                        confirmLabel: 'Ya',
                      );
                    },
                    child: const Text('Open Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Konfirmasi Aksi'), findsOneWidget);
      await tester.tap(find.text('Lanjutkan'));
      await tester.pumpAndSettle();
      expect(confirmResult, isTrue);

      await tester.tap(find.text('Open Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Konfirmasi Batal'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(cancelResult, isFalse);
    });

    testWidgets('presets render expected labels without em dashes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPlasTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () => showSubmitExerciseConfirmDialog(
                      context,
                      answeredCount: 4,
                      totalCount: 5,
                    ),
                    child: const Text('Preset Exercise'),
                  ),
                  ElevatedButton(
                    onPressed: () => showSubmitTestConfirmDialog(
                      context,
                      testLabel: 'Post-Test',
                    ),
                    child: const Text('Preset Test'),
                  ),
                  ElevatedButton(
                    onPressed: () => showLogoutConfirmDialog(context),
                    child: const Text('Preset Logout'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Preset Exercise'));
      await tester.pumpAndSettle();
      expect(find.text('Kumpulkan Latihan?'), findsOneWidget);
      expect(find.textContaining('4 dari 5 soal'), findsOneWidget);
      expect(find.text('Kumpulkan'), findsOneWidget);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.data ?? '', isNot(contains('\u2014')));
      }
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preset Test'));
      await tester.pumpAndSettle();
      expect(find.text('Kumpulkan Post-Test?'), findsOneWidget);
      expect(find.text('Kumpulkan Post-Test'), findsOneWidget);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.data ?? '', isNot(contains('\u2014')));
      }
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preset Logout'));
      await tester.pumpAndSettle();
      expect(find.text('Keluar dari Akun?'), findsOneWidget);
      expect(find.text('Keluar'), findsOneWidget);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.data ?? '', isNot(contains('\u2014')));
      }
      final logoutButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Keluar'),
      );
      expect(
        logoutButton.style?.backgroundColor?.resolve(<WidgetState>{}),
        PlasColors.errorBorder,
      );
      expect(
        logoutButton.style?.side?.resolve(<WidgetState>{WidgetState.focused}),
        const BorderSide(color: PlasColors.focusLight, width: 2),
      );
      final cancelButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Batal'),
      );
      expect(
        cancelButton.style?.side?.resolve(<WidgetState>{WidgetState.focused}),
        const BorderSide(color: PlasColors.focusLight, width: 2),
      );
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
    });
  });

  group('PlasBottomNav', () {
    testWidgets(
      'renders exact 3 tabs, reports taps 0..2, and each tab hit box is >= 48dp',
      (tester) async {
        final tappedIndices = <int>[];
        var currentIndex = 0;

        await tester.pumpWidget(
          MaterialApp(
            theme: buildPlasTheme(),
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: const SizedBox.shrink(),
                bottomNavigationBar: PlasBottomNav(
                  currentIndex: currentIndex,
                  onTap: (index) {
                    tappedIndices.add(index);
                    setState(() {
                      currentIndex = index;
                    });
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        const labels = ['Belajar', 'Riwayat', 'Profil'];
        for (var i = 0; i < labels.length; i++) {
          final label = labels[i];
          expect(find.text(label), findsOneWidget);
          expect(find.bySemanticsLabel(label), findsOneWidget);
          final inkWell = find.ancestor(
            of: find.text(label),
            matching: find.byType(InkWell),
          );
          expect(inkWell, findsOneWidget);
          final size = tester.getSize(inkWell);
          expect(size.height, greaterThanOrEqualTo(48.0));
          expect(size.width, greaterThanOrEqualTo(48.0));

          await tester.tap(inkWell);
          await tester.pumpAndSettle();
        }

        expect(tappedIndices, [0, 1, 2]);
      },
    );
  });

  group('PlasStateViews', () {
    testWidgets('PlasLoadingSkeleton renders message and cardCount blocks', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const PlasLoadingSkeleton(
            message: 'Memuat materi pembelajaran...',
            cardCount: 4,
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Memuat materi pembelajaran...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      final cards = find.descendant(
        of: find.byType(PlasLoadingSkeleton),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).border != null,
        ),
      );
      expect(cards, findsNWidgets(4));
    });

    testWidgets(
      'PlasEmptyView renders outline OwlBracketMascot and triggers onAction',
      (tester) async {
        var actionCalled = false;

        await tester.pumpWidget(
          _wrap(
            PlasEmptyView(
              title: 'Belum Ada Materi',
              description: 'Gabung kelas terlebih dahulu untuk membuka materi.',
              actionLabel: 'Gabung Kelas',
              onAction: () {
                actionCalled = true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final mascot = tester.widget<OwlBracketMascot>(
          find.byType(OwlBracketMascot),
        );
        expect(mascot.variant, OwlMascotVariant.outline);
        expect(mascot.size, 56);
        expect(find.text('Belum Ada Materi'), findsOneWidget);

        await tester.tap(find.text('Gabung Kelas'));
        await tester.pump();
        expect(actionCalled, isTrue);
      },
    );

    testWidgets('PlasErrorView renders message and triggers onRetry', (
      tester,
    ) async {
      var retried = false;

      await tester.pumpWidget(
        _wrap(
          PlasErrorView(
            title: 'Gagal Memuat',
            message: 'Terjadi kesalahan saat menghubungi server.',
            onRetry: () {
              retried = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Gagal Memuat'), findsOneWidget);
      expect(
        find.text('Terjadi kesalahan saat menghubungi server.'),
        findsOneWidget,
      );
      expect(find.byIcon(Symbols.error), findsOneWidget);

      final retryButton = tester.widget<OutlinedButton>(
        find.byType(OutlinedButton),
      );
      expect(
        retryButton.style?.side?.resolve(<WidgetState>{WidgetState.focused}),
        const BorderSide(color: PlasColors.focusLight, width: 2),
      );

      await tester.tap(find.text('Coba Lagi'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets(
      'PlasOfflineSyncBanner renders pendingCount, handles retry, and disables button while syncing',
      (tester) async {
        var retriedCount = 0;

        await tester.pumpWidget(
          _wrap(
            PlasOfflineSyncBanner(
              pendingCount: 3,
              onRetry: () {
                retriedCount++;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('3 data tersimpan sementara'), findsOneWidget);
        expect(find.byIcon(Symbols.cloud_off), findsOneWidget);

        await tester.tap(find.text('Kirim Ulang Sekarang'));
        await tester.pump();
        expect(retriedCount, 1);

        await tester.pumpWidget(
          _wrap(
            PlasOfflineSyncBanner(
              pendingCount: 3,
              isSyncing: true,
              onRetry: () {
                retriedCount++;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mengirim Ulang...'), findsOneWidget);
        final button = tester.widget<OutlinedButton>(
          find.byType(OutlinedButton),
        );
        expect(button.onPressed, isNull);
        expect(
          button.style?.foregroundColor?.resolve(<WidgetState>{
            WidgetState.disabled,
          }),
          PlasColors.disabledText,
        );
        expect(
          button.style?.backgroundColor?.resolve(<WidgetState>{
            WidgetState.disabled,
          }),
          PlasColors.disabledBg,
        );
        expect(
          button.style?.side
              ?.resolve(<WidgetState>{WidgetState.disabled})
              ?.color,
          PlasColors.disabledBorder,
        );
        expect(
          button.style?.side?.resolve(<WidgetState>{WidgetState.focused}),
          const BorderSide(color: PlasColors.focusLight, width: 2),
        );
        await tester.tap(find.text('Mengirim Ulang...'));
        await tester.pump();
        expect(retriedCount, 1);
      },
    );
  });

  group('Accessibility / 390x844 @ 2.0x text scale stress test', () {
    testWidgets(
      'all Task 3 widgets render at 390px width with TextScaler.linear(2.0) and zero overflow',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const mediaQuery = MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(2.0),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: buildPlasTheme(),
            builder: (context, child) => MediaQuery(
              data: mediaQuery,
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(PlasSpacing.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: PlasSpacing.space2,
                      runSpacing: PlasSpacing.space2,
                      children: [
                        for (final variant in PlasBadgeVariant.values)
                          PlasStatusBadge(
                            label: 'Badge ${variant.name}',
                            variant: variant,
                          ),
                      ],
                    ),
                    const SizedBox(height: PlasSpacing.space4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TanyaAiFab(onPressed: () {}),
                    ),
                    const SizedBox(height: PlasSpacing.space4),
                    const PlasLoadingSkeleton(
                      message: 'Memuat daftar latihan...',
                      cardCount: 2,
                    ),
                    const SizedBox(height: PlasSpacing.space4),
                    PlasEmptyView(
                      title: 'Belum Ada Riwayat',
                      description: 'Mulai latihan pertama kamu sekarang.',
                      actionLabel: 'Mulai Belajar',
                      onAction: () {},
                    ),
                    const SizedBox(height: PlasSpacing.space4),
                    PlasErrorView(
                      title: 'Koneksi Bermasalah',
                      message: 'Tidak dapat memuat data dari server.',
                      onRetry: () {},
                    ),
                    const SizedBox(height: PlasSpacing.space4),
                    PlasOfflineSyncBanner(
                      pendingCount: 2,
                      onRetry: () {},
                    ),
                    const SizedBox(height: PlasSpacing.space4),
                    Builder(
                      builder: (context) => ElevatedButton(
                        onPressed: () => showSubmitTestConfirmDialog(
                          context,
                          testLabel: 'Post-Test',
                        ),
                        child: const Text('Buka Dialog'),
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: PlasBottomNav(
                currentIndex: 0,
                onTap: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.text('Buka Dialog'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Buka Dialog'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(PlasConfirmDialog), findsOneWidget);
      },
    );
  });
}
