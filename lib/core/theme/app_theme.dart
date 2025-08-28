// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // BİLGEAI DEVRİMİ: Renk paleti, bilgeliği, odaklanmayı ve motivasyonu yansıtacak şekilde yeniden tasarlandı.
  // Ana Renkler
  static const Color primaryColor = Color(0xFF0D1B2A);      // Derin Gece Mavisi (Odaklanma)
  static const Color secondaryColor = Color(0xFFFCA311);     // Canlı Turuncu (Eylem ve Motivasyon)
  static const Color accentColor = Color(0xFFE71D36);       // Güçlü Kırmızı (Uyarı ve Hata)
  static const Color successColor = Color(0xFF2EC4B6);      // Canlı Turkuaz (Başarı)

  // Arka Plan ve Yüzey Renkleri
  static const Color scaffoldBackgroundColor = Color(0xFF0D1B2A); // Ana arka plan
  static const Color cardColor = Color(0xFF1B263B);             // Kartların ve yüzeylerin rengi
  static const Color lightSurfaceColor = Color(0xFF415A77);     // Daha açık tonlu yüzeyler (inputlar vb.)

  // Metin Renkleri
  static const Color textColor = Color(0xFFE0E1DD);              // Ana metin rengi
  static const Color secondaryTextColor = Color(0xFFA0AEC0);      // Daha az önemli metinler için gri ton

  // Merkezi Buton Stili
  static final ButtonStyle _buttonStyle = ElevatedButton.styleFrom(
    backgroundColor: secondaryColor,
    foregroundColor: primaryColor,
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

  // BİLGEAI DEVRİMİ: Tek ve güçlü "Modern Bilge" teması.
  static final ThemeData modernTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: secondaryColor, // Ana etkileşim rengi olarak turuncu
      onPrimary: primaryColor,
      secondary: successColor,   // İkincil etkileşim rengi olarak turkuaz
      onSecondary: Colors.white,
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
      iconTheme: IconThemeData(color: secondaryColor),
    ),
    iconTheme: IconThemeData(color: secondaryTextColor),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
    ),
    // *** HATA DÜZELTİLDİ: BottomAppBarTheme -> BottomAppBarThemeData ***
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
}