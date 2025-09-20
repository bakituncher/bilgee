// lib/features/onboarding/controllers/app_tour_controller.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taktik/features/onboarding/widgets/app_tour_widget.dart';

class AppTourController extends StateNotifier<bool> {
  AppTourController() : super(false);

  static const String _tourCompletedKey = 'app_tour_completed';

  Future<void> checkAndShowTour(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final tourCompleted = prefs.getBool(_tourCompletedKey) ?? false;

    if (!tourCompleted && mounted) {
      // Kısa bir gecikme ile tour'u başlat
      Future.delayed(Duration(milliseconds: 1000), () {
        if (context.mounted) {
          showAppTour(context);
        }
      });
    }
  }

  void showAppTour(BuildContext context) {
    final tourSteps = _getTourSteps();
    final targetKeys = _getTargetKeys(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => AppTourWidget(
        targetKeys: targetKeys,
        steps: tourSteps,
        onComplete: () {
          Navigator.of(context).pop();
          _markTourCompleted();
        },
      ),
    );
  }

  Future<void> _markTourCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourCompletedKey, true);
    state = true;
  }

  List<TourStep> _getTourSteps() {
    return [
      TourStep(
        title: 'AI Asistanın 🤖',
        description: 'Burada AI asistanın ile konuşabilirsin. Soru çözümü, konu açıklaması ve strateji geliştirme için tıkla.',
        icon: Icons.psychology,
      ),
      TourStep(
        title: 'Soru Bankası 📚',
        description: 'Binlerce soru ile pratik yap. Seviyene uygun sorular ve detaylı çözümler burada.',
        icon: Icons.quiz,
      ),
      TourStep(
        title: 'Çalışma Planın 📋',
        description: 'Kişisel çalışma programını görüntüle ve güncellemeler yap.',
        icon: Icons.calendar_today,
      ),
      TourStep(
        title: 'İlerleme Takibi 📊',
        description: 'Performansını takip et, güçlü ve zayıf yönlerini gör. Hedefine ne kadar yakın olduğunu öğren.',
        icon: Icons.trending_up,
      ),
      TourStep(
        title: 'Profil Ayarları ⚙️',
        description: 'Profil bilgilerini düzenle, hedeflerini güncelle ve uygulama ayarlarını yönet.',
        icon: Icons.person,
      ),
      TourStep(
        title: 'Başarıya Hazırsın! 🎯',
        description: 'Taktik ile sınav başarına giden yolculuğun başladı. İyi çalışmalar!',
        icon: Icons.flag,
      ),
    ];
  }

  List<GlobalKey> _getTargetKeys(BuildContext context) {
    // Bu keys'ler ana ekrandaki widget'lara assign edilecek
    return [
      GlobalKey(), // AI Chat button key
      GlobalKey(), // Question bank key
      GlobalKey(), // Study plan key
      GlobalKey(), // Progress key
      GlobalKey(), // Profile key
      GlobalKey(), // Generic key for last step
    ];
  }

  Future<void> resetTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tourCompletedKey);
    state = false;
  }
}

final appTourControllerProvider = StateNotifierProvider<AppTourController, bool>((ref) {
  return AppTourController();
});

// Ana ekran widget'larında kullanılacak keys
class TourKeys {
  static final GlobalKey aiChatKey = GlobalKey();
  static final GlobalKey questionBankKey = GlobalKey();
  static final GlobalKey studyPlanKey = GlobalKey();
  static final GlobalKey progressKey = GlobalKey();
  static final GlobalKey profileKey = GlobalKey();
}
