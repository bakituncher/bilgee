// lib/features/onboarding/models/tutorial_step.dart
import 'package:flutter/material.dart';

class TutorialStep {
  final GlobalKey? highlightKey; // Vurgulanacak widget'ın anahtarı
  final String title;
  final String text;
  final String buttonText;
  final bool isNavigational; // Kullanıcının bir yere tıklamasını mı bekliyor?
  final int? requiredScreenIndex; // Bu adımın gösterilmesi için gereken ekran index'i

  TutorialStep({
    this.highlightKey,
    required this.title,
    required this.text,
    this.buttonText = "Anladım, devam et!",
    this.isNavigational = false,
    this.requiredScreenIndex,
  });
}