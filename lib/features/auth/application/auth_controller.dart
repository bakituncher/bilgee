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
import '../../../core/services/revenuecat_service.dart'; // RevenueCat Service
import '../../../shared/streak/streak_milestone_notifier.dart';

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

    // RevenueCat müşteri bilgisi dinleyicisini GÜVENLİ şekilde başlat
    // Bu, RevenueCat'in initialize edilmesinden SONRA çalışacak
    _setupRevenueCatListener();

    ref.onDispose(() {
      authSubscription.cancel();
    });

    return authStream;
  }

  // RevenueCat listener'ını güvenli ve asenkron şekilde kur
  void _setupRevenueCatListener() {
    Future.microtask(() async {
      try {
        // RevenueCat'in TAM OLARAK başlatılmasını bekle
        // ensureInitialized, init tamamlanana kadar bekleyecek
        if (kDebugMode) {
          debugPrint('🔄 RevenueCat listener kuruluyor...');
        }

        await RevenueCatService.ensureInitialized().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            if (kDebugMode) {
              debugPrint('⚠️ RevenueCat initialization timeout, listener atlanıyor');
            }
            throw TimeoutException('RevenueCat not initialized in time');
          },
        );

        // iOS için ek güvenlik: SDK'nın tam olarak hazır olması için kısa bir bekleme
        await Future.delayed(const Duration(milliseconds: 500));

        // Listener'ı kur - addCustomerInfoUpdateListener kullan
        // Bu, RevenueCat SDK'nın resmi listener yöntemidir
        Purchases.addCustomerInfoUpdateListener((CustomerInfo info) {
          if (kDebugMode) {
            debugPrint('📱 RevenueCat CustomerInfo güncellendi');
            debugPrint('   Active entitlements: ${info.entitlements.active.keys.join(", ")}');
          }

          // Premium durumunu kontrol et
          // isPremium değişkeni kullanılmadığı için kaldırıldı

          // Sunucu senkronizasyonunu tetikle
          _triggerServerSideSync();

          // User profile'ı yenile
          ref.invalidate(userProfileProvider);
        });

        if (kDebugMode) {
          debugPrint('✅ RevenueCat listener başarıyla kuruldu');
        }
      } catch (e, stackTrace) {
        // RevenueCat henüz başlatılmamışsa veya hata varsa sessizce logla
        if (kDebugMode) {
          debugPrint('⚠️ RevenueCat listener kurulamadı (güvenli): $e');
          debugPrint('   Stack trace: $stackTrace');
        }
      }
    });
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
      // Microtask ile UI thread'i bloklamadan çalıştır
      Future.microtask(() async {
        try {
          await NotificationService.instance.refreshTokenOnLogin();
        } catch (e) {
          print("Bildirim token yenileme hatası (güvenli): $e");
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

      // --- LOGIN STREAK: Her gün ilk girişte streak güncelle ---
      Future.delayed(const Duration(seconds: 3), () async {
        try {
          if (!state.hasValue) return;
          final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
              .httpsCallable('users-recordLoginStreak');
          final result = await callable.call();
          final data = result.data as Map<String, dynamic>?;
          if (data != null && data['isMilestone'] == true && data['isNewDay'] == true) {
            final streak = (data['streak'] as num?)?.toInt() ?? 0;
            if (streak > 0) {
              ref.read(streakMilestoneProvider.notifier).showMilestone(streak);
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('recordLoginStreak hatası (güvenli): $e');
          }
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
  }) async {
    final authRepository = ref.read(authRepositoryProvider);

    // App Check SDK otomatik olarak token'ı ekler
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
      // RevenueCat'in başlatıldığından emin ol
      await Future.delayed(const Duration(milliseconds: 200));
      await Purchases.logIn(uid);
      if (kDebugMode) {
        debugPrint('✅ RevenueCat logIn başarılı: $uid');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("⚠️ RevenueCat login error (güvenli): $e");
      }
    }
  }

  Future<void> _logOutFromRevenueCat() async {
    try {
      await Purchases.logOut();
      if (kDebugMode) {
        debugPrint('✅ RevenueCat logOut başarılı');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("⚠️ RevenueCat logOut error (güvenli): $e");
      }
    }
  }

  Future<void> signOut() async {
    // PERFORMANS İYİLEŞTİRMESİ: Yan görevleri (RevenueCat) paralel olarak
    // çalıştır ve hata vermesin diye güvenli şekilde sar. Kullanıcı deneyimi için
    // bu işlemlerin bitmesini beklemeden Firebase'den hemen çıkış yap.

    // Güvenli çalıştırıcı yardımcı fonksiyonu
    Future<void> safeRun(Future<void> Function() action) async {
      try {
        await action();
      } catch (e) {
        if (kDebugMode) debugPrint("Cleanup error (ignored): $e");
      }
    }

    // Temizlik işlemlerini paralel başlat (kullanıcıyı bekletmeden)
    final cleanupFuture = Future.wait([
      safeRun(() => _logOutFromRevenueCat()),
    ]);

    // Firebase çıkışını hemen yap (cleanup bitmesini bekleme)
    final authRepository = ref.read(authRepositoryProvider);
    await authRepository.signOut();

    // Oturum kapatıldıktan sonra kullanıcıya özel verileri temizle
    ref.invalidate(userProfileProvider);

    // Temizlik işlemlerinin arka planda tamamlanmasını bekle (opsiyonel)
    // Bu satırı kaldırırsanız daha da hızlı olur, ancak güvenlik için bırakılabilir
    cleanupFuture.catchError((e) {
      if (kDebugMode) debugPrint("Background cleanup error (safe): $e");
      return []; // List<void> dönmek için boş liste
    });
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

  Future<void> signInWithApple() async {
    // Apple sign-in'den önce mevcut RevenueCat kullanıcısını temizle
    await _logOutFromRevenueCat();
    final authRepository = ref.read(authRepositoryProvider);
    await authRepository.signInWithApple();
  }
}