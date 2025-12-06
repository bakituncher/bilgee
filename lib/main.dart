// lib/main.dart
// Rahman ve Rahim olan Allah'ın adıyla
// Bismilahirrahmanirrahim

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

// --- FIREBASE GERİ GELDİ ---
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// --- NAVIGATION & THEME ---
import 'package:taktik/core/navigation/app_router.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/core/theme/theme_provider.dart';
import 'package:taktik/core/services/connectivity_service.dart';
import 'package:taktik/shared/screens/no_internet_screen.dart';
import 'package:taktik/core/services/revenuecat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env dosyasını yükle (assets klasöründen)
  await dotenv.load(fileName: "assets/.env");

  // AppBootstrapper ile güvenli açılış
  runApp(const ProviderScope(child: AppBootstrapper()));
}

/// Uygulama Başlatıcı (Bekçi)
class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key});

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCriticalServices();
  }

  Future<void> _initializeCriticalServices() async {
    try {
      // 1. Ekran Yönü
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      // 2. Firebase Başlat
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("✅ Firebase Başarıyla Başlatıldı");

      // 3. RevenueCat Başlat
      try {
        await RevenueCatService.init();
        debugPrint("✅ RevenueCat Başarıyla Başlatıldı");
      } catch (e) {
        debugPrint("⚠️ RevenueCat Başlatma Hatası: $e");
        // RevenueCat hatası uygulamayı durdurmasın, sadece loglayalım
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("❌ Kritik Başlatma Hatası: $e");
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hata Ekranı
    if (_errorMessage != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text("Hata:\n$_errorMessage", textAlign: TextAlign.center),
            ),
          ),
        ),
      );
    }

    // Yükleniyor Ekranı
    if (!_isInitialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("Taktik Hazırlanıyor..."),
              ],
            ),
          ),
        ),
      );
    }

    // Asıl Uygulama
    return const BilgeAiApp();
  }
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeNotifierProvider);
    final connectivityAsync = ref.watch(connectivityProvider);

    // Tema mantığı
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

    return connectivityAsync.when(
      data: (isConnected) {
        if (!isConnected) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
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
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (err, stack) => MaterialApp(
        home: Scaffold(body: Center(child: Text("Hata: $err"))),
      ),
    );
  }
}