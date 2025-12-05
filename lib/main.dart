// lib/main.dart
//Rahman ve Rahim olan Allah'ın adıyla
//Bismilahirrahmanirrahim
import 'dart:async';
import 'dart:ui';
import 'package:taktik/core/navigation/app_router.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/core/theme/theme_provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'package:taktik/core/prompts/strategy_prompts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'shared/notifications/notification_service.dart';
import 'package:taktik/core/prompts/prompt_remote.dart';
import 'package:taktik/core/services/revenuecat_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:taktik/core/services/connectivity_service.dart';
import 'package:taktik/shared/screens/no_internet_screen.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
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
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await runZonedGuarded(() async {
    WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    // Splash screen'i koru - JS Bridge/Native yüklenirken beyaz ekranı engeller
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

    // 1. .env yükle
    try {
      await dotenv.load(fileName: ".env").timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          if (kDebugMode) debugPrint('[Init] .env yükleme timeout');
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Init] .env dosyası yüklenemedi: $e');
      }
    }

    // 2. Firebase Başlat
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw TimeoutException('Firebase initialization timeout');
        },
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Init] Firebase başlatılamadı: $e');
        debugPrint(st.toString());
      }
      runApp(const ErrorApp(message: 'Başlatma hatası: Firebase yüklenemedi.'));
      return;
    }

    // Firebase servislerini yapılandır
    FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
    FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

    // 3. REVENUECAT BAŞLATMA
    try {
      await RevenueCatService.init().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          if (kDebugMode) debugPrint('[RevenueCat] Initialization timeout');
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RevenueCat] Initialization failed: $e');
      }
    }

    // 4. UYGULAMAYI BAŞLAT
    runApp(const ProviderScope(child: BilgeAiApp()));

    // Uygulama başlatıldıktan sonra splash screen'i kaldır
    FlutterNativeSplash.remove();

    // --- Diğer "Non-Kritik" Servisler Arka Planda Başlatılabilir ---

    // App Check
    Future.microtask(() async {
      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider: kDebugMode
              ? AppleProvider.debug
              : AppleProvider.appAttest,
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            if (kDebugMode) debugPrint('[AppCheck] Activation timeout');
          },
        );
      } catch (e) {
        try {
          await FirebaseAppCheck.instance.activate(
            androidProvider: kDebugMode
                ? AndroidProvider.debug
                : AndroidProvider.playIntegrity,
            appleProvider: kDebugMode
                ? AppleProvider.debug
                : AppleProvider.deviceCheck,
          ).timeout(const Duration(seconds: 5));
        } catch (e2) {
          if (kDebugMode) {
            debugPrint('[AppCheck] Fallback failed: $e2');
          }
        }
      }

      try {
        await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
        try {
          await FirebaseAppCheck.instance.getToken().timeout(const Duration(seconds: 3));
        } catch (e) {
          if (kDebugMode) debugPrint('[AppCheck] İlk token alınamadı: $e');
        }
      } catch (_) {}
    });

    // FCM Handler
    Future.microtask(() {
      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (e) {
        if (kDebugMode) debugPrint('[FCM] Background handler kaydedilemedi: $e');
      }
    });

    // Tarih Yerelleştirme
    Future.microtask(() async {
      try {
        await initializeDateFormatting('tr_TR', null).timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            if (kDebugMode) debugPrint('[Intl] Tarih format timeout');
          },
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[Intl] Tarih format başlatılamadı: $e');
      }
    });

    // Preload İşlemleri
    Future.microtask(() async {
      try {
        await Future.wait([
          RemotePrompts.preloadAndWatch(),
          StrategyPrompts.preload(),
        ]).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            if (kDebugMode) debugPrint('[Preload] Timeout - devam ediyor');
            return <void>[];
          },
        );
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

    // Hot Reload sorununu çözmek için yapıyı değiştirdik.
    // MaterialApp.router'ı sürekli yeniden oluşturmak (rebuild) yerine,
    // bağlantı kontrolünü builder içinde yapıyoruz.
    return MaterialApp.router(
      title: 'Taktik',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        // İnternet bağlantısını burada dinle
        final connectivityAsync = ref.watch(connectivityProvider);

        return connectivityAsync.when(
          data: (isConnected) {
            if (!isConnected) return const NoInternetScreen();
            return child ?? const SizedBox();
          },
          // Hot reload veya loading durumunda UI'ı bozma, child'ı göster
          loading: () => child ?? const SizedBox(),
          // Hata durumunda da akışı bozma
          error: (_, __) => child ?? const SizedBox(),
        );
      },
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
