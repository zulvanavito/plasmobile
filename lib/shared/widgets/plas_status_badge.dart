import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';

enum PlasBadgeVariant { success, error, warning, brand, neutral, disabled }

class PlasStatusBadge extends StatelessWidget {
  const PlasStatusBadge({
    super.key,
    required this.label,
    required this.variant,
    this.icon,
  });

  final String label;
  final PlasBadgeVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(variant);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PlasSpacing.space2,
        vertical: PlasSpacing.space1,
      ),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(PlasRadii.sm),
        border: Border.all(color: style.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? style.icon, size: 16, color: style.fg),
          const SizedBox(width: PlasSpacing.space1),
          Flexible(
            child: Text(
              label,
              style: PlasTypography.caption.copyWith(
                color: style.fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static _PlasBadgeStyle _styleFor(PlasBadgeVariant variant) {
    return switch (variant) {
      PlasBadgeVariant.success => const _PlasBadgeStyle(
        bg: PlasColors.successBg,
        border: PlasColors.successBorder,
        fg: PlasColors.successText,
        icon: Symbols.check_circle,
      ),
      PlasBadgeVariant.error => const _PlasBadgeStyle(
        bg: PlasColors.errorBg,
        border: PlasColors.errorBorder,
        fg: PlasColors.errorText,
        icon: Symbols.cancel,
      ),
      PlasBadgeVariant.warning => const _PlasBadgeStyle(
        bg: PlasColors.warningBg,
        border: PlasColors.warningBorder,
        fg: PlasColors.warningText,
        icon: Symbols.schedule,
      ),
      PlasBadgeVariant.brand => const _PlasBadgeStyle(
        bg: PlasColors.brandTint,
        border: PlasColors.brandPrimary,
        fg: PlasColors.brandHover,
        icon: Symbols.info,
      ),
      PlasBadgeVariant.neutral => const _PlasBadgeStyle(
        bg: PlasColors.bgSubtle,
        border: PlasColors.borderDivider,
        fg: PlasColors.textSecondary,
        icon: Symbols.label,
      ),
      PlasBadgeVariant.disabled => const _PlasBadgeStyle(
        bg: PlasColors.disabledBg,
        border: PlasColors.disabledBorder,
        fg: PlasColors.disabledText,
        icon: Symbols.lock,
      ),
    };
  }
}

class _PlasBadgeStyle {
  const _PlasBadgeStyle({
    required this.bg,
    required this.border,
    required this.fg,
    required this.icon,
  });

  final Color bg;
  final Color border;
  final Color fg;
  final IconData icon;
}
