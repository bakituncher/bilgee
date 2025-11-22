// lib/main.dart
//Rahman ve Rahim olan Allah'ın adıyla
//Bismilahirrahmanirrahim
import 'dart:async';
import 'dart:ui';
import 'package:taktik/core/navigation/app_router.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/core/theme/theme_provider.dart'; // EKLENDİ
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart'; // kDebugMode için bu import gerekli
import 'package:flutter/material.dart';
// SystemChrome için gerekli
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'package:taktik/core/prompts/strategy_prompts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'shared/notifications/notification_service.dart';
import 'package:taktik/core/prompts/prompt_remote.dart';
import 'package:taktik/core/services/revenuecat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:taktik/core/services/admob_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Arka plan izole içinde Firebase'i başlatmak önemli
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
  await NotificationService.firebaseMessagingBackgroundHandler(message);
}

void main() async {
  // Global hata yakalama (Flutter ve Dart)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('[FlutterError] ${details.exceptionAsString()}');
      debugPrint(details.stack?.toString());
    }
    // Firebase Crashlytics'e hata gönder
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  // Asenkron hatalar için de Crashlytics'e gönder
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await runZonedGuarded(() async {
    // Binding ve runApp aynı zone'da olmalı
    WidgetsFlutterBinding.ensureInitialized();

    // Environment variables'ı yükle
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Init] .env dosyası yüklenemedi: $e');
      }
    }

    // Android 15+ SDK 35 için zorunlu edge-to-edge ayarları - öncelik sırası önemli
    // Artık main'de değil, tema değişimine duyarlı olarak BilgeAiApp içinde yapılacak.
    // AppTheme.configureSystemUI();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Init] Firebase başlatılamadı: $e');
        debugPrint(st.toString());
      }
      runApp(const ErrorApp(message: 'Başlatma hatası: Firebase yüklenemedi.'));
      return;
    }

    // Firebase Crashlytics'i yapılandır
    // Debug modunda Crashlytics'i etkinleştir (isteğe bağlı)
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

    // Firebase Analytics'i yapılandır - AD_ID kullanmadan
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

    // Initialize RevenueCat
    try {
      await RevenueCatService.init();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RevenueCat] Initialization failed: $e');
      }
    }

    // Initialize AdMob - KALDIRILDI
    // AdMob artık AuthController içinde kullanıcı premium durumuna göre
    // başlatılıyor veya engelleniyor (kaynak tasarrufu).
    // Eski kod: await AdMobService().initialize();

    // App Check'i başlat ve güvenlik sağlayıcılarını aktive et.
    // SafetyNet yerine Play Integrity API kullanımı (Android 15+ uyumluluk)
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity, // SafetyNet yerine Play Integrity
        appleProvider: kDebugMode
            ? AppleProvider.debug
            : AppleProvider.appAttest,
      );
    } catch (e) {
      // iOS'ta App Attest desteklenmiyorsa DeviceCheck'e düş
      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity, // Fallback'te de Play Integrity
          appleProvider: kDebugMode
              ? AppleProvider.debug
              : AppleProvider.deviceCheck,
        );
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('[AppCheck] Play Integrity aktivasyon başarısız: $e | DeviceCheck fallback hata: $e2');
        }
      }
    }

    // App Check tokenlarını otomatik yenile
    try {
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
      // İlk çağrılarda boş token durumlarını azaltmak için token üretimini tetikle
      try {
        await FirebaseAppCheck.instance.getToken();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AppCheck] İlk token alınamadı: $e');
        }
      }
    } catch (_) {}

    // FCM background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Tarih yerelleştirme (hata olursa uygulamayı engellemesin)
    try {
      await initializeDateFormatting('tr_TR', null);
    } catch (e) {
      if (kDebugMode) debugPrint('[Intl] Tarih format başlatılamadı: $e');
    }

    // Uygulamayı hızlıca ayağa kaldır
    runApp(const ProviderScope(child: BilgeAiApp()));

    // Ağ bağımlı preload işleri uygulamayı bloklamasın
    // RemotePrompts, StrategyPrompts ve QuestArmory eşzamanlı ve hata yalıtımlı
    Future.microtask(() async {
      try {
        await Future.wait([
          RemotePrompts.preloadAndWatch(),
          StrategyPrompts.preload(),
        ]);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[Preload] Hata: $e');
          debugPrint(st.toString());
        }
      }
    });
  }, (error, stack) {
    if (kDebugMode) {
      debugPrint('[Zoned] Yakalanmamış hata: $error');
      debugPrint(stack.toString());
    }
    // Firebase Crashlytics'e hata gönder
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class BilgeAiApp extends ConsumerStatefulWidget {
  const BilgeAiApp({super.key});

  @override
  ConsumerState<BilgeAiApp> createState() => _BilgeAiAppState();
}

class _BilgeAiAppState extends ConsumerState<BilgeAiApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // İlk bildirim servisi başlatma
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = ref.read(goRouterProvider);
      NotificationService.instance.initialize(onNavigate: (route) {
        router.go(route);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    // Sistem teması değiştiğinde, eğer kullanıcı "Sistem" modunu seçtiyse,
    // UI'ı yeniden çizmek için state'i tazelemeye gerek kalmaz,
    // MaterialApp değişikliği otomatik olarak yönetir.
    // Ancak SystemUIOverlay'ı manuel güncellememiz gerekiyor.
    final themeMode = ref.read(themeModeNotifierProvider);
    if (themeMode == ThemeMode.system) {
      final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      AppTheme.configureSystemUI(platformBrightness);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeNotifierProvider);

    // Tema her değiştiğinde (açık, koyu veya sistem) doğru UI overlay'i ayarla
    final Brightness currentBrightness;
    switch (themeMode) {
      case ThemeMode.light:
        currentBrightness = Brightness.light;
        break;
      case ThemeMode.dark:
        currentBrightness = Brightness.dark;
        break;
      case ThemeMode.system:
        currentBrightness = MediaQuery.of(context).platformBrightness;
        break;
    }
    AppTheme.configureSystemUI(currentBrightness);

    return MaterialApp.router(
      title: 'Taktik',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
