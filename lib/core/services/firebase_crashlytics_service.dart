// lib/core/services/firebase_crashlytics_service.dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Crashlytics servisi
/// AD_ID izni olmadan çalışacak şekilde yapılandırılmıştır
class FirebaseCrashlyticsService {
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Hata kaydı
  static Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool fatal = false,
  }) async {
    try {
      await _crashlytics.recordError(
        exception,
        stack,
        reason: reason,
        information: information,
        fatal: fatal,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Crashlytics] Error recording: $e');
      }
    }
  }

  /// Flutter hata kaydı
  static Future<void> recordFlutterError(FlutterErrorDetails details) async {
    try {
      await _crashlytics.recordFlutterFatalError(details);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Crashlytics] Flutter error recording: $e');
      }
    }
  }

  /// Log mesajı ekle
  static Future<void> log(String message) async {
    try {
      await _crashlytics.log(message);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Crashlytics] Log error: $e');
      }
    }
  }

  /// Kullanıcı ID'si ayarla
  static Future<void> setUserId(String userId) async {
    try {
      await _crashlytics.setUserIdentifier(userId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Crashlytics] User ID error: $e');
      }
    }
  }

  /// Özel anahtar ayarla
  static Future<void> setCustomKey(String key, Object value) async {
    try {
      await _crashlytics.setCustomKey(key, value);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Crashlytics] Custom key error: $e');
      }
    }
  }

  /// Birden fazla özel anahtar ayarla
  static Future<void> setCustomKeys(Map<String, Object> keys) async {
    try {
      for (final entry in keys.entries) {
        await _crashlytics.setCustomKey(entry.key, entry.value);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Crashlytics] Custom keys error: $e');
      }
    }
  }

  /// Test crash (sadece test amaçlı)
  static void testCrash() {
    if (kDebugMode) {
      debugPrint('[Crashlytics] Test crash - Bu sadece debug modda çalışır');
      return;
    }
    _crashlytics.crash();
  }

  /// Crashlytics'i etkinleştir/devre dışı bırak
  static Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    try {
      await _crashlytics.setCrashlyticsCollectionEnabled(enabled);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Crashlytics] Collection enable error: $e');
      }
    }
  }

  /// İşlenmemiş hataları kontrol et
  static Future<bool> checkForUnsentReports() async {
    try {
      return await _crashlytics.checkForUnsentReports();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Crashlytics] Check unsent reports error: $e');
      }
      return false;
    }
  }

  /// Gönderilmemiş raporları sil
  static Future<void> deleteUnsentReports() async {
    try {
      await _crashlytics.deleteUnsentReports();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Crashlytics] Delete unsent reports error: $e');
      }
    }
  }

  /// Gönderilmemiş raporları gönder
  static Future<void> sendUnsentReports() async {
    try {
      await _crashlytics.sendUnsentReports();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Crashlytics] Send unsent reports error: $e');
      }
    }
  }
}

