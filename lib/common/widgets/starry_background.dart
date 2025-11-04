import 'dart:math';
import 'package:flutter/material.dart';

class StarryBackground extends StatelessWidget {
  final Widget child;
  const StarryBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarsPainter(),
      child: child,
    );
  }
}

class _StarsPainter extends CustomPainter {
  final rand = Random(42);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFD8B982).withValues(alpha: 0.5);
    for (int i = 0; i < 60; i++) {
      final dx = rand.nextDouble() * size.width;
      final dy = rand.nextDouble() * size.height;
      final r = rand.nextDouble() * 1.5 + 0.3;
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
