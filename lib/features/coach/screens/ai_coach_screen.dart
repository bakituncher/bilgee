// lib/features/coach/screens/ai_coach_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// BİLGEAI DEVRİMİ: Bu provider artık uygulamanın genelinde AI analizini saklayan "Bilge Kasa"dır.
// Yapısı: (imza: String, veri: Map<String, dynamic>)
final aiAnalysisProvider = StateProvider<({String signature, Map<String, dynamic> data})?>((ref) => null);

// Bu Notifier, artık doğrudan bir ekranda kullanılmıyor, ancak gelecekte
// arka planda plan güncellemesi gibi işlemler için saklanabilir.
class AiCoachNotifier extends StateNotifier<bool> {
  // BİLGEAI DEVRİMİ - DÜZELTME: Kullanılmayan _ref alanı kaldırıldı.
  AiCoachNotifier() : super(false);
}

final aiCoachNotifierProvider = StateNotifierProvider.autoDispose<AiCoachNotifier, bool>((ref) {
  return AiCoachNotifier();
});

// Not: Bu ekranın kendisi artık doğrudan kullanılmıyor.
// İşlevleri `StrategicPlanningScreen` tarafından devralındı.
class AiCoachScreen extends StatelessWidget {
  const AiCoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "Bu bölümün işlevleri 'Stratejik Planlama Atölyesi'ne taşınmıştır.",
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}