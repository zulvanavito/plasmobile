import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/shared/widgets/owl_bracket_mascot.dart';

class TanyaAiFab extends StatelessWidget {
  const TanyaAiFab({
    super.key,
    required this.onPressed,
    this.isAssessmentMode = false,
    this.label = 'Tanya AI',
  });

  final VoidCallback? onPressed;
  final bool isAssessmentMode;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (isAssessmentMode) {
      return const SizedBox.shrink();
    }

    final radius = BorderRadius.circular(PlasRadii.lg);

    return Semantics(
      button: true,
      label: 'Buka AI Learning Assistant',
      child: Container(
        decoration: BoxDecoration(
          color: PlasColors.codeBg,
          borderRadius: radius,
          border: Border.all(color: PlasColors.codeHeader),
          boxShadow: PlasShadows.floating,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            focusColor: const Color(0x3360A5FA),
            overlayColor: const WidgetStatePropertyAll(Color(0x1F60A5FA)),
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PlasSpacing.space4,
                  vertical: PlasSpacing.space3,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const OwlBracketMascot(size: 22),
                    const SizedBox(width: PlasSpacing.space2),
                    Flexible(
                      child: Text(
                        label,
                        style: PlasTypography.label.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
