// lib/core/theme/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themeModeKey = 'app_theme_mode';

// 1. Notifier Tanımı
@Riverpod(keepAlive: true)
class ThemeModeNotifier extends _$ThemeModeNotifier {
  late SharedPreferences _prefs;

  @override
  ThemeMode build() {
    // build metodu senkron olmalı, bu yüzden başlangıç değeri verip asenkron yüklemeyi tetikliyoruz.
    // Gerçek değer yüklendiğinde state güncellenecek ve UI yeniden çizilecek.
    _init();
    return ThemeMode.system; // Varsayılan başlangıç değeri
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final themeModeIndex = _prefs.getInt(_themeModeKey);
    if (themeModeIndex != null) {
      state = ThemeMode.values[themeModeIndex];
    } else {
      state = ThemeMode.system; // Kayıt yoksa sistem temasını kullan
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state != mode) {
      state = mode;
      await _prefs.setInt(_themeModeKey, mode.index);
    }
  }
}
