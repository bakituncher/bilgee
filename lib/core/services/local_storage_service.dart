// lib/core/services/local_storage_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider to access the service
final localStorageProvider = Provider<LocalStorageService>((ref) {
  // This will be overridden in main.dart after SharedPreferences is initialized
  throw UnimplementedError();
});

class LocalStorageService {
  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  static const String _testCounterKey = 'test_counter';
  static const String _courseNetCounterKey = 'course_net_counter';
  static const String _lastPremiumShowDateKey = 'last_premium_show_date';

  // --- Test Counter ---
  Future<int> getTestCounter() async {
    return _prefs.getInt(_testCounterKey) ?? 0;
  }

  Future<void> incrementTestCounter() async {
    int currentCount = await getTestCounter();
    await _prefs.setInt(_testCounterKey, currentCount + 1);
  }

  Future<void> resetTestCounter() async {
    await _prefs.setInt(_testCounterKey, 0);
  }

  // --- Course Net Counter ---
  Future<int> getCourseNetCounter() async {
    return _prefs.getInt(_courseNetCounterKey) ?? 0;
  }

  Future<void> incrementCourseNetCounter() async {
    int currentCount = await getCourseNetCounter();
    await _prefs.setInt(_courseNetCounterKey, currentCount + 1);
  }

  Future<void> resetCourseNetCounter() async {
    await _prefs.setInt(_courseNetCounterKey, 0);
  }
}
