// lib/core/services/admob_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob reklam servisi
/// - Yaşa göre kişiselleştirilmiş/kişiselleştirilmemiş reklamlar
/// - Banner ve Interstitial reklam desteği
class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  bool _initialized = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoading = false;

  /// AdMob'u başlat
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await MobileAds.instance.initialize();
      _initialized = true;

      // İlk interstitial reklamı yükle
      _loadInterstitialAd();

      debugPrint('✅ AdMob initialized successfully');
    } catch (e) {
      debugPrint('❌ AdMob initialization failed: $e');
    }
  }

  /// Test modunda mı?
  bool get isTestMode => kDebugMode;

  /// Banner Ad ID'leri
  String get bannerAdUnitId {
    if (isTestMode) {
      // Test Ad Unit IDs
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111' // Android test banner
          : 'ca-app-pub-3940256099942544/2934735716'; // iOS test banner
    }

    // Gerçek Ad Unit IDs - Bunları AdMob konsolundan almalısın
    return Platform.isAndroid
        ? 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY' // Android banner - DEĞİŞTİRİLMELİ
        : 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY'; // iOS banner - DEĞİŞTİRİLMELİ
  }

  /// Interstitial Ad ID'leri
  String get interstitialAdUnitId {
    if (isTestMode) {
      // Test Ad Unit IDs
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712' // Android test interstitial
          : 'ca-app-pub-3940256099942544/4411468910'; // iOS test interstitial
    }

    // Gerçek Ad Unit IDs - Bunları AdMob konsolundan almalısın
    return Platform.isAndroid
        ? 'ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ' // Android interstitial - DEĞİŞTİRİLMELİ
        : 'ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ'; // iOS interstitial - DEĞİŞTİRİLMELİ
  }

  /// Yaşa göre reklam isteği oluştur
  /// - 18 yaş altı: Kişiselleştirilmemiş reklamlar (COPPA uyumlu)
  /// - 18 yaş ve üstü: Kişiselleştirilmiş reklamlar
  AdRequest createAdRequest({required bool isUnder18}) {
    if (isUnder18) {
      // 18 yaş altı için kişiselleştirilmemiş reklamlar
      return const AdRequest(
        keywords: ['education', 'study', 'learning', 'student'],
        nonPersonalizedAds: true, // Kişiselleştirilmemiş reklamlar
      );
    } else {
      // 18 yaş ve üstü için normal reklamlar
      return const AdRequest(
        keywords: ['education', 'study', 'learning', 'student', 'exam'],
      );
    }
  }

  /// Banner reklam yükle
  BannerAd createBannerAd({required bool isUnder18, required Function(Ad) onAdLoaded, required Function(Ad, LoadAdError) onAdFailedToLoad}) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: createAdRequest(isUnder18: isUnder18),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
        onAdOpened: (ad) => debugPrint('Banner ad opened'),
        onAdClosed: (ad) => debugPrint('Banner ad closed'),
      ),
    );
  }

  /// Interstitial reklam yükle
  void _loadInterstitialAd({bool isUnder18 = false}) {
    if (_isInterstitialAdLoading || _interstitialAd != null) return;

    _isInterstitialAdLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: createAdRequest(isUnder18: isUnder18),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ Interstitial ad loaded');
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;

          // Ad event callbacks
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              debugPrint('Interstitial ad showed');
            },
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('Interstitial ad dismissed');
              ad.dispose();
              _interstitialAd = null;
              // Yeni reklam yükle
              _loadInterstitialAd(isUnder18: isUnder18);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('❌ Interstitial ad failed to show: $error');
              ad.dispose();
              _interstitialAd = null;
              // Yeni reklam yükle
              _loadInterstitialAd(isUnder18: isUnder18);
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Interstitial ad failed to load: $error');
          _isInterstitialAdLoading = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Interstitial reklamı göster
  /// [isPremium] true ise reklam gösterilmez
  Future<void> showInterstitialAd({bool isUnder18 = false, bool isPremium = false}) async {
    if (!_initialized) {
      debugPrint('⚠️ AdMob not initialized');
      return;
    }

    // Premium kullanıcılara reklam gösterme
    if (isPremium) {
      debugPrint('ℹ️ Skipping ad for premium user');
      return;
    }

    if (_interstitialAd != null) {
      await _interstitialAd!.show();
    } else {
      debugPrint('⚠️ Interstitial ad not ready, loading...');
      _loadInterstitialAd(isUnder18: isUnder18);
    }
  }

  /// Servisi temizle
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}

