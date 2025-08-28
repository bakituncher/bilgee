// lib/features/onboarding/providers/tutorial_provider.dart
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TutorialNotifier extends StateNotifier<int?> {
  final int totalSteps;
  final StatefulNavigationShell? navigationShell;
  final Ref _ref;

  TutorialNotifier(this.totalSteps, this.navigationShell, this._ref) : super(null); // Başlangıçta null (kapalı)

  void start() {
    state = 0; // Öğreticiyi ilk adımdan başlat
  }

  void next() {
    if (state == null) return;

    // Özel adımlar için navigasyon mantığı
    // Adım 3'ten sonra Koç sekmesine git
    if (state == 3) {
      navigationShell?.goBranch(1); // Koç sekmesinin index'i 1
    }
    // Adım 5'ten sonra Arena sekmesine git
    else if (state == 5) {
      navigationShell?.goBranch(3); // Arena sekmesinin index'i 3
    }
    // Adım 6'dan sonra Profil sekmesine git
    else if (state == 6) {
      navigationShell?.goBranch(4); // Profil sekmesinin index'i 4
    }

    if (state! < totalSteps - 1) {
      state = state! + 1;
    } else {
      finish();
    }
  }

  void finish() {
    // Tur bitince ana ekrana (index 0) dön
    if (navigationShell?.currentIndex != 0) {
      navigationShell?.goBranch(0);
    }
    // DEĞİŞİKLİK: Kullanıcının eğitimi tamamladığı bilgisi burada veritabanına kaydediliyor.
    final userId = _ref.read(authControllerProvider).value?.uid;
    if (userId != null) {
      _ref.read(firestoreServiceProvider).markTutorialAsCompleted(userId);
    }
    state = null; // Öğreticiyi bitir ve kapat
  }
}

final tutorialProvider = StateNotifierProvider<TutorialNotifier, int?>((ref) {
  // Bu provider, ScaffoldWithNavBar'da override edilerek gerçek değerleriyle oluşturulacak.
  throw UnimplementedError('tutorialProvider must be overridden');
});