import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/data/providers/shared_prefs_provider.dart';

class PreAuthWelcomeScreen extends ConsumerStatefulWidget {
  const PreAuthWelcomeScreen({super.key});

  @override
  ConsumerState<PreAuthWelcomeScreen> createState() => _PreAuthWelcomeScreenState();
}

class _PreAuthWelcomeScreenState extends ConsumerState<PreAuthWelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  // Premium color palette - Uygulama renkleriyle uyumlu mavi tonları
  static const _gradientColors = [
    Color(0xFF22D3EE), // Vivid Cyan (app secondary)
    Color(0xFF0EA5E9), // Sky blue
    Color(0xFF38BDF8), // Light sky
    Color(0xFF06B6D4), // Cyan
  ];

  static const _accentGradient = [
    Color(0xFF0EA5E9), // Sky blue
    Color(0xFF22D3EE), // Vivid Cyan
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _continue(BuildContext context) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool('hasSeenWelcomeScreen', true);

    if (context.mounted) {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF0D0D0D),
                            const Color(0xFF1A1A2E),
                            const Color(0xFF16213E),
                          ]
                        : [
                            const Color(0xFFF8FAFC),
                            const Color(0xFFEEF2FF),
                            const Color(0xFFFDF4FF),
                          ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              );
            },
          ),
          // Floating orbs - Instagram style
          Positioned(
            top: -size.height * 0.15,
            right: -size.width * 0.3,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: size.width * 0.8,
                    height: size.width * 0.8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _gradientColors[0].withValues(alpha: isDark ? 0.3 : 0.15),
                          _gradientColors[1].withValues(alpha: isDark ? 0.1 : 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: -size.height * 0.1,
            left: -size.width * 0.4,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 2 - _pulseAnimation.value,
                  child: Container(
                    width: size.width * 0.9,
                    height: size.width * 0.9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _gradientColors[2].withValues(alpha: isDark ? 0.25 : 0.12),
                          _gradientColors[3].withValues(alpha: isDark ? 0.08 : 0.04),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 40),
                              // Premium Logo with glow
                              ScaleTransition(
                                scale: _scaleAnimation,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _accentGradient[0].withValues(alpha: 0.3),
                                        blurRadius: 40,
                                        spreadRadius: 5,
                                      ),
                                      BoxShadow(
                                        color: _accentGradient[1].withValues(alpha: 0.2),
                                        blurRadius: 60,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/images/splash.png',
                                    height: 80,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Premium title with shimmer effect
                              _ShimmerText(
                                text: 'Taktik\'e Hoş Geldin!',
                                style: textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 32,
                                  letterSpacing: -1,
                                  height: 1.1,
                                ),
                                gradientColors: _accentGradient,
                              ),
                              const SizedBox(height: 16),
                              // Elegant subtitle
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                                ),
                                child: Text(
                                  'Kişisel koçunla tanışmaya hazır mısın? ✨',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),
                              // Premium Feature Cards with staggered animation
                              _PremiumFeatureCard(
                                icon: Icons.auto_awesome_rounded,
                                title: 'Kişiye Özel Eğitim Koçu',
                                subtitle: 'Seni anlayan, zayıf yönlerini belirleyen ve sana özel stratejiler üreten koçun.',
                                gradientColors: const [Color(0xFF0EA5E9), Color(0xFF22D3EE)],
                                delay: 0,
                                controller: _controller,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 16),
                              _PremiumFeatureCard(
                                icon: Icons.insights_rounded,
                                title: 'Detaylı Performans Analizi',
                                subtitle: 'Her deneme sonrası netlerini, konu başarılarını ve gelişimini takip et.',
                                gradientColors: const [Color(0xFF06B6D4), Color(0xFF38BDF8)],
                                delay: 1,
                                controller: _controller,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 16),
                              _PremiumFeatureCard(
                                icon: Icons.calendar_month_rounded,
                                title: 'Haftalık Planlama',
                                subtitle: 'Haftalık ve günlük hedeflerini belirle, zamanını en verimli şekilde kullan.',
                                gradientColors: const [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                                delay: 2,
                                controller: _controller,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                      // Premium CTA Button
                      _PremiumButton(
                        onTap: () => _continue(context),
                        pulseController: _pulseController,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Shimmer text effect widget - Google/Instagram style
class _ShimmerText extends StatelessWidget {
  const _ShimmerText({
    required this.text,
    required this.style,
    required this.gradientColors,
  });

  final String text;
  final TextStyle? style;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: style?.copyWith(color: Colors.white),
      ),
    );
  }
}

// Premium feature card with glassmorphism
class _PremiumFeatureCard extends StatelessWidget {
  const _PremiumFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.delay,
    required this.controller,
    required this.isDark,
    this.isCompact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final int delay;
  final AnimationController controller;
  final bool isDark;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Interval(
        0.2 + (delay * 0.1),
        0.6 + (delay * 0.1),
        curve: Curves.easeOutCubic,
      ),
    ));

    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Interval(
        0.2 + (delay * 0.1),
        0.5 + (delay * 0.1),
        curve: Curves.easeOut,
      ),
    ));

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: Container(
          padding: EdgeInsets.all(isCompact ? 12 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
            // Glassmorphism effect
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.7),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : gradientColors[0].withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withValues(alpha: isDark ? 0.15 : 0.08),
                blurRadius: isCompact ? 12 : 20,
                offset: Offset(0, isCompact ? 4 : 8),
              ),
              if (!isDark)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.8),
                  blurRadius: isCompact ? 6 : 10,
                  offset: Offset(isCompact ? -3 : -5, isCompact ? -3 : -5),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon container with gradient
                  Container(
                    padding: EdgeInsets.all(isCompact ? 8 : 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(isCompact ? 10 : 14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gradientColors[0].withValues(alpha: 0.4),
                          blurRadius: isCompact ? 8 : 12,
                          offset: Offset(0, isCompact ? 2 : 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: isCompact ? 20 : 26,
                    ),
                  ),
                  SizedBox(width: isCompact ? 10 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: isCompact ? 14 : 16,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: isCompact ? 3 : 6),
                        Text(
                          subtitle,
                          style: textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: isCompact ? 11 : 13,
                            height: 1.4,
                            letterSpacing: 0.1,
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
      ),
    );
  }
}

// Premium animated CTA button
class _PremiumButton extends StatelessWidget {
  const _PremiumButton({
    required this.onTap,
    required this.pulseController,
    this.isCompact = false,
  });

  final VoidCallback onTap;
  final AnimationController pulseController;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final scale = 1.0 + (pulseController.value * 0.02);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isCompact ? 14 : 18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0EA5E9), // Sky blue
                  Color(0xFF22D3EE), // Vivid Cyan
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.4),
                  blurRadius: isCompact ? 12 : 20,
                  offset: Offset(0, isCompact ? 4 : 8),
                ),
                BoxShadow(
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.3),
                  blurRadius: isCompact ? 20 : 30,
                  offset: Offset(0, isCompact ? 8 : 12),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(isCompact ? 14 : 18),
                splashColor: Colors.white.withValues(alpha: 0.2),
                highlightColor: Colors.white.withValues(alpha: 0.1),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: isCompact ? 14 : 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Hadi Başlayalım',
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: isCompact ? 15 : 17,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(width: isCompact ? 8 : 10),
                      Container(
                        padding: EdgeInsets.all(isCompact ? 3 : 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(isCompact ? 6 : 8),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: isCompact ? 16 : 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

