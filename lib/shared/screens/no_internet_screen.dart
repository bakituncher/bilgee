// lib/shared/screens/no_internet_screen.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
// import 'package:google_fonts/google_fonts.dart'; // <-- KALDIRILDI

class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E27) : Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lottie animasyonu
                SizedBox(
                  width: 280,
                  height: 280,
                  child: Lottie.asset(
                    'assets/lotties/no_internet.json',
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 32),

                // Başlık
                Text(
                  'İnternet Bağlantısı Yok',
                  // GoogleFonts yerine TextStyle
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0A0E27),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Açıklama
                Text(
                  'Taktik uygulamasını kullanabilmek için lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.',
                  // GoogleFonts yerine TextStyle
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    color: isDark
                        ? Colors.white.withOpacity(0.7)
                        : Colors.black.withOpacity(0.6),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 48),

                // Dekoratif element
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        color: isDark
                            ? Colors.white.withOpacity(0.5)
                            : Colors.black.withOpacity(0.4),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Bağlantı bekleniyor...',
                        // GoogleFonts yerine TextStyle
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          color: isDark
                              ? Colors.white.withOpacity(0.5)
                              : Colors.black.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}