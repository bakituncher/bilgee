// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- BRAND COLORS (Consistent across themes) ---
  static const Color primaryBrandColor = Color(0xFF0F172A);   // Deep Slate Blue (Used as bg in dark)
  static const Color secondaryBrandColor = Color(0xFF22D3EE); // Vivid Cyan (Action/Highlight)
  static const Color accentBrandColor = Color(0xFFE71D36);    // Red (Error/Alert)
  static const Color successBrandColor = Color(0xFF34D399);   // Emerald (Success)
  static const Color goldBrandColor = Color(0xFFFFB020);      // Gold (Premium/Awards)

  // --- DARK THEME COLOR CONSTANTS ---
  static const Color _darkScaffoldBackgroundColor = Color(0xFF0F172A); // slate-900
  static const Color _darkCardColor = Color(0xFF1E293B);               // slate-800
  static const Color _darkLightSurfaceColor = Color(0xFF334155);       // slate-700
  static const Color _darkTextColor = Color(0xFFE2E8F0);               // slate-200
  static const Color _darkSecondaryTextColor = Color(0xFF94A3B8);      // slate-400

  // --- LIGHT THEME COLOR CONSTANTS ---
  static const Color _lightScaffoldBackgroundColor = Color(0xFFF1F5F9); // slate-100
  static const Color _lightCardColor = Color(0xFFFFFFFF);               // white
  static const Color _lightLightSurfaceColor = Color(0xFFE2E8F0);       // slate-200
  static const Color _lightTextColor = Color(0xFF0F172A);               // slate-900
  static const Color _lightSecondaryTextColor = Color(0xFF64748B);      // slate-500

  // --- System UI Overlays ---
  static const SystemUiOverlayStyle darkSystemUiOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light, // For dark backgrounds
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  );

  static const SystemUiOverlayStyle lightSystemUiOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // For light backgrounds
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  );


  // ==================== DARK THEME DEFINITION ====================
  static final ThemeData darkTheme = _buildTheme(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _darkScaffoldBackgroundColor,
    cardColor: _darkCardColor,
    lightSurfaceColor: _darkLightSurfaceColor,
    textColor: _darkTextColor,
    secondaryTextColor: _darkSecondaryTextColor,
  );

  // ==================== LIGHT THEME DEFINITION ====================
  static final ThemeData lightTheme = _buildTheme(
    brightness: Brightness.light,
    scaffoldBackgroundColor: _lightScaffoldBackgroundColor,
    cardColor: _lightCardColor,
    lightSurfaceColor: _lightLightSurfaceColor,
    textColor: _lightTextColor,
    secondaryTextColor: _lightSecondaryTextColor,
  );

  // ============ CENTRAL THEME BUILDER (DRY Principle) ============
  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color scaffoldBackgroundColor,
    required Color cardColor,
    required Color lightSurfaceColor,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    final isDark = brightness == Brightness.dark;

    final baseTextTheme = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final textTheme = GoogleFonts.montserratTextTheme(baseTextTheme).apply(
      bodyColor: textColor,
      displayColor: textColor,
    );

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: secondaryBrandColor,
      foregroundColor: Colors.black, // Cyan on black is good for contrast
      minimumSize: const Size(double.infinity, 52.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 4.0,
      textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 16),
      shadowColor: secondaryBrandColor.withOpacity(0.4),
    );

    final inputDecorationTheme = InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: isDark ? lightSurfaceColor.withOpacity(0.5) : lightSurfaceColor,
      labelStyle: TextStyle(color: secondaryTextColor),
      hintStyle: TextStyle(color: secondaryTextColor.withOpacity(0.7)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );

    return ThemeData(
      brightness: brightness,
      primaryColor: primaryBrandColor,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: secondaryBrandColor, // Main action color: cyan
        onPrimary: Colors.black,     // Text on cyan: black for contrast
        secondary: successBrandColor,
        onSecondary: Colors.black,
        error: accentBrandColor,
        onError: Colors.white,
        surface: cardColor,
        onSurface: textColor,
        surfaceContainerHighest: lightSurfaceColor, // For slightly different surfaces
        onSurfaceVariant: secondaryTextColor, // For secondary text on surfaces
      ),
      textTheme: textTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
      inputDecorationTheme: inputDecorationTheme,
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 2,
        color: cardColor,
        shadowColor: isDark ? Colors.transparent : Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
            side: BorderSide(color: isDark ? lightSurfaceColor.withOpacity(0.5) : lightSurfaceColor, width: 1),
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
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      iconTheme: IconThemeData(color: secondaryTextColor),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: secondaryBrandColor,
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
        backgroundColor: cardColor.withOpacity(0.95),
        contentTextStyle: GoogleFonts.montserrat(color: textColor, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: lightSurfaceColor.withOpacity(isDark ? 0.4 : 0.8))
        ),
        elevation: 6,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actionTextColor: secondaryBrandColor,
      ),
    );
  }

  // Refactored method to apply the correct overlay based on brightness
  static void configureSystemUI(Brightness brightness) {
    final style = brightness == Brightness.dark ? darkSystemUiOverlay : lightSystemUiOverlay;
    SystemChrome.setSystemUIOverlayStyle(style);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      top: mediaQuery.padding.top,
      bottom: mediaQuery.padding.bottom,
    );
  }
}
