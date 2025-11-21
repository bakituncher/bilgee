// lib/core/services/admob_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// AdMob reklam servisi
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
      _initialized = true;
      _loadInterstitialAd();
      _loadRewardedAd();
      debugPrint('✅ AdMob initialized');
    } catch (e) {
      debugPrint('❌ AdMob initialization failed: $e');
    }
  }

  /// Test modunda mı?
  bool get isTestMode => kDebugMode;

  /// Banner Ad ID
  String get bannerAdUnitId {
    if (isTestMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';
    }
    return Platform.isAndroid
        ? dotenv.get('ANDROID_BANNER_AD_ID', fallback: 'ca-app-pub-3940256099942544/6300978111')
        : dotenv.get('IOS_BANNER_AD_ID', fallback: 'ca-app-pub-3940256099942544/2934735716');
  }

  /// Interstitial Ad ID
  String get interstitialAdUnitId {
    if (isTestMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712'
          : 'ca-app-pub-3940256099942544/4411468910';
    }
    return Platform.isAndroid
        ? dotenv.get('ANDROID_INTERSTITIAL_AD_ID', fallback: 'ca-app-pub-3940256099942544/1033173712')
        : dotenv.get('IOS_INTERSTITIAL_AD_ID', fallback: 'ca-app-pub-3940256099942544/4411468910');
  }

  /// Rewarded Ad ID
  String get rewardedAdUnitId {
    if (isTestMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-3940256099942544/1712485313';
    }
    return Platform.isAndroid
        ? dotenv.get('ANDROID_REWARDED_AD_ID', fallback: 'ca-app-pub-3940256099942544/5224354917')
        : dotenv.get('IOS_REWARDED_AD_ID', fallback: 'ca-app-pub-3940256099942544/1712485313');
  }

  /// Banner reklam oluştur
  BannerAd createBannerAd({
    required Function(Ad) onAdLoaded,
    required Function(Ad, LoadAdError) onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
      ),
    );
  }

  /// Interstitial reklam yükle
  void _loadInterstitialAd() {
    if (_isInterstitialAdLoading || _interstitialAd != null) return;

    _isInterstitialAdLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdLoading = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Interstitial reklamı göster
  Future<void> showInterstitialAd({bool isPremium = false}) async {
    if (!_initialized || isPremium) return;

    if (_interstitialAd != null) {
      await _interstitialAd!.show();
    } else {
      _loadInterstitialAd();
    }
  }

  /// Rewarded reklam yükle
  void _loadRewardedAd() {
    if (_isRewardedAdLoading || _rewardedAd != null) return;

    _isRewardedAdLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isRewardedAdLoading = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Rewarded reklamı göster
  Future<bool> showRewardedAd() async {
    if (!_initialized || _rewardedAd == null) {
      _loadRewardedAd();
      return false;
    }

    bool rewardEarned = false;
    final completer = Completer<bool>();

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        if (!completer.isCompleted) completer.complete(rewardEarned);
        Future.delayed(const Duration(milliseconds: 500), _loadRewardedAd);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        if (!completer.isCompleted) completer.complete(false);
        Future.delayed(const Duration(milliseconds: 500), _loadRewardedAd);
      },
    );

    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) => rewardEarned = true,
      );
    } catch (e) {
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future;
  }

  /// Rewarded ad hazır mı?
  bool get isRewardedAdReady => _rewardedAd != null;

  /// Rewarded ad yükleniyor mu?
  bool get isRewardedAdLoading => _isRewardedAdLoading;

  /// Rewarded ad'ı önceden yükle
  void preloadRewardedAd() => _loadRewardedAd();

  /// Servisi temizle
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}

