// lib/features/premium/screens/premium_welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'dart:math' as math;

/// Premium kullanıcılar için hoş geldiniz/teşekkür ekranı
/// Kullanıcı premium aldığında gösterilir
class PremiumWelcomeScreen extends ConsumerStatefulWidget {
  const PremiumWelcomeScreen({super.key});

  @override
  ConsumerState<PremiumWelcomeScreen> createState() => _PremiumWelcomeScreenState();
}

class _PremiumWelcomeScreenState extends ConsumerState<PremiumWelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _particleController;
  late final AnimationController _glowController;

  // Premium Brand Colors - Industry Standard Palette
  final Color _primaryGold = const Color(0xFFFDB022);
  final Color _secondaryGold = const Color(0xFFFFC043);
  final Color _accentPurple = const Color(0xFF7C3AED);
  final Color _accentBlue = const Color(0xFF4F46E5);
  final Color _deepPurple = const Color(0xFF5B21B6);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _mainController.forward();

    // Haptic feedback
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _mainController.dispose();
    _particleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    HapticFeedback.lightImpact();
    // Premium Tur'u başlatmak için AI Hub'a özel parametre ile gidiyoruz
    context.go('/ai-hub', extra: {'startPremiumTour': true});
  }

  String _getSupportMessage(String? exam) {
    switch (exam?.toUpperCase()) {
      case 'YKS':
        return 'Taktik, üniversite hayalini gerçekleştirene kadar her adımda yanında';
      case 'LGS':
        return 'Taktik, hayalindeki liseye girene kadar her adımda yanında';
      case 'KPSS':
        return 'Taktik, devlet kapısından girene kadar her adımda yanında';
      case 'AGS':
        return 'Taktik, öğretmenlik hayalini gerçekleştirene kadar her adımda yanında';
      default:
        return 'Taktik, başarı yolculuğunda her adımda yanında';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final user = ref.watch(userProfileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E27) : Colors.white,
      body: Stack(
        children: [
          // Animated Gradient Background
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF0A0E27),
                            Color.lerp(const Color(0xFF1A1F3A), _deepPurple.withValues(alpha: 0.2),
                                _glowController.value * 0.3)!,
                            Color.lerp(const Color(0xFF0A0E27), _accentPurple.withValues(alpha: 0.15),
                                _glowController.value * 0.2)!,
                          ]
                        : [
                            Colors.white,
                            Color.lerp(Colors.white, _secondaryGold.withValues(alpha: 0.08),
                                _glowController.value * 0.5)!,
                            Colors.white,
                          ],
                  ),
                ),
              );
            },
          ),

          // Floating Particles - Enhanced
          ...List.generate(20, (index) {
            return AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                final progress = (_particleController.value + (index * 0.05)) % 1.0;
                final x = size.width * (0.05 + (index % 5) * 0.2);
                final y = size.height * progress;
                final opacity = (1 - progress) * 0.6;
                final sineWave = math.sin(progress * math.pi * 6) * 40;

                return Positioned(
                  left: x + sineWave,
                  top: y,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 3 + (index % 4) * 1.5,
                      height: 3 + (index % 4) * 1.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index % 3 == 0
                          ? _primaryGold
                          : index % 3 == 1
                            ? _accentPurple
                            : _accentBlue,
                        boxShadow: [
                          BoxShadow(
                            color: (index % 3 == 0
                              ? _primaryGold
                              : index % 3 == 1
                                ? _accentPurple
                                : _accentBlue).withValues(alpha: 0.6),
                            blurRadius: 12,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom - 64,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        // Premium Badge with Glow
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_primaryGold, const Color(0xFFFFA500)],
                            ),
                            borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryGold.withValues(alpha: 0.5),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium_rounded,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'PRO ÜYE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        )
                            .animate(onPlay: (controller) => controller.repeat())
                            .shimmer(
                              duration: 3.seconds,
                              color: Colors.white.withValues(alpha: 0.5),
                            )
                            .then()
                            .shake(
                              duration: 3.seconds,
                              hz: 1,
                              curve: Curves.easeInOut,
                            ),

                        const SizedBox(height: 32),

                        // Lottie Celebration Animation
                        SizedBox(
                          height: 220,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Glow effect behind lottie
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _primaryGold.withValues(alpha: 0.3),
                                      blurRadius: 60,
                                      spreadRadius: 20,
                                    ),
                                  ],
                                ),
                              ),
                              Lottie.asset(
                                'assets/lotties/Done.json',
                                fit: BoxFit.contain,
                                repeat: true,
                                animate: true,
                              ),
                            ],
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .scale(
                              begin: const Offset(0.8, 0.8),
                              duration: 800.ms,
                              curve: Curves.elasticOut,
                            ),

                        const SizedBox(height: 32),

                        // Welcome Message
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              _primaryGold,
                              const Color(0xFFFFA500),
                              _accentPurple,
                            ],
                          ).createShader(bounds),
                          child: Text(
                            user?.firstName != null
                                ? 'Hoş Geldin ${user!.firstName}!'
                                : 'Hoş Geldin!',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.2,
                              letterSpacing: -1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 400.ms, duration: 600.ms)
                            .slideY(begin: 0.2, end: 0),

                        const SizedBox(height: 16),

                        // Subtitle
                        Text(
                          'Artık sınır yok. Rakiplerinin önüne geçmeni sağlayacak süper güçlerin kilidi açıldı.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.8)
                                : Colors.black.withValues(alpha: 0.7),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        )
                            .animate()
                            .fadeIn(delay: 600.ms, duration: 600.ms)
                            .slideY(begin: 0.2, end: 0),

                        const SizedBox(height: 24),

                        // Support Message
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                color: _primaryGold,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  _getSupportMessage(user?.selectedExam),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.75)
                                        : Colors.black.withValues(alpha: 0.65),
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 800.ms, duration: 600.ms)
                            .scale(
                              begin: const Offset(0.9, 0.9),
                              duration: 600.ms,
                              curve: Curves.easeOut,
                            ),
                      ],
                    ),

                    // CTA Button
                    const SizedBox(height: 32),
                    Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_accentBlue, _accentPurple],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _accentBlue.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 0,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _handleContinue,
                        borderRadius: BorderRadius.circular(16),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Güçlerimi Göster',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 1000.ms, duration: 600.ms)
                      .slideY(begin: 0.3, end: 0)
                      .then()
                      .shimmer(
                        delay: 1800.ms,
                        duration: 2.seconds,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

