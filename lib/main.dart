// lib/main.dart
//Rahman ve Rahim olan Allah'ın adıyla
//Bismilahirrahmanirrahim
import 'dart:async';
import 'dart:io';
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
import 'package:url_launcher/url_launcher.dart';
import 'package:taktik/core/services/firebase_analytics_service.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taktik/features/coach/models/saved_solution_model.dart';
import 'package:taktik/data/providers/premium_provider.dart';

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
    WidgetsFlutterBinding.ensureInitialized();

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

    // 1.5. HIVE BAŞLATMA (Firebase'den önce)
    try {
      await Hive.initFlutter();
      Hive.registerAdapter(SavedSolutionAdapter());
      await Hive.openBox<SavedSolutionModel>('saved_solutions_box');
      if (kDebugMode) {
        debugPrint('[Hive] ✅ Başarıyla başlatıldı');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Hive] ❌ Başlatılamadı: $e');
        debugPrint(st.toString());
      }
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'Hive initialization failed',
        fatal: false,
      );
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
    if (kDebugMode) {
      // DebugView için debug buildlerde etiket ve kısa oturum ayarı
      try {
        await FirebaseAnalytics.instance.setSessionTimeoutDuration(const Duration(minutes: 5));
        await FirebaseAnalytics.instance.logEvent(name: 'debug_app_start', parameters: {
          'ts': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (_) {}
    }

    // 3. REVENUECAT BAŞLATMA (KRİTİK - BURAYA TAŞINDI)
    // UI çizilmeden önce RevenueCat'in hazır olması şarttır, aksi takdirde iOS'ta çökme yaşanır.
    // Başlatma sırasını garanti altına almak için await kullanıyoruz.
    try {
      if (kDebugMode) {
        debugPrint('[RevenueCat] Başlatılıyor...');
      }

      await RevenueCatService.init().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          if (kDebugMode) debugPrint('[RevenueCat] Initialization timeout');
          throw TimeoutException('RevenueCat initialization timeout');
        },
      );

      if (kDebugMode) {
        debugPrint('[RevenueCat] ✅ Başarıyla başlatıldı');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[RevenueCat] ❌ Initialization failed: $e');
        debugPrint('[RevenueCat] Stack trace: $stackTrace');
      }
      // RevenueCat hatası uygulamanın açılmasını engellememeli ama loglanmalı
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'RevenueCat initialization failed',
        fatal: false,
      );
    }

    // 4. UYGULAMAYI BAŞLAT
    runApp(const ProviderScope(child: BilgeAiApp()));

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
  VoidCallback? _routerListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = ref.read(goRouterProvider);

      // Navigation analytics: listen to route changes and log screen views
      void logCurrentRoute() {
        try {
          final config = router.routerDelegate.currentConfiguration;
          // Varsayılan bir değer atayalım
          String screenName = router.routeInformationProvider.value.location ?? '/';

          if (config.isNotEmpty) {
            final last = config.last;

            // --- DEĞİŞİKLİK BURADA ---
            // Öncelik: GoRouter'da tanımlı olan 'name' özelliğini kullan (Örn: 'Library', 'Settings')
            // Bu sayede /blog/yazi-1 ve /blog/yazi-2 tek bir 'BlogDetail' olarak görünür.
            if (last.route is GoRoute && (last.route as GoRoute).name != null) {
              screenName = (last.route as GoRoute).name!;
            } else {
              // Eğer name yoksa, slash işaretini temizleyerek path'i kullan
              // Örn: "/library" -> "library"
              String location = last.matchedLocation;
              if (location.startsWith('/')) {
                location = location.substring(1);
              }
              // Kök dizin boş kalırsa 'Splash' veya 'Home' deyin
              if (location.isEmpty) {
                location = 'Splash';
              }
              screenName = location;
            }
            // -------------------------
          }

          // screen_view (manual)
          FirebaseAnalyticsService.logScreenView(screenName: screenName);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[Analytics] route log error: $e');
          }
        }
      }

      // Log initial
      logCurrentRoute();
      // Listen ongoing changes via routerDelegate (ChangeNotifier)
      _routerListener = logCurrentRoute;
      router.routerDelegate.addListener(_routerListener!);

      NotificationService.instance.initialize(onNavigate: (route) async {
        // 1. Mağaza Yönlendirmesi Kontrolü
        if (route == '/store' || route == 'UPDATE_APP') {
          if (Platform.isAndroid || Platform.isIOS) {
            // Android Paket Adı: com.codenzi.taktik
            // iOS App Store ID: 6755930518
            final appId = Platform.isAndroid ? 'com.codenzi.taktik' : '6755930518';

            final url = Uri.parse(
              Platform.isAndroid
                ? "market://details?id=$appId"
                : "https://apps.apple.com/app/id$appId"
            );

            // Önce market protokolü ile açmayı dene (Mağaza uygulaması açılır)
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            } else {
              // Olmazsa web linki olarak aç
              final webUrl = Uri.parse(
                Platform.isAndroid
                  ? "https://play.google.com/store/apps/details?id=$appId"
                  : "https://apps.apple.com/app/id$appId"
              );
              if (await canLaunchUrl(webUrl)) {
                 await launchUrl(webUrl, mode: LaunchMode.externalApplication);
              }
            }
          }
          return;
        }

        // 2. HTTP Link Kontrolü (Web sitesine yönlendirme gerekirse)
        if (route.startsWith('http')) {
           final uri = Uri.parse(route);
           if (await canLaunchUrl(uri)) {
             await launchUrl(uri, mode: LaunchMode.externalApplication);
           }
           return;
        }

        // 3. Premium Gate Kontrolü - AI Hub özellikleri için
        // Kullanıcı premium değilse, offer ekranına yönlendir
        final premiumRoutes = {
          '/ai-hub/question-solver': {
            'title': 'Soru Çözücü',
            'subtitle': 'Anında çözüm cebinde.',
            'icon': Icons.camera_enhance_rounded,
            'color': Colors.orangeAccent,
            'marketingTitle': 'Soruda Takılma!',
            'marketingSubtitle': 'Yapamadığın sorunun fotoğrafını çek, Taktik Tavşan adım adım çözümünü anlatsın.',
            'redirectRoute': '/ai-hub/question-solver',
          },
          '/ai-hub/weakness-workshop': {
            'title': 'Etüt Odası',
            'subtitle': 'Kişiye özel çalışma materyalleri.',
            'iconName': 'menu_book',
            'color': const Color(0xFF8B5CF6),
            'marketingTitle': 'Eksiklerini Kapat!',
            'marketingSubtitle': 'Yapay zeka sadece eksik olduğun konulara özel konu özeti ve test soruları üretsin.',
            'redirectRoute': '/ai-hub/weakness-workshop',
          },
          '/ai-hub/strategic-planning': {
            'title': 'Haftalık Stratejist',
            'subtitle': 'Sana özel ders programı.',
            'iconName': 'calendar_month',
            'color': const Color(0xFF10B981),
            'marketingTitle': 'Programın Hazır!',
            'marketingSubtitle': 'Eksik konularına ve müsait zamanına göre sana en uygun haftalık ders çalışma programını saniyeler içinde oluştur.',
            'redirectRoute': '/ai-hub/strategic-planning',
          },
        };

        if (premiumRoutes.containsKey(route)) {
          final isPremium = ref.read(premiumStatusProvider);
          if (!isPremium) {
            // Premium değilse offer ekranına yönlendir
            router.go('/ai-hub/offer', extra: premiumRoutes[route]);
            return;
          }
        }

        // 4. Uygulama İçi Rota (Mevcut davranış)
        if (route.isNotEmpty) {
           router.go(route);
        }
      });
    });
  }

  @override
  void dispose() {
    // Detach router listener if attached
    try {
      final router = ref.read(goRouterProvider);
      if (_routerListener != null) {
        router.routerDelegate.removeListener(_routerListener!);
      }
    } catch (_) {}
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

    // İnternet bağlantısını kontrol et
    final connectivityAsync = ref.watch(connectivityProvider);

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

    // İnternet bağlantısı yoksa NoInternetScreen göster
    return connectivityAsync.when(
      data: (isConnected) {
        if (!isConnected) {
          return MaterialApp(
            title: 'Taktik',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            home: const NoInternetScreen(),
          );
        }

        return MaterialApp.router(
          title: 'Taktik',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          routerConfig: router,
        );
      },
      loading: () => MaterialApp(
        title: 'Taktik',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (_, __) => MaterialApp.router(
        title: 'Taktik',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: router,
      ),
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
