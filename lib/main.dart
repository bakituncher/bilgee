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

  await initializeDateFormatting('tr_TR', null);
  // Asset tabanlı içerikleri önceden yükle
  await StrategyPrompts.preload();
  await QuestArmoryLoader.preload();
  runApp(const ProviderScope(child: BilgeAiApp()));
}

class BilgeAiApp extends ConsumerWidget {
  const BilgeAiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

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