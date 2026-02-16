// lib/features/premium/screens/premium_welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/providers/firestore_providers.dart';

/// Premium kullanıcılar için özel tasarlanmış, görsel ağırlıklı karşılama ekranı.
/// "Industry-Standard" kalitesinde, sadelik ve marka vurgusu ön planda.
class PremiumWelcomeScreen extends ConsumerStatefulWidget {
  const PremiumWelcomeScreen({super.key});

  @override
  ConsumerState<PremiumWelcomeScreen> createState() => _PremiumWelcomeScreenState();
}

class _PremiumWelcomeScreenState extends ConsumerState<PremiumWelcomeScreen> {
  // Premium Brand Colors
  final Color _primaryGold = const Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    // Tam ekran sinematik deneyim
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    // Çıkışta normal moda dön
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _handleContinue() {
    HapticFeedback.lightImpact();
    context.go('/ai-hub', extra: {'startPremiumTour': true});
  }



  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).valueOrNull;
    final firstName = user?.firstName ?? 'Şampiyon';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. KATMAN: Arka Plan Görseli (elele.png)
          Image.asset(
            'assets/images/elele.webp',
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
            alignment: Alignment.center,
          ).animate().fadeIn(duration: 800.ms),

          // 2. KATMAN: Sinematik Gradient Overlay
          // Metinlerin okunabilirliği için daha dramatik bir geçiş
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.2), // Hafif karartma
                  Colors.black.withValues(alpha: 0.7), // Metin arkası
                  Colors.black.withValues(alpha: 0.95), // Alt kısım tam siyah
                ],
                stops: const [0.0, 0.3, 0.6, 1.0],
              ),
            ),
          ),

          // 3. KATMAN: İçerik
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst Kısım: Premium Rozeti
                  Align(
                    alignment: Alignment.topRight,
                    child: _buildPremiumBadge(),
                  ).animate().slideY(begin: -0.5, end: 0, duration: 600.ms).fadeIn(),

                  const Spacer(), // İçeriği aşağı itiyoruz

                  // Başlık
                  Text(
                    'Aramıza Hoş Geldin,\n$firstName!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: -1.0,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          offset: Offset(0, 4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1, end: 0),

                  const SizedBox(height: 20),

                  // Fayda Odaklı İkna Edici Metin
                  Text(
                    "Kazanmaya hoş geldin! Bugün attığın bu adımla kontrol artık sende. Haftalık Plan seni hedeflerine kilitlerken, Soru Çözücü ile takıldığın her an yanıtlar cebinde. İster yolda ister teneffüste ol; Etüt Odası ve Zihin Haritası ile en zor konuları bile keyifle halledeceksin. Taktik Tavşan stratejini belirledi bile, şimdi başlama zamanı!",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      letterSpacing: -0.2,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 600.ms),

                  const SizedBox(height: 48),

                  // CTA Butonu
                  _buildCTAButton(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _primaryGold.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryGold.withValues(alpha: 0.15),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars_rounded, color: _primaryGold, size: 20),
          const SizedBox(width: 8),
          Text(
            'PRO ÜYE',
            style: TextStyle(
              color: _primaryGold,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTAButton() {
    return Container(
      width: double.infinity,
      height: 60, // Biraz daha büyük ve iddialı buton
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryGold,
            const Color(0xFFFFA000), // Amber
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primaryGold.withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleContinue,
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.white.withValues(alpha: 0.2),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Yolculuğa Başla',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: 10),
                Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 26),
              ],
            ),
          ),
        ),
      ),
    )
    .animate(onPlay: (controller) => controller.repeat(reverse: true))
    .shimmer(
      delay: 1500.ms,
      duration: 2.seconds,
      color: Colors.white.withValues(alpha: 0.5),
    ) // Dikkat çekici parıltı
    .animate()
    .fadeIn(delay: 500.ms)
    .scale(begin: const Offset(0.95, 0.95));
  }
}

