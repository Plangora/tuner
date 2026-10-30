import 'package:flutter/material.dart';

/// A small, dependency-free metronome outline for the tuner navigation button.
class MetronomeIcon extends StatelessWidget {
  const MetronomeIcon({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _MetronomePainter(IconTheme.of(context).color ?? Colors.white),
    ),
  );
}

class _MetronomePainter extends CustomPainter {
  const _MetronomePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 32;
    canvas.save();
    canvas.scale(scale);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    final body = Path()
      ..moveTo(6, 27)
      ..lineTo(10, 7)
      ..quadraticBezierTo(10.5, 5, 13, 5)
      ..lineTo(19, 5)
      ..quadraticBezierTo(21.5, 5, 22, 7)
      ..lineTo(26, 27)
      ..quadraticBezierTo(26.5, 29, 24, 29)
      ..lineTo(8, 29)
      ..quadraticBezierTo(5.5, 29, 6, 27)
      ..close();
    canvas.drawPath(body, stroke);
    canvas.drawLine(const Offset(11, 25), const Offset(20, 10), stroke);
    canvas.drawCircle(const Offset(15, 18), 2.4, fill);
    canvas.drawLine(const Offset(11, 23), const Offset(20, 23), stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MetronomePainter oldDelegate) =>
      oldDelegate.color != color;
}
