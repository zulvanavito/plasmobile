import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';

class PlasAccuracyRing extends StatelessWidget {
  const PlasAccuracyRing({
    super.key,
    required this.percentage,
    this.arcColor = PlasColors.successBorder,
    this.trackColor = PlasColors.borderSubtle,
    this.size = 120,
    this.strokeWidth = 12,
    this.label,
  });

  final double percentage;
  final Color arcColor;
  final Color trackColor;
  final double size;
  final double strokeWidth;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final safePercentage = percentage.isFinite
        ? percentage.clamp(0.0, 100.0).toDouble()
        : 0.0;
    final rounded = safePercentage.round();
    final cleanLabel = label?.trim();
    final hasLabel = cleanLabel != null && cleanLabel.isNotEmpty;
    final semanticsLabel = hasLabel ? '$cleanLabel $rounded%' : 'Akurasi $rounded%';

    final safeSize = size > 0 ? size : 120.0;
    final safeStroke = strokeWidth > 0
        ? math.min(strokeWidth, safeSize / 2)
        : 12.0;
    final innerInset = math.min(
      safeStroke + math.max(PlasSpacing.space1, safeStroke * 0.4),
      (safeSize / 2) - 4,
    ).clamp(0.0, safeSize / 2);

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox(
        width: safeSize,
        height: safeSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: PlasAccuracyRingPainter(
                  percentage: safePercentage,
                  arcColor: arcColor,
                  trackColor: trackColor,
                  strokeWidth: safeStroke,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(innerInset),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$rounded%',
                      style: PlasTypography.display.copyWith(
                        color: PlasColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (hasLabel) ...[
                      const SizedBox(height: 2),
                      Text(
                        cleanLabel,
                        style: PlasTypography.caption.copyWith(
                          color: PlasColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlasAccuracyRingPainter extends CustomPainter {
  const PlasAccuracyRingPainter({
    required this.percentage,
    required this.arcColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double percentage;
  final Color arcColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    if (side <= 0) return;

    final effectiveStroke = math.min(strokeWidth, side / 2);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(0.0, (side - effectiveStroke) / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = effectiveStroke;
    canvas.drawCircle(center, radius, trackPaint);

    final clamped = percentage.isFinite
        ? percentage.clamp(0.0, 100.0).toDouble()
        : 0.0;
    if (clamped <= 0) return;

    final sweepAngle = (clamped / 100.0) * (math.pi * 2);
    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = effectiveStroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant PlasAccuracyRingPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.arcColor != arcColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
