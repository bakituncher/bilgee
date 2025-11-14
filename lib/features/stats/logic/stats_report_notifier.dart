// lib/features/stats/logic/stats_report_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taktik/data/providers/shared_prefs_provider.dart';

const _statsLastViewedKey = 'stats_last_viewed_timestamp';
const _statsReportCooldown = Duration(hours: 2);

final statsReportNotifierProvider =
    StateNotifierProvider<StatsReportNotifier, DateTime?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).value;
  return StatsReportNotifier(prefs);
});

class StatsReportNotifier extends StateNotifier<DateTime?> {
  final SharedPreferences? _prefs;

  StatsReportNotifier(this._prefs) : super(null) {
    _loadLastViewedTimestamp();
  }

  void _loadLastViewedTimestamp() {
    final timestamp = _prefs?.getInt(_statsLastViewedKey);
    if (timestamp != null) {
      state = DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
  }

  bool shouldReportView() {
    if (state == null) return true;
    return DateTime.now().difference(state!) > _statsReportCooldown;
  }

  Future<void> reportViewed() async {
    final now = DateTime.now();
    await _prefs?.setInt(_statsLastViewedKey, now.millisecondsSinceEpoch);
    state = now;
  }
}
