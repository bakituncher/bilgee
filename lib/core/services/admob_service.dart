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
      // RequestConfiguration ayarları
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          maxAdContentRating: MaxAdContentRating.g, // Genel izleyici için
          tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
          tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
        ),
      );

      await MobileAds.instance.initialize();
      _initialized = true;
      // İlk yüklemede yaş bilgisi olmadığı için güvenli modda başlatıyoruz
      _loadInterstitialAd();
      _loadRewardedAd();
      debugPrint('✅ AdMob initialized with COPPA compliance');
    } catch (e) {
      debugPrint('❌ AdMob initialization failed: $e');
    }
  }

  /// Kullanıcı yaşına göre AdMob konfigürasyonunu güncelle
  Future<void> updateUserAgeConfiguration({DateTime? dateOfBirth}) async {
    if (!_initialized) return;

    final isUnder18 = _isUserUnder18(dateOfBirth);

    try {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          maxAdContentRating: isUnder18 ? MaxAdContentRating.g : MaxAdContentRating.t,
          tagForChildDirectedTreatment: isUnder18
              ? TagForChildDirectedTreatment.yes
              : TagForChildDirectedTreatment.no,
          tagForUnderAgeOfConsent: isUnder18
              ? TagForUnderAgeOfConsent.yes
              : TagForUnderAgeOfConsent.no,
        ),
      );
      debugPrint('✅ AdMob configuration updated for ${isUnder18 ? "child" : "adult"} user');
    } catch (e) {
      debugPrint('❌ Failed to update AdMob configuration: $e');
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

  /// Kullanıcının yaşına göre AdRequest oluştur
  /// 18 yaşından küçükler için COPPA uyumlu reklam
  AdRequest _buildAdRequest({DateTime? dateOfBirth}) {
    final isUnder18 = _isUserUnder18(dateOfBirth);

    if (isUnder18) {
      // 18 yaşından küçükler için COPPA uyumlu ayarlar
      return const AdRequest(
        extras: {
          'npa': '1', // Non-Personalized Ads
          'tag_for_child_directed_treatment': '1', // COPPA - Child Directed
          'max_ad_content_rating': 'G', // Genel izleyici (Everyone)
        },
      );
    }

    // 18 yaş ve üzeri için normal reklam
    return const AdRequest(
      extras: {
        'tag_for_child_directed_treatment': '0', // Yetişkin içerik
      },
    );
  }

  /// Kullanıcı 18 yaşından küçük mü kontrol et
  bool _isUserUnder18(DateTime? dateOfBirth) {
    if (dateOfBirth == null) {
      // Yaş bilgisi yoksa güvenli tarafta olalım
      return true;
    }

    final today = DateTime.now();
    var age = today.year - dateOfBirth.year;

    // Doğum günü bu yıl henüz gelmemişse yaşı bir azalt
    if (today.month < dateOfBirth.month ||
        (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) {
      age--;
    }

    return age < 18;
  }

  /// Banner reklam oluştur
  BannerAd createBannerAd({
    required Function(Ad) onAdLoaded,
    required Function(Ad, LoadAdError) onAdFailedToLoad,
    DateTime? dateOfBirth,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: _buildAdRequest(dateOfBirth: dateOfBirth),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
      ),
    );
  }

  /// Interstitial reklam yükle
  void _loadInterstitialAd({DateTime? dateOfBirth}) {
    if (_isInterstitialAdLoading || _interstitialAd != null) return;

    _isInterstitialAdLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: _buildAdRequest(dateOfBirth: dateOfBirth),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd(dateOfBirth: dateOfBirth);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd(dateOfBirth: dateOfBirth);
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
  Future<void> showInterstitialAd({
    bool isPremium = false,
    DateTime? dateOfBirth,
  }) async {
    if (!_initialized || isPremium) return;

    if (_interstitialAd != null) {
      await _interstitialAd!.show();
    } else {
      _loadInterstitialAd(dateOfBirth: dateOfBirth);
    }
  }

  /// Rewarded reklam yükle
  void _loadRewardedAd({DateTime? dateOfBirth}) {
    if (_isRewardedAdLoading || _rewardedAd != null) return;

    _isRewardedAdLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: _buildAdRequest(dateOfBirth: dateOfBirth),
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
  Future<bool> showRewardedAd({DateTime? dateOfBirth}) async {
    if (!_initialized || _rewardedAd == null) {
      _loadRewardedAd(dateOfBirth: dateOfBirth);
      return false;
    }

    bool rewardEarned = false;
    final completer = Completer<bool>();

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        if (!completer.isCompleted) completer.complete(rewardEarned);
        Future.delayed(const Duration(milliseconds: 500), () => _loadRewardedAd(dateOfBirth: dateOfBirth));
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        if (!completer.isCompleted) completer.complete(false);
        Future.delayed(const Duration(milliseconds: 500), () => _loadRewardedAd(dateOfBirth: dateOfBirth));
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
  void preloadRewardedAd({DateTime? dateOfBirth}) => _loadRewardedAd(dateOfBirth: dateOfBirth);

  /// Servisi temizle
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}

