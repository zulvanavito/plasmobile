import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';

enum PlasConfirmTone { primary, destructive }

class PlasConfirmDialog extends StatelessWidget {
  const PlasConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Batal',
    this.tone = PlasConfirmTone.primary,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final PlasConfirmTone tone;

  @override
  Widget build(BuildContext context) {
    final isDestructive = tone == PlasConfirmTone.destructive;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(PlasRadii.md),
    );

    final confirmStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: PlasSpacing.space4,
          vertical: PlasSpacing.space3,
        ),
      ),
      shape: WidgetStatePropertyAll(buttonShape),
      textStyle: WidgetStatePropertyAll(PlasTypography.label),
      elevation: const WidgetStatePropertyAll(0),
      foregroundColor: const WidgetStatePropertyAll(Colors.white),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.hovered)) {
          return isDestructive
              ? const Color(0xFFB91C1C)
              : PlasColors.brandHover;
        }
        return isDestructive ? PlasColors.errorBorder : PlasColors.brandPrimary;
      }),
    );

    final cancelStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: PlasSpacing.space4,
          vertical: PlasSpacing.space3,
        ),
      ),
      shape: WidgetStatePropertyAll(buttonShape),
      textStyle: WidgetStatePropertyAll(PlasTypography.label),
      foregroundColor: const WidgetStatePropertyAll(PlasColors.textPrimary),
      backgroundColor: const WidgetStatePropertyAll(PlasColors.bgSurface),
      side: const WidgetStatePropertyAll(
        BorderSide(color: PlasColors.borderInteractive),
      ),
    );

    return Dialog(
      backgroundColor: PlasColors.bgSurface,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: PlasSpacing.space4,
        vertical: PlasSpacing.space6,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PlasRadii.xl),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: PlasColors.bgSurface,
          borderRadius: BorderRadius.circular(PlasRadii.xl),
          boxShadow: PlasShadows.overlay,
        ),
        padding: const EdgeInsets.all(PlasSpacing.space5),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: PlasTypography.heading),
              const SizedBox(height: PlasSpacing.space2),
              Text(message, style: PlasTypography.body),
              const SizedBox(height: PlasSpacing.space5),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: PlasSpacing.space2,
                overflowSpacing: PlasSpacing.space2,
                overflowAlignment: OverflowBarAlignment.end,
                children: [
                  OutlinedButton(
                    style: cancelStyle,
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(cancelLabel, textAlign: TextAlign.center),
                  ),
                  ElevatedButton(
                    style: confirmStyle,
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(confirmLabel, textAlign: TextAlign.center),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> showPlasConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Batal',
  PlasConfirmTone tone = PlasConfirmTone.primary,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => PlasConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      tone: tone,
    ),
  );
  return result ?? false;
}

Future<bool> showSubmitExerciseConfirmDialog(
  BuildContext context, {
  int? answeredCount,
  int? totalCount,
}) {
  final message = answeredCount != null && totalCount != null
      ? 'Kamu sudah menjawab $answeredCount dari $totalCount soal. Setelah dikumpulkan, jawaban akan dinilai dan pembahasan ditampilkan.'
      : 'Setelah dikumpulkan, jawaban latihan akan dinilai dan pembahasan ditampilkan.';
  return showPlasConfirmDialog(
    context,
    title: 'Kumpulkan Latihan?',
    message: message,
    confirmLabel: 'Kumpulkan',
  );
}

Future<bool> showSubmitTestConfirmDialog(
  BuildContext context, {
  required String testLabel,
}) {
  return showPlasConfirmDialog(
    context,
    title: 'Kumpulkan $testLabel?',
    message:
        'Pastikan semua jawaban $testLabel sudah diperiksa. Setelah dikumpulkan, kamu tidak dapat mengubah jawaban lagi.',
    confirmLabel: 'Kumpulkan $testLabel',
  );
}

Future<bool> showLogoutConfirmDialog(BuildContext context) {
  return showPlasConfirmDialog(
    context,
    title: 'Keluar dari Akun?',
    message:
        'Kamu akan keluar dari sesi saat ini. Data yang belum tersinkron tetap tersimpan secara lokal.',
    confirmLabel: 'Keluar',
    tone: PlasConfirmTone.destructive,
  );
}
