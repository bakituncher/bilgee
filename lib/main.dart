// lib/main.dart
//Rahman ve Rahim olan Allah'ın adıyla
//Bismilahirrahmanirrahim
import 'package:bilge_ai/core/navigation/app_router.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'; // kDebugMode için bu import gerekli
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'package:bilge_ai/core/prompts/strategy_prompts.dart';
import 'package:bilge_ai/features/quests/quest_armory.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'shared/notifications/notification_service.dart';
import 'package:bilge_ai/core/prompts/prompt_remote.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.firebaseMessagingBackgroundHandler(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check'i başlat ve güvenlik sağlayıcılarını aktive et.
  await FirebaseAppCheck.instance.activate(
    // UYGULAMA TEST MODUNDAYKEN (DEBUG) BU SAĞLAYICIYI KULLAN
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );

  // App Check tokenlarını otomatik yenile (özellikle üretimde Play Integrity/App Attest sürekliliği için)
  await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
  // İlk çağrılarda boş token durumlarını azaltmak için token üretimini tetikle
  try {
    await FirebaseAppCheck.instance.getToken();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[AppCheck] İlk token alınamadı: $e');
    }
  }

  // FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await initializeDateFormatting('tr_TR', null);
  // Firestore tabanlı promptları önceden yükle ve canlı izlemeyi başlat
  await RemotePrompts.preloadAndWatch();
  // Asset tabanlı içerikleri önceden yükle (uzak yoksa yedek)
  await StrategyPrompts.preload();
  await QuestArmoryLoader.preload();
  runApp(const ProviderScope(child: BilgeAiApp()));
}

class BilgeAiApp extends ConsumerWidget {
  const BilgeAiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    // Bildirim servisini başlat (tek seferlik)
    NotificationService.instance.initialize(onNavigate: (route) {
      router.go(route);
    });

    return MaterialApp.router(
      title: 'BilgeAi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.modernTheme,
      darkTheme: AppTheme.modernTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}