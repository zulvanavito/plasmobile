import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/shared/widgets/owl_bracket_mascot.dart';

class PlasLoadingSkeleton extends StatelessWidget {
  const PlasLoadingSkeleton({
    super.key,
    required this.message,
    this.cardCount = 3,
  });

  final String message;
  final int cardCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: PlasTypography.caption),
        const SizedBox(height: PlasSpacing.space3),
        for (var i = 0; i < cardCount; i++) ...[
          Container(
            padding: const EdgeInsets.all(PlasSpacing.space4),
            decoration: BoxDecoration(
              color: PlasColors.bgSurface,
              borderRadius: BorderRadius.circular(PlasRadii.lg),
              border: Border.all(color: PlasColors.borderDivider),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.45,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: PlasColors.borderDivider,
                      borderRadius: BorderRadius.circular(PlasRadii.sm),
                    ),
                  ),
                ),
                const SizedBox(height: PlasSpacing.space2),
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: PlasColors.bgSubtle,
                    borderRadius: BorderRadius.circular(PlasRadii.sm),
                  ),
                ),
                const SizedBox(height: PlasSpacing.space2),
                FractionallySizedBox(
                  widthFactor: 0.72,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: PlasColors.bgSubtle,
                      borderRadius: BorderRadius.circular(PlasRadii.sm),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (i < cardCount - 1) const SizedBox(height: PlasSpacing.space3),
        ],
      ],
    );
  }
}

class PlasEmptyView extends StatelessWidget {
  const PlasEmptyView({
    super.key,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(PlasSpacing.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OwlBracketMascot(
            size: 56,
            variant: OwlMascotVariant.outline,
          ),
          const SizedBox(height: PlasSpacing.space4),
          Text(
            title,
            style: PlasTypography.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PlasSpacing.space2),
          Text(
            description,
            style: PlasTypography.body,
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: PlasSpacing.space4),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: PlasColors.brandPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PlasRadii.md),
                ),
                textStyle: PlasTypography.label,
              ),
              onPressed: onAction,
              child: Text(actionLabel!, textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }
}

class PlasErrorView extends StatelessWidget {
  const PlasErrorView({
    super.key,
    required this.message,
    this.title,
    this.actionLabel = 'Coba Lagi',
    this.onRetry,
  });

  final String message;
  final String? title;
  final String actionLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PlasSpacing.space4),
      decoration: BoxDecoration(
        color: PlasColors.errorBg,
        borderRadius: BorderRadius.circular(PlasRadii.lg),
        border: Border.all(color: PlasColors.errorBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Symbols.error,
                size: 20,
                color: PlasColors.errorText,
              ),
              const SizedBox(width: PlasSpacing.space3),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null) ...[
                      Text(
                        title!,
                        style: PlasTypography.title.copyWith(
                          color: PlasColors.errorText,
                        ),
                      ),
                      const SizedBox(height: PlasSpacing.space1),
                    ],
                    Text(
                      message,
                      style: PlasTypography.body.copyWith(
                        color: PlasColors.errorText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: PlasSpacing.space3),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                  foregroundColor: const WidgetStatePropertyAll(
                    PlasColors.errorText,
                  ),
                  backgroundColor: const WidgetStatePropertyAll(
                    PlasColors.bgSurface,
                  ),
                  side: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.focused)) {
                      return const BorderSide(
                        color: PlasColors.focusLight,
                        width: 2,
                      );
                    }
                    return const BorderSide(color: PlasColors.errorBorder);
                  }),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PlasRadii.md),
                    ),
                  ),
                  textStyle: const WidgetStatePropertyAll(PlasTypography.label),
                ),
                onPressed: onRetry,
                child: Text(actionLabel, textAlign: TextAlign.center),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PlasOfflineSyncBanner extends StatelessWidget {
  const PlasOfflineSyncBanner({
    super.key,
    required this.pendingCount,
    required this.onRetry,
    this.isSyncing = false,
  });

  final int pendingCount;
  final VoidCallback? onRetry;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PlasSpacing.space4),
      decoration: BoxDecoration(
        color: PlasColors.warningBg,
        borderRadius: BorderRadius.circular(PlasRadii.lg),
        border: Border.all(color: PlasColors.warningBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Symbols.cloud_off,
                size: 20,
                color: PlasColors.warningText,
              ),
              const SizedBox(width: PlasSpacing.space3),
              Expanded(
                child: Text(
                  'Koneksi terputus. $pendingCount data tersimpan sementara dengan kunci idempotensi aman dan siap dikirim ulang.',
                  style: PlasTypography.body.copyWith(
                    color: PlasColors.warningText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PlasSpacing.space3),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PlasRadii.md),
                  ),
                ),
                textStyle: const WidgetStatePropertyAll(PlasTypography.label),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return PlasColors.disabledText;
                  }
                  return PlasColors.warningText;
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return PlasColors.disabledBg;
                  }
                  return PlasColors.bgSurface;
                }),
                side: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return const BorderSide(color: PlasColors.disabledBorder);
                  }
                  if (states.contains(WidgetState.focused)) {
                    return const BorderSide(
                      color: PlasColors.focusLight,
                      width: 2,
                    );
                  }
                  return const BorderSide(color: PlasColors.warningBorder);
                }),
              ),
              onPressed: isSyncing ? null : onRetry,
              child: Text(
                isSyncing ? 'Mengirim Ulang...' : 'Kirim Ulang Sekarang',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
