import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A custom gauge widget that displays tuning offset visually.
///
/// Shows a needle gauge that indicates how many cents off the target frequency
/// the current sound is. The gauge ranges from -100 to +100 cents, with a green
/// zone at the center representing in-tune (±5 cents).
class TunerGauge extends StatelessWidget {
  /// The offset in cents from the target frequency.
  /// Range: -100 to +100 cents (negative = flat, positive = sharp).
  final double centsOffset;

  /// Whether the current pitch is within ±5 cents (in tune).
  final bool isInTune;

  const TunerGauge({
    super.key,
    required this.centsOffset,
    required this.isInTune,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomPaint(
        painter: GaugePainter(
          centsOffset: centsOffset,
          isInTune: isInTune,
        ),
        size: const Size(300, 150),
      ),
    );
  }
}

/// Custom painter that draws the tuner gauge visualization.
class GaugePainter extends CustomPainter {
  /// The offset in cents from the target frequency.
  final double centsOffset;

  /// Whether the current pitch is within ±5 cents (in tune).
  final bool isInTune;

  GaugePainter({
    required this.centsOffset,
    required this.isInTune,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height * 0.8;
    final radius = size.width * 0.35;

    _drawArc(canvas, centerX, centerY, radius);
    _drawNeedle(canvas, centerX, centerY, radius);

    // Draw center black circle
    canvas.drawCircle(
      Offset(centerX, centerY),
      12,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill,
    );

    // Draw center white dot
    canvas.drawCircle(
      Offset(centerX, centerY),
      6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  void _drawArc(Canvas canvas, double centerX, double centerY, double radius) {
    final rect = Rect.fromCircle(
      center: Offset(centerX, centerY),
      radius: radius,
    );

    // Draw background gray arc
    canvas.drawArc(
      rect,
      math.pi, // Start at 180 degrees (left)
      math.pi, // Span 180 degrees
      false,
      Paint()
        ..color = Colors.grey
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Draw in-tune zone (green) at center (±5 cents)
    // ±5 cents out of ±100 cents = ±5% of the arc
    // 5 cents / 100 cents * 180 degrees = 9 degrees = π/20 radians
    final inTuneZoneAngle = math.pi / 20; // ±5 cents equivalent
    canvas.drawArc(
      rect,
      math.pi - inTuneZoneAngle,
      2 * inTuneZoneAngle,
      false,
      Paint()
        ..color = Colors.green
        ..strokeWidth = 12
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Draw tick marks
    for (int i = -100; i <= 100; i += 20) {
      final angle = _centsToAngle(i.toDouble());

      // Calculate start and end points for the tick mark
      final startX = centerX + (radius + 15) * math.cos(angle);
      final startY = centerY + (radius + 15) * math.sin(angle);
      final endX = centerX + (radius + 25) * math.cos(angle);
      final endY = centerY + (radius + 25) * math.sin(angle);

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        Paint()
          ..color = Colors.black
          ..strokeWidth = 2,
      );
    }
  }

  void _drawNeedle(Canvas canvas, double centerX, double centerY, double radius) {
    final clampedOffset = centsOffset.clamp(-100.0, 100.0);
    final angle = _centsToAngle(clampedOffset);

    final needleColor = isInTune ? Colors.green : Colors.red;
    final endX = centerX + radius * 0.9 * math.cos(angle);
    final endY = centerY + radius * 0.9 * math.sin(angle);

    canvas.drawLine(
      Offset(centerX, centerY),
      Offset(endX, endY),
      Paint()
        ..color = needleColor
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Converts cents offset to angle in radians.
  ///
  /// Maps -100 to +100 cents to an arc from π (180°) to 0 (0°).
  /// Center (0 cents) is at π radians (180 degrees / left).
  /// Formula: centerAngle + (normalizedCents * maxAngleSpan / 2.0)
  double _centsToAngle(double cents) {
    const centerAngle = math.pi; // 180 degrees (left)
    const maxAngleSpan = math.pi; // 180 degrees total span
    final normalizedCents = cents / 100.0;
    return centerAngle + (normalizedCents * maxAngleSpan / 2.0);
  }

  @override
  bool shouldRepaint(GaugePainter oldDelegate) {
    return oldDelegate.centsOffset != centsOffset ||
        oldDelegate.isInTune != isInTune;
  }
}
