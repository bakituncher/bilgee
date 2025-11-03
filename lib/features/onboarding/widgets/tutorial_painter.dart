// lib/features/onboarding/widgets/tutorial_painter.dart
import 'package:flutter/material.dart';

class TutorialPainter extends CustomPainter {
  final Rect? highlightRect;
  final Color highlightColor;

  TutorialPainter({required this.highlightRect, required this.highlightColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (highlightRect == null) return;

    final paint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

    final rrect = RRect.fromRectAndRadius(highlightRect!.inflate(8), const Radius.circular(16));
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}