// lib/core/services/monetization_manager.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Akıllı monetizasyon yöneticisi
/// Reklam ve paywall gösterimini optimize eder
class MonetizationManager {
  final SharedPreferences _prefs;

  MonetizationManager(this._prefs);

  // Keys
  static const String _testSubmissionCountKey = 'monetization_test_count';
  static const String _lessonNetSubmissionCountKey = 'monetization_lesson_net_count';
  static const String _lastAdShowTimeKey = 'monetization_last_ad_time';
  static const String _lastPaywallShowTimeKey = 'monetization_last_paywall_time';
  static const String _paywallShowCountKey = 'monetization_paywall_count';
  static const String _adShowCountKey = 'monetization_ad_count';

  // Strateji: Her 5 test eklemenin 4'ü reklam, 1'i paywall
  // Örnek: Test 1-4: Reklam, Test 5: Paywall, Test 6-9: Reklam, Test 10: Paywall
  static const int _cycleLength = 5;
  static const int _paywallPosition = 5; // Her 5. testte paywall

  // Minimum bekleme süreleri (spam önleme)
  static const Duration _minAdInterval = Duration(seconds: 30);
  static const Duration _minPaywallInterval = Duration(minutes: 5);

  /// Test eklendikten sonra ne gösterileceğine karar verir
  MonetizationAction getActionAfterTestSubmission() {
    final count = _getTestSubmissionCount();
    final newCount = count + 1;

    // Sayacı güncelle
    _setTestSubmissionCount(newCount);

    // Her 5. test paywall göster
    if (newCount % _cycleLength == 0) {
      // Paywall için minimum süre kontrolü
      if (_canShowPaywall()) {
        _recordPaywallShow();
        debugPrint('💰 Monetization: Showing PAYWALL (test #$newCount)');
        return MonetizationAction.showPaywall;
      } else {
        // Paywall çok yakın zamanda gösterildi, reklam göster
        debugPrint('⏰ Monetization: Paywall cooldown active, showing AD instead');
        _recordAdShow();
        return MonetizationAction.showAd;
      }
    } else {
      // Diğer testlerde reklam göster
      if (_canShowAd()) {
        _recordAdShow();
        debugPrint('📺 Monetization: Showing AD (test #$newCount)');
        return MonetizationAction.showAd;
      } else {
        // Reklam çok yakın zamanda gösterildi, hiçbir şey gösterme
        debugPrint('⏰ Monetization: Ad cooldown active, skipping');
        return MonetizationAction.showNothing;
      }
    }
  }

  /// Test ekleme sayacını al
  int _getTestSubmissionCount() {
    return _prefs.getInt(_testSubmissionCountKey) ?? 0;
  }

  /// Test ekleme sayacını güncelle
  void _setTestSubmissionCount(int count) {
    _prefs.setInt(_testSubmissionCountKey, count);
  }

  /// Ders neti eklendikten sonra ne gösterileceğine karar verir
  MonetizationAction getActionAfterLessonNetSubmission() {
    final count = _getLessonNetSubmissionCount();
    final newCount = count + 1;

    // Sayacı güncelle
    _setLessonNetSubmissionCount(newCount);

    // Her 5. ders neti paywall göster
    if (newCount % _cycleLength == 0) {
      // Paywall için minimum süre kontrolü
      if (_canShowPaywall()) {
        _recordPaywallShow();
        debugPrint('💰 Monetization: Showing PAYWALL (lesson net #$newCount)');
        return MonetizationAction.showPaywall;
      } else {
        // Paywall çok yakın zamanda gösterildi, reklam göster
        debugPrint('⏰ Monetization: Paywall cooldown active, showing AD instead');
        _recordAdShow();
        return MonetizationAction.showAd;
      }
    } else {
      // Diğer ders netlerinde reklam göster
      if (_canShowAd()) {
        _recordAdShow();
        debugPrint('📺 Monetization: Showing AD (lesson net #$newCount)');
        return MonetizationAction.showAd;
      } else {
        // Reklam çok yakın zamanda gösterildi, hiçbir şey gösterme
        debugPrint('⏰ Monetization: Ad cooldown active, skipping');
        return MonetizationAction.showNothing;
      }
    }
  }

  /// Ders neti ekleme sayacını al
  int _getLessonNetSubmissionCount() {
    return _prefs.getInt(_lessonNetSubmissionCountKey) ?? 0;
  }

  /// Ders neti ekleme sayacını güncelle
  void _setLessonNetSubmissionCount(int count) {
    _prefs.setInt(_lessonNetSubmissionCountKey, count);
  }

  /// Reklam gösterilebilir mi kontrol et
  bool _canShowAd() {
    final lastShowTime = _prefs.getInt(_lastAdShowTimeKey);
    if (lastShowTime == null) return true;

    final lastShow = DateTime.fromMillisecondsSinceEpoch(lastShowTime);
    final now = DateTime.now();
    final diff = now.difference(lastShow);

    return diff >= _minAdInterval;
  }

  /// Paywall gösterilebilir mi kontrol et
  bool _canShowPaywall() {
    final lastShowTime = _prefs.getInt(_lastPaywallShowTimeKey);
    if (lastShowTime == null) return true;

    final lastShow = DateTime.fromMillisecondsSinceEpoch(lastShowTime);
    final now = DateTime.now();
    final diff = now.difference(lastShow);

    return diff >= _minPaywallInterval;
  }

  /// Reklam gösterimini kaydet
  void _recordAdShow() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _prefs.setInt(_lastAdShowTimeKey, now);

    final count = _prefs.getInt(_adShowCountKey) ?? 0;
    _prefs.setInt(_adShowCountKey, count + 1);
  }

  /// Paywall gösterimini kaydet
  void _recordPaywallShow() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _prefs.setInt(_lastPaywallShowTimeKey, now);

    final count = _prefs.getInt(_paywallShowCountKey) ?? 0;
    _prefs.setInt(_paywallShowCountKey, count + 1);
  }

  /// İstatistikleri al (debug için)
  MonetizationStats getStats() {
    return MonetizationStats(
      totalTests: _getTestSubmissionCount(),
      totalLessonNets: _getLessonNetSubmissionCount(),
      adsShown: _prefs.getInt(_adShowCountKey) ?? 0,
      paywallsShown: _prefs.getInt(_paywallShowCountKey) ?? 0,
      lastAdTime: _prefs.getInt(_lastAdShowTimeKey) != null
          ? DateTime.fromMillisecondsSinceEpoch(_prefs.getInt(_lastAdShowTimeKey)!)
          : null,
      lastPaywallTime: _prefs.getInt(_lastPaywallShowTimeKey) != null
          ? DateTime.fromMillisecondsSinceEpoch(_prefs.getInt(_lastPaywallShowTimeKey)!)
          : null,
    );
  }

  /// Sayaçları sıfırla (test için)
  Future<void> reset() async {
    await _prefs.remove(_testSubmissionCountKey);
    await _prefs.remove(_lessonNetSubmissionCountKey);
    await _prefs.remove(_lastAdShowTimeKey);
    await _prefs.remove(_lastPaywallShowTimeKey);
    await _prefs.remove(_paywallShowCountKey);
    await _prefs.remove(_adShowCountKey);
    debugPrint('🔄 Monetization: Stats reset');
  }
}

/// Monetizasyon aksiyonu
enum MonetizationAction {
  showAd,
  showPaywall,
  showNothing,
}

/// Monetizasyon istatistikleri
class MonetizationStats {
  final int totalTests;
  final int totalLessonNets;
  final int adsShown;
  final int paywallsShown;
  final DateTime? lastAdTime;
  final DateTime? lastPaywallTime;

  MonetizationStats({
    required this.totalTests,
    required this.totalLessonNets,
    required this.adsShown,
    required this.paywallsShown,
    this.lastAdTime,
    this.lastPaywallTime,
  });

  @override
  String toString() {
    return 'MonetizationStats(tests: $totalTests, lessonNets: $totalLessonNets, ads: $adsShown, paywalls: $paywallsShown)';
  }
}

