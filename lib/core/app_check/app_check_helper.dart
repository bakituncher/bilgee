import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// App Check Token Yöneticisi
///
/// Token süresini proaktif olarak takip eder ve gerektiğinde yeniler.
/// Singleton pattern ile merkezi yönetim sağlar.
class AppCheckManager {
  AppCheckManager._();
  static final AppCheckManager instance = AppCheckManager._();

  /// Token'ın cache'lendiği zaman
  DateTime? _lastTokenFetchTime;

  /// Şu anki token (null olabilir)
  String? _cachedToken;

  /// Token yenileme işlemi devam ediyor mu?
  bool _isRefreshing = false;

  /// Yenileme işlemi için Completer (birden fazla istek aynı anda gelirse bekletir)
  Completer<String?>? _refreshCompleter;

  /// Token listener subscription
  StreamSubscription? _tokenSubscription;

  /// Token geçerlilik süresi (Firebase App Check token'ları genelde 1 saat geçerli)
  /// Güvenli tarafta kalmak için 45 dakikada bir yenileyelim
  static const _tokenValidityDuration = Duration(minutes: 45);

  /// Token yenileme için buffer süresi (süre dolmadan önce yenile)
  static const _refreshBufferDuration = Duration(minutes: 5);

  /// Token listener'ı başlat (main.dart'ta çağrılmalı)
  void startTokenListener() {
    _tokenSubscription?.cancel();
    _tokenSubscription = FirebaseAppCheck.instance.onTokenChange.listen(
      (token) {
        if (token != null && token.isNotEmpty) {
          _cachedToken = token;
          _lastTokenFetchTime = DateTime.now();
          if (kDebugMode) {
            debugPrint('[AppCheck] 🔄 Token otomatik yenilendi (listener)');
          }
        }
      },
      onError: (e) {
        if (kDebugMode) {
          debugPrint('[AppCheck] Token listener hatası: $e');
        }
      },
    );
    if (kDebugMode) {
      debugPrint('[AppCheck] Token listener başlatıldı');
    }
  }

  /// Token listener'ı durdur
  void stopTokenListener() {
    _tokenSubscription?.cancel();
    _tokenSubscription = null;
  }

  /// Token'ın süresi dolmuş mu veya dolmak üzere mi kontrol et
  bool get _isTokenExpiredOrExpiring {
    if (_lastTokenFetchTime == null || _cachedToken == null) {
      return true; // Token hiç alınmamış
    }

    final elapsed = DateTime.now().difference(_lastTokenFetchTime!);
    final expiryThreshold = _tokenValidityDuration - _refreshBufferDuration;

    return elapsed >= expiryThreshold;
  }

  /// Token'ın kesin olarak süresi dolmuş mu?
  bool get _isTokenDefinitelyExpired {
    if (_lastTokenFetchTime == null || _cachedToken == null) {
      return true;
    }

    final elapsed = DateTime.now().difference(_lastTokenFetchTime!);
    return elapsed >= _tokenValidityDuration;
  }

  /// Geçerli bir App Check token'ı al
  ///
  /// - Eğer cache'de geçerli token varsa onu döndürür
  /// - Süresi dolmuşsa veya dolmak üzereyse yeni token alır
  /// - Birden fazla istek aynı anda gelirse tek bir yenileme işlemi yapar
  Future<String?> getValidToken({bool forceRefresh = false}) async {
    // Force refresh veya token expired/expiring ise yenile
    if (!forceRefresh && !_isTokenExpiredOrExpiring && _cachedToken != null) {
      return _cachedToken;
    }

    // Eğer zaten bir yenileme işlemi devam ediyorsa onu bekle
    if (_isRefreshing && _refreshCompleter != null) {
      if (kDebugMode) {
        debugPrint('[AppCheck] Başka bir yenileme işlemi bekleniyor...');
      }
      return _refreshCompleter!.future;
    }

    // Yeni yenileme işlemi başlat
    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();

    try {
      if (kDebugMode) {
        debugPrint('[AppCheck] Token ${forceRefresh ? "zorla" : "proaktif"} yenileniyor...');
      }

      // forceRefresh: true -> Sunucudan yeni token al
      // forceRefresh: false -> Cache varsa kullan (ama bizim _isTokenExpiredOrExpiring true döndüğü için buraya geldik)
      final token = await FirebaseAppCheck.instance
          .getToken(forceRefresh || _isTokenDefinitelyExpired)
          .timeout(const Duration(seconds: 10));

      if (token != null && token.isNotEmpty) {
        _cachedToken = token;
        _lastTokenFetchTime = DateTime.now();

        if (kDebugMode) {
          debugPrint('[AppCheck] ✅ Token başarıyla alındı');
        }

        _refreshCompleter?.complete(token);
        return token;
      }

      _refreshCompleter?.complete(null);
      return null;

    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppCheck] ❌ Token alınamadı: $e');
      }

      // "Too many attempts" hatası
      if (e.toString().toLowerCase().contains('too many attempts')) {
        if (kDebugMode) {
          debugPrint('[AppCheck] Rate limit - mevcut token kullanılacak');
        }
        _refreshCompleter?.complete(_cachedToken);
        return _cachedToken;
      }

      _refreshCompleter?.complete(null);
      return null;

    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  /// Token'ı zorla yenile (hata recovery için)
  Future<String?> forceRefreshToken() async {
    // Önce kısa bir bekleme (sunucunun hazır olması için)
    await Future.delayed(const Duration(milliseconds: 300));
    return getValidToken(forceRefresh: true);
  }

  /// Cache'i temizle (logout vb. için)
  void clearCache() {
    _cachedToken = null;
    _lastTokenFetchTime = null;
    if (kDebugMode) {
      debugPrint('[AppCheck] Cache temizlendi');
    }
  }
}

/// Eski API uyumluluğu için wrapper fonksiyon
/// Tüm mevcut `ensureAppCheckTokenReady()` çağrıları bu fonksiyonu kullanmaya devam edebilir
Future<void> ensureAppCheckTokenReady({int maxAttempts = 3}) async {
  await AppCheckManager.instance.getValidToken();
}

/// Firebase Functions çağrısını App Check token yönetimiyle saran yardımcı
///
/// Bu fonksiyon:
/// 1. Çağrı öncesi geçerli token olduğundan emin olur
/// 2. Token expired hatası alırsa otomatik olarak token yenileyip tekrar dener
/// 3. Merkezi hata yönetimi sağlar
///
/// Kullanım:
/// ```dart
/// final result = await callWithAppCheck(
///   functions.httpsCallable('myFunction'),
///   {'param': 'value'},
/// );
/// ```
Future<HttpsCallableResult<T>> callWithAppCheck<T>(
  HttpsCallable callable,
  [dynamic data, int retryCount = 0]
) async {
  const maxRetries = 2;

  try {
    // 1. Çağrı öncesi token'ın geçerli olduğundan emin ol
    await AppCheckManager.instance.getValidToken();

    // 2. Fonksiyonu çağır
    return await callable.call<T>(data);

  } on FirebaseFunctionsException catch (e) {
    // 3. App Check token hatası kontrolü
    final isAppCheckError = e.code == 'unauthenticated' ||
        e.code == 'permission-denied' ||
        (e.message?.toLowerCase().contains('app check') ?? false) ||
        ((e.message?.toLowerCase().contains('token') ?? false) &&
         (e.message?.toLowerCase().contains('expired') ?? false));

    if (isAppCheckError && retryCount < maxRetries) {
      if (kDebugMode) {
        debugPrint('[AppCheck] Functions hatası: ${e.code} - Token yenileniyor (deneme ${retryCount + 1})');
      }

      // Token'ı zorla yenile
      await AppCheckManager.instance.forceRefreshToken();

      // Token'ın sunucuya yayılması için kısa bekleme
      await Future.delayed(Duration(milliseconds: 300 * (retryCount + 1)));

      // Tekrar dene
      return callWithAppCheck<T>(callable, data, retryCount + 1);
    }

    // Retry sonrası hala hata varsa veya farklı bir hata ise fırlat
    rethrow;
  }
}

/// Firebase Functions çağrısını saran ve sonucu Map olarak döndüren yardımcı
///
/// Dönüş tipi belirsiz olduğunda kullanışlıdır.
Future<Map<String, dynamic>?> callWithAppCheckMap(
  HttpsCallable callable,
  [dynamic data]
) async {
  final result = await callWithAppCheck<dynamic>(callable, data);
  if (result.data is Map) {
    return Map<String, dynamic>.from(result.data as Map);
  }
  return null;
}
