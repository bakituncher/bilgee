// lib/data/providers/activity_tracker_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taktik/data/providers/shared_prefs_provider.dart';

/// Kullanıcının deneme ve ders neti ekleme sayısını takip eder
class ActivityTracker {
  final SharedPreferences _prefs;

  ActivityTracker(this._prefs);

  static const String _lessonNetCountKey = 'activity_lesson_net_count';
  static const String _offerShowTimesKey = 'offer_show_times';
  static const int _maxShowsPerHour = 10;

  int getLessonNetCount() => _prefs.getInt(_lessonNetCountKey) ?? 0;

  List<int> _getOfferShowTimes() {
    final times = _prefs.getStringList(_offerShowTimesKey) ?? [];
    return times.map((e) => int.parse(e)).toList();
  }

  Future<void> incrementLessonNetCount() async {
    final current = getLessonNetCount();
    await _prefs.setInt(_lessonNetCountKey, current + 1);
  }

  Future<void> resetLessonNetCount() async {
    await _prefs.setInt(_lessonNetCountKey, 0);
  }

  Future<void> markToolOfferShown() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final times = _getOfferShowTimes();
    times.add(now);

    // Sadece son gösterimleri sakla
    final recentTimes = times.where((t) =>
      DateTime.now().millisecondsSinceEpoch - t < 3600000 // Son 1 saat
    ).toList();

    await _prefs.setStringList(_offerShowTimesKey, recentTimes.map((e) => e.toString()).toList());
  }

  /// Tool Offer gösterilmeli mi kontrol eder
  /// Her 1 deneme VEYA her 2 ders neti için gösterilir
  /// 1 saat içinde maksimum 5 kez gösterilir
  bool shouldShowToolOfferForTest() {
    return _canShowOffer();
  }

  bool shouldShowToolOfferForLessonNet() {
    final lessonNetCount = getLessonNetCount();
    // Her 2 ders neti güncellemesinde göster
    if (lessonNetCount >= 2 && lessonNetCount % 2 == 0) {
      return _canShowOffer();
    }
    return false;
  }

  bool _canShowOffer() {
    final times = _getOfferShowTimes();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Son 1 saat içindeki gösterimleri say
    final recentShows = times.where((t) => now - t < 3600000).length;

    // 1 saat içinde 5 kezden fazla gösterilmemeli
    return recentShows < _maxShowsPerHour;
  }
}

final activityTrackerProvider = Provider<ActivityTracker>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).requireValue;
  return ActivityTracker(prefs);
});

