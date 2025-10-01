// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Ana Renkler (Cevher Atölyesi paleti)
  static const Color primaryColor = Color(0xFF0F172A);      // Derin gece mavisi (arka plan temeli)
  static const Color secondaryColor = Color(0xFF22D3EE);    // Canlı Camgöbeği (vurgular/aksiyonlar)
  static const Color accentColor = Color(0xFFE71D36);       // Uyarı/Kırmızı (hata)
  static const Color successColor = Color(0xFF34D399);      // Zümrüt (başarı)
  static const Color goldColor = Color(0xFFFFB020);         // Altın sarısı (ödüller/premium)

  // Arka Plan ve Yüzey Renkleri
  static const Color scaffoldBackgroundColor = Color(0xFF0F172A); // Ana arka plan (slate-900)
  static const Color cardColor = Color(0xFF1E293B);               // Kart yüzeyi (slate-800)
  static const Color lightSurfaceColor = Color(0xFF334155);       // Açık yüzeyler/çerçeve (slate-700)

  // Metin Renkleri
  static const Color textColor = Color(0xFFE2E8F0);               // Açık metin (slate-200)
  static const Color secondaryTextColor = Color(0xFF94A3B8);      // İkincil metin (slate-400)

  // Merkezi Buton Stili
  static final ButtonStyle _buttonStyle = ElevatedButton.styleFrom(
    backgroundColor: secondaryColor,
    foregroundColor: Colors.black, // camgöbeği üstünde koyu yazı okunaklı
    minimumSize: const Size(double.infinity, 52.0),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16.0),
    ),
    elevation: 4.0,
    textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 16),
    shadowColor: secondaryColor.withValues(alpha: 0.4),
  );

  // Merkezi TextField Stili
  static final InputDecorationTheme _inputDecorationTheme = InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.0),
      borderSide: BorderSide.none,
    ),
    filled: true,
    fillColor: lightSurfaceColor.withValues(alpha: 0.5),
    labelStyle: TextStyle(color: secondaryTextColor),
    hintStyle: TextStyle(color: secondaryTextColor.withValues(alpha: 0.7)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  );

  // Android 15+ SDK 35 uyumlu System UI Overlay ayarları
  static const SystemUiOverlayStyle systemUiOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
    // Android 15+ için zorunlu edge-to-edge ayarları
    systemNavigationBarContrastEnforced: false,
  );

  // Tek ve güçlü "Modern Bilge" teması.
  static final ThemeData modernTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: secondaryColor,        // Ana etkileşim rengi: camgöbeği
      onPrimary: Colors.black,         // Kontrast için koyu
      secondary: successColor,         // İkincil: başarı/zümrüt
      onSecondary: Colors.black,
      error: accentColor,
      onError: Colors.white,
      surface: cardColor,
      onSurface: textColor,
    ),
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: textColor,
      displayColor: textColor,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _buttonStyle),
    inputDecorationTheme: _inputDecorationTheme,
    cardTheme: CardThemeData(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
          side: BorderSide(color: lightSurfaceColor.withValues(alpha: 0.5), width: 1),
          borderRadius: BorderRadius.circular(16)
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.montserrat(
        fontWeight: FontWeight.bold,
        fontSize: 20,
        color: textColor,
      ),
      iconTheme: const IconThemeData(color: secondaryColor),
    ),
    iconTheme: const IconThemeData(color: secondaryTextColor),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
    ),
    bottomAppBarTheme: BottomAppBarThemeData(
      color: cardColor,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: cardColor.withValues(alpha: 0.95),
      contentTextStyle: GoogleFonts.montserrat(color: textColor, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: lightSurfaceColor.withValues(alpha: 0.4))),
      elevation: 6,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      actionTextColor: secondaryColor,
    ),
  );

  // System UI'yi ayarlamak için güncellenmiş metod
  static void configureSystemUI() {
    // System UI overlay style ayarla
    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);

    // Android 15+ SDK 35 için zorunlu edge-to-edge modu
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    // Preferred orientations ayarla (opsiyonel)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Edge-to-edge layout için SafeArea padding hesaplama yardımcısı
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      top: mediaQuery.padding.top,
      bottom: mediaQuery.padding.bottom,
    );
  }
}