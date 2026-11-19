import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

enum OwlMascotVariant { filled, outline }

class OwlBracketMascot extends StatelessWidget {
  const OwlBracketMascot({
    super.key,
    this.size = 40,
    this.variant = OwlMascotVariant.filled,
    this.semanticLabel,
  });

  final double size;
  final OwlMascotVariant variant;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final assetPath = switch (variant) {
      OwlMascotVariant.filled => 'assets/svg/owl_bracket.svg',
      OwlMascotVariant.outline => 'assets/svg/owl_bracket_outline.svg',
    };
    return _PlasVectorAsset(
      assetPath: assetPath,
      size: size,
      semanticLabel: semanticLabel,
    );
  }
}

class PlasAppLogo extends StatelessWidget {
  const PlasAppLogo({
    super.key,
    this.size = 48,
    this.semanticLabel,
  });

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return _PlasVectorAsset(
      assetPath: 'assets/svg/app_logo_ts.svg',
      size: size,
      semanticLabel: semanticLabel,
    );
  }
}

class PlasGoogleLogo extends StatelessWidget {
  const PlasGoogleLogo({
    super.key,
    this.size = 20,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return _PlasVectorAsset(
      assetPath: 'assets/svg/google_logo.svg',
      size: size,
    );
  }
}

class _PlasVectorAsset extends StatelessWidget {
  const _PlasVectorAsset({
    required this.assetPath,
    required this.size,
    this.semanticLabel,
  });

  final String assetPath;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final hasLabel = semanticLabel != null && semanticLabel!.trim().isNotEmpty;
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      excludeFromSemantics: !hasLabel,
      semanticsLabel: hasLabel ? semanticLabel : null,
    );
  }
}
