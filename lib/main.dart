// lib/main.dart
// Rahman ve Rahim olan Allah'ın adıyla
// Bismilahirrahmanirrahim

import 'dart:async';
import 'dart:io';
import 'dart:ui';

// Core Imports
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Firebase Imports
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

// Project Imports
import 'package:taktik/core/navigation/app_router.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/core/theme/theme_provider.dart';
import 'package:taktik/core/prompts/strategy_prompts.dart';
import 'package:taktik/core/prompts/prompt_remote.dart';
import 'package:taktik/core/services/revenuecat_service.dart';
import 'package:taktik/core/services/connectivity_service.dart';
import 'package:taktik/core/services/firebase_analytics_service.dart';
import 'package:taktik/shared/notifications/notification_service.dart';
import 'package:taktik/shared/screens/no_internet_screen.dart';
import 'package:taktik/shared/screens/force_update_screen.dart';
import 'package:taktik/shared/screens/time_error_screen.dart';
import 'package:taktik/features/coach/models/saved_solution_model.dart';
import 'package:taktik/features/coach/models/saved_content_model.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:taktik/data/providers/version_check_provider.dart';
import 'package:taktik/data/providers/time_check_provider.dart';

/// Firebase Messaging Arka Plan İşleyicisi
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // Firebase zaten başlatılmış olabilir, hatayı yutuyoruz.
  }
  // Bildirim servisine devret
  await NotificationService.firebaseMessagingBackgroundHandler(message);
}

void main() async {
  // Tüm uygulamayı Hata Yakalama Bölgesi (Zone) içinde çalıştır
  await runZonedGuarded(() async {
    // 1. Flutter Motorunu Başlat
    WidgetsFlutterBinding.ensureInitialized();

    // 2. Çevresel Değişkenleri (.env) Yükle
    try {
      await dotenv.load(fileName: ".env").timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          if (kDebugMode) debugPrint('[Init] .env yükleme zaman aşımı (timeout)');
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Init] .env dosyası yüklenemedi: $e');
    }

    // 3. HIVE Veritabanını Başlat (Firebase'den önce)
    try {
      await Hive.initFlutter();
      // Adapter'ları kaydet (TypeID çakışmalarına dikkat edin)
      Hive.registerAdapter(SavedSolutionAdapter());     // TypeId: 0
      Hive.registerAdapter(SavedContentAdapter());      // TypeId: 1
      Hive.registerAdapter(SavedContentTypeAdapter()); // TypeId: 2
      await Hive.openBox<SavedSolutionModel>('saved_solutions_box');
      await Hive.openBox<SavedContentModel>('saved_content_box');
      if (kDebugMode) debugPrint('[Hive] ✅ Başarıyla başlatıldı');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Hive] ❌ Başlatılamadı: $e');
        debugPrint(st.toString());
      }
    }

    // 4. Firebase Başlat
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
      // Firebase olmadan uygulama çalışamaz, hata ekranı göster.
      runApp(const ErrorApp(message: 'Başlatma hatası: Bağlantı servisleri yüklenemedi.'));
      return;
    }

    // 5. FCM Background Handler Kaydı (runApp'ten ÖNCE yapılmalı)
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      if (kDebugMode) debugPrint('[FCM] Background handler kaydedildi.');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] Background handler kaydedilemedi: $e');
    }

    // 6. Hata Raporlama (Crashlytics) Ayarları

    // Flutter framework hataları
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (kDebugMode) {
        debugPrint('[FlutterError] ${details.exceptionAsString()}');
        debugPrint(details.stack?.toString());
      }
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    // Asenkron platform hataları
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Debug modunda loglamayı kapat, Prod modunda aç
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

    if (kDebugMode) {
      // DebugView testi için
      try {
        await FirebaseAnalytics.instance.setSessionTimeoutDuration(const Duration(minutes: 5));
        await FirebaseAnalytics.instance.logEvent(name: 'debug_app_start', parameters: {
          'ts': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (_) {}
    }

    // 7. App Check (Güvenlik) - Google Önerisi
    try {
      await FirebaseAppCheck.instance.activate(
        // Android: Debug modda test provider, production'da Play Integrity
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        // iOS/macOS: Debug modda test provider, production'da App Attest
        appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
      );
      if (kDebugMode) debugPrint('[AppCheck] ✅ Başlatıldı');
    } catch (e) {
      // App Check hatası kritik değil, uygulama çalışmaya devam edebilir
      if (kDebugMode) debugPrint('[AppCheck] ⚠️ Başlatılamadı: $e');
    }

    // 8. RevenueCat (Abonelik) Başlatma
    // Bu işlem, bildirimlerden gelen premium yönlendirmelerinin
    // doğru çalışması için runApp'ten önce yapılmalıdır.
    try {
      if (kDebugMode) debugPrint('[RevenueCat] Başlatılıyor...');

      await RevenueCatService.init().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          if (kDebugMode) debugPrint('[RevenueCat] Timeout');
          throw TimeoutException('RevenueCat initialization timeout');
        },
      );

      if (kDebugMode) debugPrint('[RevenueCat] ✅ Başarıyla başlatıldı');
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint('[RevenueCat] ❌ Başarısız: $e');
      FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'RevenueCat Failed', fatal: false);
    }

    // 9. Uygulamayı Başlat
    runApp(const ProviderScope(child: BilgeAiApp()));

    // 10. Arka Plan İşlemleri (UI bloklamaması için microtask)
    Future.microtask(() async {
      // Tarih formatı
      try {
        await initializeDateFormatting('tr_TR', null).timeout(const Duration(seconds: 2));
      } catch (_) {}

      // Prompt ve Strateji Preload
      try {
        await Future.wait([
          RemotePrompts.preloadAndWatch(),
          StrategyPrompts.preload(),
        ]).timeout(const Duration(seconds: 10));
      } catch (e) {
        if (kDebugMode) debugPrint('[Preload] Hata: $e');
      }
    });

  }, (error, stack) {
    // Zone Guard: Yakalanmamış en üst düzey hatalar
    if (kDebugMode) {
      debugPrint('[Zoned] Kritik Hata: $error');
      debugPrint(stack.toString());
    }
    if (Firebase.apps.isNotEmpty) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
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

    // Router ve Deep Link İşlemleri
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRouterAnalyticsAndDeepLinks();
    });
  }

  void _initializeRouterAnalyticsAndDeepLinks() {
    final router = ref.read(goRouterProvider);

    // 1. Ekran İzleme (Analytics) Fonksiyonu
    void logCurrentRoute() {
      try {
        final config = router.routerDelegate.currentConfiguration;
        String screenName = router.routeInformationProvider.value.location ?? '/';

        if (config.isNotEmpty) {
          final last = config.last;
          if (last.route is GoRoute && (last.route as GoRoute).name != null) {
            screenName = (last.route as GoRoute).name!;
          } else {
            String location = last.matchedLocation;
            if (location.startsWith('/')) location = location.substring(1);
            if (location.isEmpty) location = 'Splash';
            screenName = location;
          }
        }
        FirebaseAnalyticsService.logScreenView(screenName: screenName);
      } catch (e) {
        if (kDebugMode) debugPrint('[Analytics] Log hatası: $e');
      }
    }

    // İlk açılış logu
    logCurrentRoute();

    // Değişiklikleri dinle
    _routerListener = logCurrentRoute;
    router.routerDelegate.addListener(_routerListener!);

    // 2. Bildirim ve Deep Link Yönlendirme Mantığı
    NotificationService.instance.initialize(onNavigate: (route) async {
      try {
        // A) Mağaza Yönlendirmeleri
        if (route == '/store' || route == 'UPDATE_APP') {
          await _handleStoreRedirect();
          return;
        }

        // B) Dış Linkler (Web)
        if (route.startsWith('http')) {
          final uri = Uri.parse(route);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          return;
        }

        // C) Premium Kilitli Rotalar (AI Hub)
        if (_isPremiumRoute(route)) {
          final isPremium = ref.read(premiumStatusProvider);
          if (!isPremium) {
            // Premium değilse teklif ekranına yönlendir
            final offerExtra = _getPremiumRouteDetails(route);
            router.go('/ai-hub/offer', extra: offerExtra);
            return;
          }
        }

        // D) Standart Uygulama İçi Rota
        if (route.isNotEmpty) {
          router.go(route);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Navigation] Yönlendirme hatası: $e');
      }
    });
  }

  /// Premium kontrolü gerektiren rotalar
  bool _isPremiumRoute(String route) {
    return _premiumRoutesMap.containsKey(route);
  }

  /// Premium rotası için UI detaylarını getir
  Map<String, dynamic>? _getPremiumRouteDetails(String route) {
    return _premiumRoutesMap[route];
  }

  /// Premium rotaların tanımları
  static final Map<String, Map<String, dynamic>> _premiumRoutesMap = {
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
      'marketingSubtitle': 'Taktik, sadece eksik olduğun konulara özel konu özeti ve test soruları üretsin.',
      'redirectRoute': '/ai-hub/weakness-workshop',
    },
    '/ai-hub/strategic-planning': {
      'title': 'Haftalık Planlama',
      'subtitle': 'Sana özel ders programı.',
      'iconName': 'calendar_month',
      'color': const Color(0xFF10B981),
      'marketingTitle': 'Programın Hazır!',
      'marketingSubtitle': 'Eksik konularına ve müsait zamanına göre sana en uygun haftalık ders çalışma programını saniyeler içinde oluştur.',
      'redirectRoute': '/ai-hub/strategic-planning',
    },
    '/ai-hub/mind-map': {
      'title': 'Zihin Haritası',
      'subtitle': 'Konuları görselleştir ve daha iyi anla.',
      'iconName': 'account_tree',
      'color': const Color(0xFF6366F1),
      'marketingTitle': 'Düşüncelerini Haritala!',
      'marketingSubtitle': 'Karmaşık konuları görsel zihin haritalarına dönüştür. Daha iyi anla, daha kolay hatırla.',
      'redirectRoute': '/ai-hub/mind-map',
    },
  };

  /// Mağazaya yönlendirme işlemi
  Future<void> _handleStoreRedirect() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final appId = Platform.isAndroid ? 'com.codenzi.taktik' : '6755930518';
    final marketUrl = Uri.parse(
        Platform.isAndroid
            ? "market://details?id=$appId"
            : "https://apps.apple.com/app/id$appId"
    );

    if (await canLaunchUrl(marketUrl)) {
      await launchUrl(marketUrl, mode: LaunchMode.externalApplication);
    } else {
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

  @override
  void dispose() {
    // Dinleyiciyi temizle
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Uygulama ön plana geldiğinde zaman kontrolünü ve versiyon kontrolünü yenile
      ref.invalidate(timeCheckProvider);
      ref.invalidate(versionCheckProvider);
    }
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

    // İnternet bağlantısı durumu
    final connectivityAsync = ref.watch(connectivityProvider);
    // Eğer null ise (ilk açılış), 'bağlı' varsayalım ki ekran flash yapmasın.
    // Sadece kesin olarak false dönerse offline ekranı gösterilsin.
    final isOffline = connectivityAsync.valueOrNull == false;

    // Zaman doğruluğu durumu
    final isTimeAccurateAsync = ref.watch(timeCheckProvider);
    final isTimeWrong = isTimeAccurateAsync.valueOrNull == false;

    // Sistem UI Overlay Ayarı (Status bar rengi vb.)
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
      // Builder ile tüm sayfaların üzerine global widget'lar (Overlay) ekliyoruz
      builder: (context, child) {
        // Versiyon kontrolü
        final versionCheckAsync = ref.watch(versionCheckProvider);

        return Stack(
          children: [
            // 1. Uygulama İçeriği
            if (child != null) child,

            // 2. Zorunlu Güncelleme Ekranı (En Üst Öncelik)
            // Eğer güncelleme zorunluysa, tüm uygulamanın üzerini kaplar
            if (versionCheckAsync.valueOrNull?.updateRequired == true)
              Positioned.fill(
                child: ForceUpdateScreen(
                  versionInfo: versionCheckAsync.value!,
                ),
              ),

            // 3. İnternet Yok Ekranı (Overlay)
            // Stack'in en üstünde durur, state kaybettirmez.
            // Zorunlu güncelleme yoksa gösterilir
            if (isOffline && versionCheckAsync.valueOrNull?.updateRequired != true)
              const Positioned.fill(
                child: NoInternetScreen(),
              ),

            // 4. Zaman Hatası Ekranı (Overlay)
            // İnternet varsa ve zaman yanlışsa gösterilir
            if (!isOffline && isTimeWrong && versionCheckAsync.valueOrNull?.updateRequired != true)
              const Positioned.fill(
                child: TimeErrorScreen(),
              ),
          ],
        );
      },
    );
  }
}

/// Kritik Hata Ekranı (Firebase vb. yüklenemezse)
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
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
