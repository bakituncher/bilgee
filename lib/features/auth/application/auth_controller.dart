// lib/features/auth/application/auth_controller.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:purchases_flutter/purchases_flutter.dart'; // RevenueCat SDK
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/data/auth_repository.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';
import 'package:flutter/foundation.dart'; // kDebugMode ve debugPrint için
import '../../../shared/notifications/notification_service.dart';
import '../../../core/services/admob_service.dart';

final authControllerProvider = StreamNotifierProvider<AuthController, User?>(() {
  return AuthController();
});

class AuthController extends StreamNotifier<User?> {
  @override
  Stream<User?> build() {
    final authRepository = ref.watch(authRepositoryProvider);
    final authStream = authRepository.authStateChanges;

    // Auth state dinleyicisini ayarla
    final authSubscription = authStream.listen(_onUserActivity);

    // RevenueCat müşteri bilgisi dinleyicisini ayarla
    // Bu dinleyici, uygulama içindeki satın almalar veya sunucu tarafındaki
    // değişiklikler (örn. abonelik yenileme) sonrası tetiklenir.
    Purchases.addCustomerInfoUpdateListener((_) {
      // Değişiklik olduğunda, rate-limit korumalı sunucu senkronunu tetikle.
      _triggerServerSideSync();
    });

    ref.onDispose(() {
      authSubscription.cancel();
    });

    return authStream;
  }

  void _onUserActivity(User? user) {
    if (user != null) {
      // RevenueCat'e giriş yaparak app_user_id'yi Firebase uid ile senkronize et
      _logInToRevenueCat(user.uid);

      // KARARLILIK İYİLEŞTİRMESİ: Yarış koşullarını (race conditions) önlemek için,
      // oturum açıldığında sunucu tarafında anında bir senkronizasyon tetikle.
      // Bu, kullanıcının uygulama açılır açılmaz en güncel premium durumunu
      // görmesini sağlar. Hatalar burada yakalanır ve loglanır, ancak akışı
      // engellemez (ateşle ve unut).
      _triggerServerSideSync();


      // Oturum açan kullanıcının admin yetkisini kontrol et ve ayarla.
      // Bu işlem arka planda sessizce yapılır.
      _updateAdminClaim(user);

      // Yeni giriş için bildirim token'ını yenile
      Future.delayed(const Duration(seconds: 1), () async {
        try {
          await NotificationService.instance.refreshTokenOnLogin();
        } catch (e) {
          print("Bildirim token yenileme hatası (güvenli): $e");
        }
      });

      // --- AdMob COPPA KONFİGÜRASYONU: Kullanıcı yaşına göre güncelle ---
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          final userProfile = await ref.read(userProfileProvider.future);
          if (userProfile != null) {
            await AdMobService().updateUserAgeConfiguration(
              dateOfBirth: userProfile.dateOfBirth,
            );
          }
        } catch (e) {
          print("AdMob configuration update failed (safe to ignore): $e");
        }
      });

      // --- ZİYARET KAYDI: user_activity aylık dokümanına yaz ---
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          if (state.hasValue) {
            final firestoreService = ref.read(firestoreServiceProvider);
            await firestoreService.recordUserVisit(user.uid);
            // Görev ilerlemesini tetikle (aksiyon bazlı)
            ref.read(questNotifierProvider.notifier).userLoggedInOrOpenedApp();
          }
        } catch (e) {
          print("Quest update on auth change failed (safe to ignore on startup): $e");
        }
      });
      // ------------------------------------
    }
  }

  Future<void> _updateAdminClaim(User user) async {
    // Admin claim güncellemesi sadece geliştirme ortamında veya özel durumlarda gereklidir
    // Normal kullanıcılar için atlanır
    try {
      // DÜZELTME: Fonksiyon adı yanlıştı ('setSelfAdmin').
      // index.js içinde exports.admin = admin; olduğu için gerçek callable adı 'admin-setSelfAdmin'.
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('admin-setSelfAdmin');
      await callable.call();
      await user.getIdTokenResult(true); // claimleri yenile
      print('Admin claim updated successfully.');
    } catch (e) {
      // Bu hata normal kullanıcılar için beklenen bir durumdur
      // Sadece debug modda log'la
      if (kDebugMode) {
        debugPrint('Admin claim update (normal users will fail): $e');
      }
    }
  }

  // Sunucu tarafında anında premium senkronizasyonu tetikleyen yardımcı fonksiyon.
  // THROTTLE KORUMASLI: Son çağrıdan 30 saniye geçmediyse çağrılmaz
  DateTime? _lastSyncAttempt;
  Future<void> _triggerServerSideSync() async {
    // Throttle kontrolü: Son 60 saniyede zaten çağrıldıysa atla
    final now = DateTime.now();
    if (_lastSyncAttempt != null && now.difference(_lastSyncAttempt!) < const Duration(seconds: 60)) {
      print("Premium sync throttled - son çağrıdan 60 saniye geçmedi, atlanıyor.");
      return;
    }

    _lastSyncAttempt = now;

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('premium-syncRevenueCatPremiumCallable');
      await callable.call();
      print("Premium sync başarılı.");
    } catch (e) {
      // Bu hata, kullanıcının arayüzünü engellememelidir.
      // Genellikle geçici bir ağ sorunu veya rate limiting'den kaynaklanır.
      // Webhook zaten durumu eninde sonunda düzeltecektir.
      print("Sunucu tarafı anında senkronizasyon hatası (güvenli): $e");
    }
  }


  Future<void> signIn({required String email, required String password}) {
    final authRepository = ref.read(authRepositoryProvider);
    return authRepository.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUp({
    required String firstName,
    required String lastName,
    required String username,
    String? gender,
    DateTime? dateOfBirth,
    required String email,
    required String password,
  }) {
    final authRepository = ref.read(authRepositoryProvider);
    return authRepository.signUpWithEmailAndPassword(
      firstName: firstName,
      lastName: lastName,
      username: username,
      gender: gender,
      dateOfBirth: dateOfBirth,
      email: email,
      password: password,
    );
  }

  Future<void> _logInToRevenueCat(String uid) async {
    try {
      await Purchases.logIn(uid);
    } catch (e) {
      print("RevenueCat login error (safe to ignore): $e");
    }
  }

  Future<void> _logOutFromRevenueCat() async {
    try {
      // DÜZELTME: Kullanıcı oturumunu sonlandırır ve yerel önbelleği temizler.
      // Bu paketin eski sürümlerinde, bu işlem için `logOut` metodu kullanılır.
      // Daha yeni sürümlerde bu metodun adı `reset` olarak değiştirilmiştir.
      // Projedeki `purchases_flutter: ^9.7.1` sürümü için doğru kullanım budur.
      await Purchases.logOut();
    } catch (e) {
      print("RevenueCat logOut error (safe to ignore): $e");
    }
  }

  Future<void> signOut() async {
    await _logOutFromRevenueCat();
    final authRepository = ref.read(authRepositoryProvider);
    await authRepository.signOut();
    // Oturum kapatıldıktan sonra kullanıcıya özel verileri temizle
    ref.invalidate(userProfileProvider);
  }

  Future<void> updatePassword({required String currentPassword, required String newPassword}) {
    final authRepository = ref.read(authRepositoryProvider);
    return authRepository.updatePassword(currentPassword: currentPassword, newPassword: newPassword);
  }

  Future<void> resetPassword(String email) {
    final authRepository = ref.read(authRepositoryProvider);
    return authRepository.resetPassword(email);
  }

  Future<void> signInWithGoogle() async {
    // Google sign-in'den önce mevcut RevenueCat kullanıcısını temizle
    await _logOutFromRevenueCat();
    final authRepository = ref.read(authRepositoryProvider);
    await authRepository.signInWithGoogle();
  }
}