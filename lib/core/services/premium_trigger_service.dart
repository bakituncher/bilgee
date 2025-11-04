// lib/core/services/premium_trigger_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage when to show the premium screen based on user actions
/// Shows premium screen on:
/// - Every app launch
/// - Every 2nd test addition (2nd, 4th, 6th, etc.)
/// - Every 2nd subject score update (2nd, 4th, 6th, etc.)
class PremiumTriggerService {
  static const String _keyAppLaunches = 'premium_trigger_app_launches';
  static const String _keyTestAdditions = 'premium_trigger_test_additions';
  static const String _keySubjectUpdates = 'premium_trigger_subject_updates';

  final SharedPreferences _prefs;

  PremiumTriggerService(this._prefs);

  /// Initialize the service with SharedPreferences instance
  static Future<PremiumTriggerService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return PremiumTriggerService(prefs);
  }

  // --- App Launch Tracking ---

  /// Increment app launch counter
  /// Returns true if premium screen should be shown (always on launch)
  Future<bool> trackAppLaunch() async {
    final count = (_prefs.getInt(_keyAppLaunches) ?? 0) + 1;
    await _prefs.setInt(_keyAppLaunches, count);
    
    if (kDebugMode) {
      debugPrint('[PremiumTrigger] App launch #$count');
    }
    
    // Show premium screen on every app launch
    return true;
  }

  // --- Test Addition Tracking ---

  /// Increment test addition counter
  /// Returns true if premium screen should be shown (every 2nd addition)
  Future<bool> trackTestAddition() async {
    final count = (_prefs.getInt(_keyTestAdditions) ?? 0) + 1;
    await _prefs.setInt(_keyTestAdditions, count);
    
    final shouldShow = count % 2 == 0;
    
    if (kDebugMode) {
      debugPrint('[PremiumTrigger] Test addition #$count, shouldShow: $shouldShow');
    }
    
    return shouldShow;
  }

  // --- Subject Score Update Tracking ---

  /// Increment subject score update counter
  /// Returns true if premium screen should be shown (every 2nd update)
  Future<bool> trackSubjectScoreUpdate() async {
    final count = (_prefs.getInt(_keySubjectUpdates) ?? 0) + 1;
    await _prefs.setInt(_keySubjectUpdates, count);
    
    final shouldShow = count % 2 == 0;
    
    if (kDebugMode) {
      debugPrint('[PremiumTrigger] Subject score update #$count, shouldShow: $shouldShow');
    }
    
    return shouldShow;
  }

  // --- Counter Management ---

  /// Get current counters (for debugging/testing)
  Map<String, int> getCounters() {
    return {
      'appLaunches': _prefs.getInt(_keyAppLaunches) ?? 0,
      'testAdditions': _prefs.getInt(_keyTestAdditions) ?? 0,
      'subjectUpdates': _prefs.getInt(_keySubjectUpdates) ?? 0,
    };
  }

  /// Reset all counters (for testing purposes)
  Future<void> resetCounters() async {
    await _prefs.remove(_keyAppLaunches);
    await _prefs.remove(_keyTestAdditions);
    await _prefs.remove(_keySubjectUpdates);
    
    if (kDebugMode) {
      debugPrint('[PremiumTrigger] All counters reset');
    }
  }
}
