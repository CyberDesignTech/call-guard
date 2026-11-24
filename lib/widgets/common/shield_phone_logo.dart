import 'package:flutter/material.dart';

class ShieldPhoneLogo extends StatelessWidget {
  const ShieldPhoneLogo({super.key, this.size = 42});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _ShieldPhonePainter());
  }
}

class _ShieldPhonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    canvas.save();
    canvas.translate(
      (size.width - size.shortestSide) / 2,
      (size.height - size.shortestSide) / 2,
    );
    canvas.scale(scale);

    final shield = Path()
      ..moveTo(50, 6)
      ..cubicTo(61, 13, 75, 16, 87, 18)
      ..lineTo(87, 47)
      ..cubicTo(87, 68, 71, 85, 50, 95)
      ..cubicTo(29, 85, 13, 68, 13, 47)
      ..lineTo(13, 18)
      ..cubicTo(25, 16, 39, 13, 50, 6)
      ..close();

    canvas.drawShadow(shield, const Color(0x66334FA8), 5, true);
    canvas.drawPath(
      shield,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF72A7FF), Color(0xFF19B6A3)],
        ).createShader(const Rect.fromLTWH(10, 6, 80, 90)),
    );
    final highlight = Path()
      ..moveTo(50, 15)
      ..cubicTo(58, 19, 67, 21, 76, 23);
    canvas.drawPath(
      highlight,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4,
    );

    final handset = Path()
      ..moveTo(34, 30)
      ..cubicTo(31, 29, 28, 31, 27, 34)
      ..lineTo(26, 39)
      ..cubicTo(29, 53, 43, 67, 57, 72)
      ..cubicTo(60, 73, 64, 71, 66, 68)
      ..lineTo(69, 63)
      ..cubicTo(70, 61, 69, 59, 67, 58)
      ..lineTo(60, 54)
      ..cubicTo(58, 53, 56, 54, 54, 56)
      ..lineTo(51, 59)
      ..cubicTo(45, 56, 40, 51, 37, 45)
      ..lineTo(41, 41)
      ..cubicTo(43, 39, 43, 37, 42, 35)
      ..lineTo(37, 31)
      ..cubicTo(36, 30, 35, 29, 34, 30)
      ..close();
    canvas.save();
    canvas.translate(50, 50);
    canvas.scale(1.2);
    canvas.translate(-50, -50);
    canvas.drawPath(handset, Paint()..color = Colors.white);
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShieldPhonePainter oldDelegate) => false;
}
