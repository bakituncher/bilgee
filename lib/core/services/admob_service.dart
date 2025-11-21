// lib/core/services/admob_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// AdMob reklam servisi - COPPA ve GDPR uyumlu
/// - Doğum tarihine göre otomatik yaş kontrolü
/// - 18 yaş altı: Çocuk odaklı reklamlar (COPPA uyumlu)
/// - 18 yaş üstü: Normal reklamlar
/// - Google Aile Politikası uyumlu
class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  bool _initialized = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoading = false;
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;

  /// AdMob'u başlat - Varsayılan olarak güvenli mod (çocuk modu)
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Varsayılan konfigürasyon: Güvenli mod (çocuk odaklı)
      // Kullanıcının yaşı belirlendikten sonra updateConfigurationByAge() ile güncellenecek
      await _applyConfiguration(isUnder18: true);

      // AdMob SDK'yı başlat
      await MobileAds.instance.initialize();

      _initialized = true;

      // İlk reklamları yükle (güvenli mod)
      _loadInterstitialAd(isUnder18: true);
      _loadRewardedAd(isUnder18: true);

      debugPrint('✅ AdMob initialized successfully (Safe Mode - Child-Directed Content)');
    } catch (e) {
      debugPrint('❌ AdMob initialization failed: $e');
    }
  }

  /// Doğum tarihine göre AdMob konfigürasyonunu güncelle
  /// Bu metod kullanıcının yaşı belirlendiğinde çağrılmalıdır
  ///
  /// [dateOfBirth] Kullanıcının doğum tarihi
  ///
  /// Google Aile Politikası Uyumluluğu:
  /// - 18 yaş altı: tagForChildDirectedTreatment = YES (COPPA uyumlu)
  /// - 18 yaş üstü: tagForChildDirectedTreatment = NO (Normal reklamlar)
  Future<void> updateConfigurationByAge(DateTime? dateOfBirth) async {
    if (!_initialized) {
      debugPrint('⚠️ AdMob not initialized yet');
      return;
    }

    final isUnder18 = _calculateIsUnder18(dateOfBirth);
    await _applyConfiguration(isUnder18: isUnder18);

    debugPrint('✅ AdMob configuration updated - Age restricted: $isUnder18');
  }

  /// Yaş hesaplama (null-safe)
  bool _calculateIsUnder18(DateTime? dateOfBirth) {
    if (dateOfBirth == null) {
      // Yaş bilgisi yoksa güvenli tarafta kal (çocuk modu)
      return true;
    }

    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;

    // Doğum günü henüz gelmemişse bir yaş düşür
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }

    return age < 18;
  }

  /// Yaşa göre AdMob konfigürasyonunu uygula
  Future<void> _applyConfiguration({required bool isUnder18}) async {
    final RequestConfiguration configuration;

    if (isUnder18) {
      // 18 yaş altı: COPPA uyumlu konfigürasyon
      configuration = RequestConfiguration(
        maxAdContentRating: MaxAdContentRating.g, // Genel izleyici (en güvenli)
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes, // Çocuk odaklı içerik
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes, // GDPR yaş onayı altında
        testDeviceIds: kDebugMode ? [
          'F9742A37C96523F237FE85385A67842F',
          'BD3C30521D0B02B7473439F1BD0D2868',
        ] : [],
      );
      debugPrint('🛡️ AdMob: Child-Directed Treatment ENABLED (COPPA Compliant)');
    } else {
      // 18 yaş üstü: Normal konfigürasyon
      configuration = RequestConfiguration(
        maxAdContentRating: MaxAdContentRating.pg, // Genel izleyici + (biraz daha geniş)
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.no, // Yetişkin içerik izni
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.no, // GDPR yaş onayı üstünde
        testDeviceIds: kDebugMode ? [
          'F9742A37C96523F237FE85385A67842F',
          'BD3C30521D0B02B7473439F1BD0D2868',
        ] : [],
      );
      debugPrint('✅ AdMob: Standard Treatment (18+ years old)');
    }

    await MobileAds.instance.updateRequestConfiguration(configuration);
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

  /// Yaşa göre reklam isteği oluştur (COPPA ve Google Aile Politikası uyumlu)
  ///
  /// [isUnder18] Kullanıcı 18 yaşından küçük mü?
  ///
  /// GÜVENLİK: 18 yaş altı için ÇİFTE KORUMA
  /// 1. RequestConfiguration: tagForChildDirectedTreatment = YES
  /// 2. AdRequest: nonPersonalizedAds = true
  ///
  /// Bu iki katman birlikte, 18 yaş altı kullanıcılara KESİNLİKLE
  /// kişiselleştirilmiş reklam gösterilmemesini garanti eder.
  AdRequest createAdRequest({required bool isUnder18}) {
    if (isUnder18) {
      // 18 yaş altı: ÇİFTE GÜVENLİK
      // - RequestConfiguration'da tagForChildDirectedTreatment: YES (zaten ayarlanmış)
      // - AdRequest'te nonPersonalizedAds: true (ekstra koruma)
      return const AdRequest(
        nonPersonalizedAds: true, // KESİNLİKLE kişiselleştirilmemiş reklamlar
      );
    } else {
      // 18 yaş üstü: Serbest
      // AdMob kendi algoritmalarını kullanır
      // Kullanıcı tercihine göre kişiselleştirme yapılabilir
      return const AdRequest(
        // nonPersonalizedAds belirtilmez - kullanıcı tercihine göre
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

