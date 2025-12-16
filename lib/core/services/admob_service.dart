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
  bool _isPremium = false;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoading = false;
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;

  // Kullanıcının doğum tarihi (yaş konfigürasyonu için saklanır)
  DateTime? _userDateOfBirth;
  // Son yüklenen reklamların çocuk (under 18) modunda olup olmadığı
  bool? _lastIsUnder18;

  /// Servisi tamamen sıfırla (Logout durumunda kullanılır)
  /// Tüm state'i temizler ve reklamları yok eder.
  void reset() {
    debugPrint('🔄 AdMobService is being reset (Logout/Cleanup)');
    dispose();
    _initialized = false;
    _isPremium = false;
    _userDateOfBirth = null;
    _lastIsUnder18 = null;
  }

  /// AdMob'u başlat
  /// [isPremium] true ise AdMob SDK başlatılmaz, kaynak tüketilmez.
  Future<void> initialize({bool isPremium = false}) async {
    // Eğer daha önce initialize edilmişse ve premium durumu değişmediyse çık
    // Ancak reset sonrası _initialized false olacağı için tekrar çalışır.
    if (_initialized && _isPremium == isPremium) return;

    _isPremium = isPremium;

    // Eğer premium ise ve daha önce init edilmişse, kaynakları temizle
    // ve init edilmiş gibi işaretle
    if (_isPremium) {
      dispose();
      debugPrint('✅ AdMob skipped initialization for Premium user');
      _initialized = true; // İşaretliyoruz ki tekrar tekrar denemesin
      return;
    }

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
      // İlk yüklemede yaş bilgisi olmadığı için güvenli (çocuk) modda başlatıyoruz;
      // fakat yaş bilgisi sonradan gelince updateUserAgeConfiguration bu reklamları yeniden yükleyecek.
      _loadInterstitialAd();
      _loadRewardedAd();
      debugPrint('✅ AdMob initialized with COPPA compliance');
    } catch (e) {
      debugPrint('❌ AdMob initialization failed: $e');
    }
  }

  /// Premium durumunu günceller.
  /// Kullanıcı premium satın alırsa veya aboneliği biterse çağrılır.
  Future<void> updatePremiumStatus(bool isPremium) async {
    if (_isPremium == isPremium) return;

    _isPremium = isPremium;
    debugPrint('ℹ️ AdMob premium status updated: $_isPremium');

    if (_isPremium) {
      // Premium olduysa tüm reklamları temizle ve belleği boşalt
      dispose();
    } else {
      // Premium bittiyse:
      // Eğer daha önce "skipped init" yapıldıysa (_initialized=true ama SDK çalışmadı),
      // şimdi gerçekten init etmeliyiz.
      // Veya hiç init edilmediyse init etmeliyiz.

      // _initialized=true olması, MobileAds.initialize çağrıldığı anlamına gelmez (premium skip durumu).
      // Bu yüzden sadece _initialized kontrolü yetersiz olabilir, ama initialize() metodunu
      // isPremium=false ile çağırmak güvenlidir.
      await initialize(isPremium: false);

      // initialize() içinde zaten yükleme çağrılıyor ama asenkron olduğu için
      // garanti olsun diye yüklemeyi tetikle.
      if (_interstitialAd == null) _loadInterstitialAd(dateOfBirth: _userDateOfBirth);
      if (_rewardedAd == null) _loadRewardedAd(dateOfBirth: _userDateOfBirth);
    }
  }

  /// Kullanıcı yaşına göre AdMob konfigürasyonunu güncelle
  /// Bu metot aynı zamanda yaş durumundaki değişiklik sonrası (özellikle çocuk -> yetişkin)
  /// interstitial ve rewarded reklamları yeniden yükler ki test cihazı kimliği alınabilsin.
  /// Doğum tarihi olmayan kullanıcılar için de çocuk olarak işlem yapılır (COPPA uyumlu)
  Future<void> updateUserAgeConfiguration({DateTime? dateOfBirth}) async {
    if (!_initialized || _isPremium) return;

    _userDateOfBirth = dateOfBirth; // Yaş bilgisini sakla
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
      debugPrint('✅ AdMob configuration updated for ${isUnder18 || dateOfBirth == null ? "child/no-age" : "adult"} user');

      // Yaş durumunda değişiklik varsa veya artık yetişkin moduna geçildiyse reklamları yeniden yükle
      // Böylece çocuk modunda ilk alınan reklamlar yetişkin modunda ad id toplayıp test reklamı gösterebilir.
      final shouldReload = _lastIsUnder18 == null || _lastIsUnder18 != isUnder18 || (!isUnder18 && _lastIsUnder18 == true);
      if (shouldReload) {
        _reloadAgeSensitiveAds(dateOfBirth: _userDateOfBirth);
      }
      _lastIsUnder18 = isUnder18;
    } catch (e) {
      debugPrint('❌ Failed to update AdMob configuration: $e');
    }
  }

  /// Yaşa bağlı reklamları yeniden yükler (interstitial & rewarded)
  void _reloadAgeSensitiveAds({DateTime? dateOfBirth}) {
    if (_isPremium) return;

    // Mevcut reklamları dispose edip null'lıyoruz ki yeni konfig ile yeniden yüklensinler
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdLoading = false;

    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isRewardedAdLoading = false;

    // Yeni yaş bilgisine göre tekrar yükle
    _loadInterstitialAd(dateOfBirth: dateOfBirth);
    _loadRewardedAd(dateOfBirth: dateOfBirth);
    debugPrint('🔄 Age change detected. Interstitial & Rewarded ads reloaded.');
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
  /// Doğum tarihi olmayan kullanıcılar için de COPPA uyumlu reklam (reklam kimliği toplanmaz)
  AdRequest _buildAdRequest({DateTime? dateOfBirth}) {
    // Parametre verilmezse saklanan kullanıcı doğum tarihini kullan
    dateOfBirth ??= _userDateOfBirth;
    final isUnder18 = _isUserUnder18(dateOfBirth);

    if (isUnder18 || dateOfBirth == null) {
      // 18 yaşından küçükler veya doğum tarihi olmayan kullanıcılar için COPPA uyumlu ayarlar
      // Bu ayarlar reklam kimliği (AD ID) toplanmasını engeller
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
  /// Doğum tarihi yoksa güvenli tarafta olup çocuk muamelesi yap
  bool _isUserUnder18(DateTime? dateOfBirth) {
    if (dateOfBirth == null) {
      // Yaş bilgisi yoksa güvenli tarafta olalım (COPPA uyumlu)
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
  BannerAd? createBannerAd({
    required Function(Ad) onAdLoaded,
    required Function(Ad, LoadAdError) onAdFailedToLoad,
    DateTime? dateOfBirth,
  }) {
    if (_isPremium) {
      debugPrint('🚫 Banner ad creation blocked for Premium user');
      return null;
    }

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
    if (_isPremium) return;
    if (_isInterstitialAdLoading || _interstitialAd != null) return;

    _isInterstitialAdLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: _buildAdRequest(dateOfBirth: dateOfBirth ?? _userDateOfBirth),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd(dateOfBirth: _userDateOfBirth);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd(dateOfBirth: _userDateOfBirth);
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
  Future<void> showInterstitialAd({DateTime? dateOfBirth}) async {
    if (_isPremium) {
      debugPrint('🚫 Interstitial ad skipped for Premium user');
      return;
    }

    if (!_initialized) {
      // Henüz initialize olmadıysa (belki gecikmeli init), başlatmayı dene
      // ama bu noktada kullanıcı premium değilse init çalışmalıydı.
      debugPrint('⚠️ AdMob not initialized, skipping interstitial show');
      return;
    }

    // Gösterimden önce varsa kullanıcı yaşını güncellemek için parametreyi saklanan değere aktaralım
    if (dateOfBirth != null && dateOfBirth != _userDateOfBirth) {
      // Bu sadece gösterim öncesi gelirse konfigürasyon güncellemesini tetikleyebilir
      await updateUserAgeConfiguration(dateOfBirth: dateOfBirth);
    }

    if (_interstitialAd != null) {
      await _interstitialAd!.show();
    } else {
      _loadInterstitialAd(dateOfBirth: _userDateOfBirth);
    }
  }

  /// Rewarded reklam yükle
  void _loadRewardedAd({DateTime? dateOfBirth}) {
    if (_isPremium) return;
    if (_isRewardedAdLoading || _rewardedAd != null) return;

    _isRewardedAdLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: _buildAdRequest(dateOfBirth: dateOfBirth ?? _userDateOfBirth),
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
  /// Premium kullanıcılar için otomatik olarak true döner.
  Future<bool> showRewardedAd({DateTime? dateOfBirth}) async {
    if (_isPremium) {
      debugPrint('🎁 Premium user auto-rewarded without ad');
      return true;
    }

    if (dateOfBirth != null && dateOfBirth != _userDateOfBirth) {
      await updateUserAgeConfiguration(dateOfBirth: dateOfBirth);
    }

    if (!_initialized || _rewardedAd == null) {
      _loadRewardedAd(dateOfBirth: _userDateOfBirth);
      return false;
    }

    bool rewardEarned = false;
    final completer = Completer<bool>();

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        if (!completer.isCompleted) completer.complete(rewardEarned);
        Future.delayed(const Duration(milliseconds: 500), () => _loadRewardedAd(dateOfBirth: _userDateOfBirth));
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        if (!completer.isCompleted) completer.complete(false);
        Future.delayed(const Duration(milliseconds: 500), () => _loadRewardedAd(dateOfBirth: _userDateOfBirth));
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
  void preloadRewardedAd({DateTime? dateOfBirth}) {
    if (!_isPremium) {
      _loadRewardedAd(dateOfBirth: dateOfBirth ?? _userDateOfBirth);
    }
  }

  /// Servisi temizle
  /// Premium olduğunda tüm reklamları bellekten siler.
  void dispose() {
    debugPrint('🗑️ Disposing all ads (Premium or cleanup)');
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdLoading = false;

    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isRewardedAdLoading = false;
  }
}
