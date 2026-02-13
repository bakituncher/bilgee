// lib/core/services/monetization_manager.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Akıllı monetizasyon yöneticisi
/// Reklam ve paywall gösterimini optimize eder
class MonetizationManager {
  final SharedPreferences _prefs;
  final bool _disableCooldownForTesting;

  MonetizationManager(
    this._prefs, {
    bool disableCooldownForTesting = false,
  }) : _disableCooldownForTesting = disableCooldownForTesting;

  // Keys
  static const String _testSubmissionCountKey = 'monetization_test_count';
  static const String _lessonNetSubmissionCountKey = 'monetization_lesson_net_count';
  static const String _lastPaywallShowTimeKey = 'monetization_last_paywall_time';
  static const String _paywallShowCountKey = 'monetization_paywall_count';

  // --- STRATEJİ: HER 3 İŞLEMDE 1 PAYWALL ---
  // 1. işlem: skip
  // 2. işlem: skip
  // 3. işlem: paywall
  static const int _cycleLength = 3;

  // Minimum bekleme süresi (spam önleme)
  static const Duration _minPaywallInterval =
      kDebugMode ? Duration(seconds: 5) : Duration(minutes: 5);

  /// Test eklendikten sonra ne gösterileceğine karar verir
  MonetizationAction getActionAfterTestSubmission() {
    final count = _getTestSubmissionCount();
    final newCount = count + 1;

    // Sayacı güncelle
    _setTestSubmissionCount(newCount);

    debugPrint('💰 Monetization: Test Submission #$newCount');

    // Her 3 işlemde bir paywall göster
    if (newCount % _cycleLength == 0) {
      if (_canShowPaywall()) {
        _recordPaywallShow();
        debugPrint('💰 Monetization: Showing PAYWALL (test #$newCount)');
        return MonetizationAction.showPaywall;
      }

      debugPrint('⏰ Monetization: Paywall cooldown active, skipping');
      return MonetizationAction.showNothing;
    }

    // Diğer işlemlerde hiçbir şey gösterme
    debugPrint('✓ Monetization: Skipping (test #$newCount)');
    return MonetizationAction.showNothing;
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

    debugPrint('💰 Monetization: Lesson Net Submission #$newCount');

    // Her 3 işlemde bir paywall göster
    if (newCount % _cycleLength == 0) {
      if (_canShowPaywall()) {
        _recordPaywallShow();
        debugPrint('💰 Monetization: Showing PAYWALL (lesson net #$newCount)');
        return MonetizationAction.showPaywall;
      }

      debugPrint('⏰ Monetization: Paywall cooldown active, skipping');
      return MonetizationAction.showNothing;
    }

    // Diğer işlemlerde hiçbir şey gösterme
    debugPrint('✓ Monetization: Skipping (lesson net #$newCount)');
    return MonetizationAction.showNothing;
  }

  /// Ders neti ekleme sayacını al
  int _getLessonNetSubmissionCount() {
    return _prefs.getInt(_lessonNetSubmissionCountKey) ?? 0;
  }

  /// Ders neti ekleme sayacını güncelle
  void _setLessonNetSubmissionCount(int count) {
    _prefs.setInt(_lessonNetSubmissionCountKey, count);
  }

  /// Paywall gösterilebilir mi kontrol et
  bool _canShowPaywall() {
    if (_disableCooldownForTesting) return true;

    final lastShowTime = _prefs.getInt(_lastPaywallShowTimeKey);
    if (lastShowTime == null) return true;

    final lastShow = DateTime.fromMillisecondsSinceEpoch(lastShowTime);
    final now = DateTime.now();
    final diff = now.difference(lastShow);

    return diff >= _minPaywallInterval;
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
      paywallsShown: _prefs.getInt(_paywallShowCountKey) ?? 0,
      lastPaywallTime: _prefs.getInt(_lastPaywallShowTimeKey) != null
          ? DateTime.fromMillisecondsSinceEpoch(_prefs.getInt(_lastPaywallShowTimeKey)!)
          : null,
    );
  }

  /// Sayaçları sıfırla (test için)
  Future<void> reset() async {
    await _prefs.remove(_testSubmissionCountKey);
    await _prefs.remove(_lessonNetSubmissionCountKey);
    await _prefs.remove(_lastPaywallShowTimeKey);
    await _prefs.remove(_paywallShowCountKey);
    debugPrint('🔄 Monetization: Stats reset');
  }
}

/// Monetizasyon aksiyonu
enum MonetizationAction {
  showPaywall,
  showNothing,
}

/// Monetizasyon istatistikleri
class MonetizationStats {
  final int totalTests;
  final int totalLessonNets;
  final int paywallsShown;
  final DateTime? lastPaywallTime;

  MonetizationStats({
    required this.totalTests,
    required this.totalLessonNets,
    required this.paywallsShown,
    this.lastPaywallTime,
  });

  @override
  String toString() {
    return 'MonetizationStats(tests: $totalTests, lessonNets: $totalLessonNets, paywalls: $paywallsShown)';
  }
}
