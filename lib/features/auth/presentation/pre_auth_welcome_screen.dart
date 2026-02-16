import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import 'package:google_fonts/google_fonts.dart'; // <-- KALDIRILDI
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
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. ARKA PLAN GÖRSELİ
          Positioned.fill(
            child: Image.asset(
              'assets/images/giris.webp',
              fit: BoxFit.cover,
            ),
          ),

          // 2. GRADIENT OVERLAY
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.transparent,
                    Colors.black.withOpacity(0.7), // Alt kısımdaki karartma
                    Colors.black,
                  ],
                  stops: const [0.0, 0.4, 0.8, 1.0],
                ),
              ),
            ),
          ),

          // 3. İÇERİK
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),

                // --- LOGO & BRAND (Üstte Ortada) ---
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Hero(
                          tag: 'app_logo',
                          child: Image.asset(
                            'assets/images/splash.png',
                            height: 40,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _AnimatedBrandText(
                          text: 'Taktik',
                          controller: _controller,
                          // DÜZELTME: GoogleFonts yerine TextStyle
                          textStyle: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // --- ALT METİN BLOĞU (SOLA DAYALI) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, // Sola yaslı
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // BAŞLIK
                        _ShimmerText(
                          text: 'Yolun Zorlu,\nAma Yalnız Değilsin',
                          textAlign: TextAlign.start,
                          style: textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 32,
                            height: 1.1,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            fontFamily: 'Montserrat', // Font eklendi
                          ),
                          gradientColors: const [Colors.white, Colors.white],
                        ),

                        const SizedBox(height: 16),

                        // AÇIKLAMA METNİ (Düzeltildi: Tam Beyaz)
                        Text(
                          'Düştüğünde kaldıran, başardığında seninle sevinen yol arkadaşın burada. Başarı hikayeni birlikte yazalım.',
                          textAlign: TextAlign.start,
                          style: textTheme.bodyLarge?.copyWith(
                            color: Colors.white, // Artık opacity yok, tam beyaz.
                            fontSize: 16,
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'Montserrat', // Font eklendi
                          ),
                        ),

                        const SizedBox(height: 32),

                        // BUTON
                        _PremiumButton(
                          onTap: () => _continue(context),
                          pulseController: _pulseController,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- YARDIMCI WIDGET'LAR ---

class _AnimatedBrandText extends StatelessWidget {
  final String text;
  final AnimationController controller;
  final TextStyle textStyle;

  const _AnimatedBrandText({
    required this.text,
    required this.controller,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final letters = text.split('');
    const double startInterval = 0.2;
    const double endInterval = 0.8;
    final double intervalStep = (endInterval - startInterval) / letters.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(letters.length, (index) {
        final double letterStart = startInterval + (index * intervalStep * 0.5);
        final double letterEnd = letterStart + 0.4;

        final animation = CurvedAnimation(
          parent: controller,
          curve: Interval(
            letterStart.clamp(0.0, 1.0),
            letterEnd.clamp(0.0, 1.0),
            curve: Curves.easeOutBack,
          ),
        );

        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Opacity(
              opacity: animation.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - animation.value)),
                child: Text(
                  letters[index],
                  style: textStyle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class _ShimmerText extends StatelessWidget {
  const _ShimmerText({
    required this.text,
    required this.style,
    required this.gradientColors,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final TextStyle? style;
  final List<Color> gradientColors;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [
          Colors.white,
          const Color(0xFFE0F2FE),
          Colors.white,
        ],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Text(
        text,
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}

class _PremiumButton extends StatefulWidget {
  const _PremiumButton({
    required this.onTap,
    required this.pulseController,
  });

  final VoidCallback onTap;
  final AnimationController pulseController;

  @override
  State<_PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<_PremiumButton> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    // Döngü süresi 4 saniye
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: widget.pulseController,
      builder: (context, child) {
        final scale = 1.0 + (widget.pulseController.value * 0.02);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF2563EB), // Net Mavi
                  Color(0xFF16A34A), // Net Yeşil
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(0.4), // DÜZELTME: withOpacity
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // 1. SHIMMER EFEKTİ (ÖNCE BEKLE, SONRA GEÇ)
                  AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      const double startPoint = 0.8;
                      final double value = _shimmerController.value;

                      if (value < startPoint) {
                        return const SizedBox();
                      }

                      final double normalizedValue = (value - startPoint) / (1.0 - startPoint);

                      return FractionallySizedBox(
                        widthFactor: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.15), // DÜZELTME: withOpacity
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                              begin: Alignment(-2.5 + (normalizedValue * 5), -0.5),
                              end: Alignment(-1.5 + (normalizedValue * 5), 0.5),
                              tileMode: TileMode.clamp,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // 2. TIKLANABİLİR ALAN
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onTap,
                      borderRadius: BorderRadius.circular(12),
                      overlayColor: WidgetStateProperty.all(Colors.white.withOpacity(0.1)), // DÜZELTME
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Yolculuğa Başla',
                              style: textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 0.5,
                                fontFamily: 'Montserrat', // Font eklendi
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}