// lib/core/theme/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themeModeKey = 'app_theme_mode';

final themeModeNotifierProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  late SharedPreferences _prefs;

  ThemeModeNotifier() : super(ThemeMode.system) {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final themeModeIndex = _prefs.getInt(_themeModeKey);
    if (themeModeIndex != null) {
      state = ThemeMode.values[themeModeIndex];
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state != mode) {
      state = mode;
      await _prefs.setInt(_themeModeKey, mode.index);
    }
  }
}
