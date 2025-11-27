// lib/features/settings/logic/settings_notifier.dart
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';

// Veri sıfırlama işleminin durumunu takip etmek için
enum ResetStatus { initial, success, failure }

// Ayarlar ekranının durumunu tutan model
class SettingsState extends Equatable {
  final bool isLoading;
  final ResetStatus resetStatus;

  const SettingsState({
    this.isLoading = false,
    this.resetStatus = ResetStatus.initial,
  });

  SettingsState copyWith({bool? isLoading, ResetStatus? resetStatus}) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      resetStatus: resetStatus ?? this.resetStatus,
    );
  }

  @override
  List<Object> get props => [isLoading, resetStatus];
}

// Ayarlar ekranının mantığını yöneten Notifier
class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref _ref;
  SettingsNotifier(this._ref) : super(const SettingsState());

  Future<bool> updateUserName(String newName) async {
    state = state.copyWith(isLoading: true);
    final userId = _ref.read(authControllerProvider).value?.uid;

    if (userId == null) {
      state = state.copyWith(isLoading: false);
      return false;
    }

    try {
      await _ref
          .read(firestoreServiceProvider)
          .updateUserName(userId: userId, newName: newName);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  // KALDIRILDI: resetAccountForNewExam() - Artık kullanılmıyor

  // Hesap silme işlemini yöneten fonksiyon
  Future<void> deleteAccount() async {
    state = state.copyWith(isLoading: true, resetStatus: ResetStatus.initial);

    try {
      // 1. Cloud Function'ı çağır ve bekle
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('users-deleteUserAccount');
      await callable.call();

      // 2. Buraya gelindiyse işlem BAŞARILIDIR
      state = state.copyWith(isLoading: false, resetStatus: ResetStatus.success);

    } catch (e) {
      // Sadece Cloud Function hata verirse buraya düşer
      state = state.copyWith(isLoading: false, resetStatus: ResetStatus.failure);
      return; // Hata alındıysa fonksiyondan çık
    }

    // 3. Çıkış işlemini ana try-catch dışına alıyoruz
    // Hesap sunucudan silindiği için client tarafında token hatası alınabilir,
    // ancak bu işlemin başarısız olduğu anlamına gelmez
    try {
      await _ref.read(authControllerProvider.notifier).signOut();
    } catch (e) {
      // Çıkış yaparken oluşan hataları sessizce yutabiliriz (beklenen bir durum)
      // Kullanıcı zaten silindiği için token geçersiz olabilir
    }
  }

  // Navigasyon sonrası durumu sıfırlamak için
  void resetOperationStatus() {
    state = state.copyWith(resetStatus: ResetStatus.initial);
  }
}

// Bu Notifier'ı tüm uygulamada kullanılabilir hale getiren Provider
final settingsNotifierProvider =
StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});