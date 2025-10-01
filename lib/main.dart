// lib/main.dart
//Rahman ve Rahim olan Allah'ın adıyla
//Bismilahirrahmanirrahim
import 'dart:async';
import 'package:taktik/core/navigation/app_router.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'; // kDebugMode için bu import gerekli
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemChrome için gerekli
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'package:taktik/core/prompts/strategy_prompts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'shared/notifications/notification_service.dart';
import 'package:taktik/core/prompts/prompt_remote.dart';

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
  };

  await runZonedGuarded(() async {
    // Binding ve runApp aynı zone'da olmalı
    WidgetsFlutterBinding.ensureInitialized();

    // Android 15+ SDK 35 için zorunlu edge-to-edge ayarları - öncelik sırası önemli
    AppTheme.configureSystemUI();

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
  });
}

class BilgeAiApp extends ConsumerWidget {
  const BilgeAiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    // Bildirim servisini post-frame'de başlat (tek seferlik ve build dışı yan etki)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.initialize(onNavigate: (route) {
        router.go(route);
      });
    });

    return MaterialApp.router(
      title: 'Taktik',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.modernTheme,
      darkTheme: AppTheme.modernTheme,
      themeMode: ThemeMode.dark,
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
      theme: AppTheme.modernTheme,
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
