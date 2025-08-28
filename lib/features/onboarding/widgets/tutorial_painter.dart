// lib/features/onboarding/widgets/tutorial_painter.dart
import 'package:flutter/material.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';

class TutorialPainter extends CustomPainter {
  final Rect? highlightRect;

  TutorialPainter({required this.highlightRect});

  @override
  void paint(Canvas canvas, Size size) {
    if (highlightRect == null) return;

    final paint = Paint()
      ..color = AppTheme.secondaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

    final rrect = RRect.fromRectAndRadius(highlightRect!.inflate(8), const Radius.circular(16));
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}