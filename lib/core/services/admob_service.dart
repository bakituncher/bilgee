// lib/core/services/admob_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;

  /// AdMob'u başlat
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await MobileAds.instance.initialize();

      // --- EKLENECEK KISIM BAŞLANGICI ---
      // Aile politikası için genel yapılandırma.
      // Bu ayar, uygulamanın varsayılan olarak "Genel İzleyici (G)" kitlesine uygun reklamlar almasını garantiye alır.
      // Yetişkin içerikli reklamların yanlışlıkla bile olsa gösterilmesini engeller.
      RequestConfiguration configuration = RequestConfiguration(
        maxAdContentRating: MaxAdContentRating.g, // Sadece G (General) dereceli reklamlar
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes, // COPPA uyumluluğu için
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes, // GDPR uyumluluğu için (Avrupa)
      );

      await MobileAds.instance.updateRequestConfiguration(configuration);
      // --- EKLENECEK KISIM SONU ---

      _initialized = true;

      // İlk interstitial ve rewarded reklamları yükle
      // Not: Başlangıçta kullanıcının yaşını bilmiyorsanız varsayılan olarak isUnder18: true kabul etmek en güvenlisidir.
      _loadInterstitialAd(isUnder18: true);
      _loadRewardedAd(isUnder18: true);

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
          ? dotenv.get('ANDROID_BANNER_TEST_ID', fallback: 'ca-app-pub-3940256099942544/6300978111')
          : dotenv.get('IOS_BANNER_TEST_ID', fallback: 'ca-app-pub-3940256099942544/2934735716');
    }

    // Gerçek Ad Unit IDs - .env dosyasından yüklenir
    return Platform.isAndroid
        ? dotenv.get('ANDROID_BANNER_AD_ID', fallback: 'ca-app-pub-3940256099942544/6300978111')
        : dotenv.get('IOS_BANNER_AD_ID', fallback: 'ca-app-pub-3940256099942544/2934735716');
  }

  /// Interstitial Ad ID'leri
  String get interstitialAdUnitId {
    if (isTestMode) {
      // Test Ad Unit IDs
      return Platform.isAndroid
          ? dotenv.get('ANDROID_INTERSTITIAL_TEST_ID', fallback: 'ca-app-pub-3940256099942544/1033173712')
          : dotenv.get('IOS_INTERSTITIAL_TEST_ID', fallback: 'ca-app-pub-3940256099942544/4411468910');
    }

    // Gerçek Ad Unit IDs - .env dosyasından yüklenir
    return Platform.isAndroid
        ? dotenv.get('ANDROID_INTERSTITIAL_AD_ID', fallback: 'ca-app-pub-3940256099942544/1033173712')
        : dotenv.get('IOS_INTERSTITIAL_AD_ID', fallback: 'ca-app-pub-3940256099942544/4411468910');
  }

  /// Rewarded Ad ID'leri
  String get rewardedAdUnitId {
    if (isTestMode) {
      // Test Ad Unit IDs
      return Platform.isAndroid
          ? dotenv.get('ANDROID_REWARDED_TEST_ID', fallback: 'ca-app-pub-3940256099942544/5224354917')
          : dotenv.get('IOS_REWARDED_TEST_ID', fallback: 'ca-app-pub-3940256099942544/1712485313');
    }

    // Gerçek Ad Unit IDs - .env dosyasından yüklenir
    return Platform.isAndroid
        ? dotenv.get('ANDROID_REWARDED_AD_ID', fallback: 'ca-app-pub-3940256099942544/5224354917')
        : dotenv.get('IOS_REWARDED_AD_ID', fallback: 'ca-app-pub-3940256099942544/1712485313');
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

  /// Rewarded (ödüllü) reklam yükle
  void _loadRewardedAd({bool isUnder18 = false}) {
    if (_isRewardedAdLoading || _rewardedAd != null) return;

    _isRewardedAdLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: createAdRequest(isUnder18: isUnder18),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ Rewarded ad loaded');
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
          // Callback'ler show() metodunda ayarlanacak
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Rewarded ad failed to load: $error');
          _isRewardedAdLoading = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Rewarded reklamı göster ve ödül ver
  /// Returns: Kullanıcı reklamı tamamladıysa true, aksi halde false
  Future<bool> showRewardedAd({bool isUnder18 = false}) async {
    if (!_initialized) {
      debugPrint('⚠️ AdMob not initialized');
      return false;
    }

    if (_rewardedAd == null) {
      debugPrint('⚠️ Rewarded ad not ready, loading...');
      _loadRewardedAd(isUnder18: isUnder18);
      return false;
    }

    bool rewardEarned = false;
    final completer = Completer<bool>();

    // Ad callback'lerini ayarla
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('🎬 Rewarded ad showed');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('✅ Rewarded ad dismissed - Reward earned: $rewardEarned');

        // Cleanup
        ad.dispose();
        _rewardedAd = null;

        // Completer'ı tamamla
        if (!completer.isCompleted) {
          completer.complete(rewardEarned);
        }

        // Yeni reklam yükle (background)
        Future.delayed(const Duration(milliseconds: 500), () {
          _loadRewardedAd(isUnder18: isUnder18);
        });
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ Rewarded ad failed to show: $error');

        // Cleanup
        ad.dispose();
        _rewardedAd = null;

        // Completer'ı tamamla
        if (!completer.isCompleted) {
          completer.complete(false);
        }

        // Yeni reklam yükle (background)
        Future.delayed(const Duration(milliseconds: 500), () {
          _loadRewardedAd(isUnder18: isUnder18);
        });
      },
    );

    // Reklamı göster
    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          debugPrint('🎁 User earned reward: ${reward.amount} ${reward.type}');
          rewardEarned = true;
        },
      );
    } catch (e) {
      debugPrint('❌ Error showing rewarded ad: $e');
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }

    return completer.future;
  }

  /// Rewarded ad hazır mı?
  bool get isRewardedAdReady => _rewardedAd != null;

  /// Rewarded ad yükleniyor mu?
  bool get isRewardedAdLoading => _isRewardedAdLoading;

  /// Rewarded ad'ı önceden yükle
  void preloadRewardedAd({bool isUnder18 = false}) {
    _loadRewardedAd(isUnder18: isUnder18);
  }

  /// Servisi temizle
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}

