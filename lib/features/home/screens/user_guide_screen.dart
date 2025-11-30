// lib/features/home/screens/user_guide_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'dart:async';

class UserGuideScreen extends StatefulWidget {
  const UserGuideScreen({super.key});

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> with TickerProviderStateMixin {
  late final AnimationController _headerSlideController;
  late final AnimationController _fadeController;
  late final AnimationController _gradientController;
  late final PageController _pageController;

  late final Animation<double> _gradientAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _headerSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
    _pageController = PageController();

    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _gradientController,
        curve: Curves.easeInOutSine,
      ),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _headerSlideController.forward();
        _fadeController.forward();
        _startAutoSlide();
      }
    });
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (!_pageController.hasClients) return;

      int nextPage = _pageController.page!.round() + 1;
      if (nextPage >= 5) {
        nextPage = 0;
      }
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _headerSlideController.dispose();
    _fadeController.dispose();
    _gradientController.dispose();
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    final guideSlides = [
      (
        title: 'Deneme Verilerini Kaydet',
        subtitle: 'Her deneme sonucunu hemen kaydet. Kendini tanı, gelişimini gör, hedefine odaklan.',
        icon: Icons.assessment_rounded,
        color: const Color(0xFFE63946),
        badge: 'ÖNEMLİ',
      ),
      (
        title: 'Yapay Zeka Analizi',
        subtitle: 'AI performansını analiz eder, zayıf konuları tespit eder, özel strateji sunar.',
        icon: Icons.psychology_alt_rounded,
        color: const Color(0xFF5b3d88),
        badge: null,
      ),
      (
        title: 'Gelişim Grafiklerini İncele',
        subtitle: 'Deneme arşivi ve istatistik ekranlarında ilerlemeyi takip et, motive ol.',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF2E7D32),
        badge: 'TAKİP',
      ),
      (
        title: 'Haftalık Akıllı Plan',
        subtitle: 'Verilerine göre optimize edilmiş, müfredat sıralı, dinamik çalışma planı.',
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF1565C0),
        badge: null,
      ),
      (
        title: 'Cevher Atölyesi',
        subtitle: 'Zayıf konularda soru çöz, öğren, pekiştir. AI destekli kişisel atölye.',
        icon: Icons.diamond_outlined,
        color: const Color(0xFFFFB020),
        badge: null,
      ),
    ];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Animated Gradient Background
          _buildAnimatedGradientBackground(),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Container(color: colorScheme.surface.withOpacity(0.3)),
          ),

          Column(
            children: [
              // Header with close button
              _buildCustomHeader(context),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Hero Section - Kompakt
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: isSmallScreen ? 4 : 6,
                        ),
                        child: _AnimatedHeader(
                          slideController: _headerSlideController,
                          fadeController: _fadeController,
                          isSmallScreen: isSmallScreen,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 4 : 6),

                      // Features Carousel - Kompakt
                      _buildFeaturesCarousel(guideSlides, isSmallScreen),
                      SizedBox(height: isSmallScreen ? 6 : 8),

                      // Page Indicator - Kompakt
                      _buildPageIndicator(guideSlides),
                      SizedBox(height: isSmallScreen ? 10 : 14),

                      // Data Entry Emphasis - YENİ
                      FadeTransition(
                        opacity: _fadeController,
                        child: _buildDataEntryEmphasis(context, isSmallScreen),
                      ),
                      SizedBox(height: isSmallScreen ? 10 : 14),

                      // Quick Success Tips - Kompakt
                      FadeTransition(
                        opacity: _fadeController,
                        child: _buildQuickTipsSection(context, isSmallScreen),
                      ),
                      SizedBox(height: isSmallScreen ? 10 : 14),

                      // Screen Navigation Tips - YENİ
                      FadeTransition(
                        opacity: _fadeController,
                        child: _buildScreenNavigationTips(context, isSmallScreen),
                      ),
                      SizedBox(height: isSmallScreen ? 14 : 18),

                      // CTA Button - Kompakt
                      FadeTransition(
                        opacity: _fadeController,
                        child: _buildCTAButton(context, isSmallScreen),
                      ),

                      SizedBox(height: MediaQuery.of(context).padding.bottom + 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 8,
        right: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 26,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            tooltip: 'Kapat',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          Text(
            'Hızlı Başlangıç',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(width: 48), // Balance for close button
        ],
      ),
    );
  }

  Widget _buildAnimatedGradientBackground() {
    return AnimatedBuilder(
      animation: _gradientAnimation,
      builder: (context, child) {
        final colorScheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                0.5 + 0.5 * (1 - _gradientAnimation.value),
                0.5 - 0.5 * _gradientAnimation.value,
              ),
              radius: 1.5,
              colors: isDark
                  ? [
                      colorScheme.surface,
                      colorScheme.surface,
                      Color.lerp(colorScheme.surface, Colors.black, 0.5)!,
                    ]
                  : [
                      colorScheme.surface,
                      Color.lerp(colorScheme.surface, colorScheme.primary, 0.05)!,
                      Color.lerp(colorScheme.surface, colorScheme.secondary, 0.08)!,
                    ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeaturesCarousel(
    List<({String title, String subtitle, IconData icon, Color color, String? badge})> slides,
    bool isSmallScreen,
  ) {
    final carouselHeight = isSmallScreen ? 90.0 : 105.0;

    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        height: carouselHeight,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        child: PageView.builder(
          controller: _pageController,
          itemCount: slides.length,
          itemBuilder: (context, index) {
            final slide = slides[index];
            return _FeatureSlideCard(
              title: slide.title,
              subtitle: slide.subtitle,
              icon: slide.icon,
              color: slide.color,
              badge: slide.badge,
              isSmallScreen: isSmallScreen,
            );
          },
        ),
      ),
    );
  }

  Widget _buildPageIndicator(
    List<({String title, String subtitle, IconData icon, Color color, String? badge})> slides,
  ) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double currentPage = _pageController.hasClients ? _pageController.page ?? 0 : 0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(slides.length, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: index == currentPage.round() ? 20.0 : 6.0,
                height: 6.0,
                decoration: BoxDecoration(
                  gradient: index == currentPage.round()
                      ? const LinearGradient(
                          colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  color: index == currentPage.round()
                      ? null
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: index == currentPage.round()
                      ? [
                          BoxShadow(
                            color: const Color(0xFF2E3192).withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildDataEntryEmphasis(BuildContext context, bool isSmallScreen) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFFE63946).withOpacity(0.15),
                  const Color(0xFFE63946).withOpacity(0.08),
                ]
              : [
                  const Color(0xFFE63946).withOpacity(0.12),
                  const Color(0xFFE63946).withOpacity(0.06),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE63946).withOpacity(isDark ? 0.4 : 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE63946).withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE63946), Color(0xFFD62839)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE63946).withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.priority_high_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Veri Girişi = Başarının Anahtarı',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 15 : 16,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          Text(
            'Deneme sonuçlarını düzenli kaydetmek, yapay zekanın seni doğru analiz etmesini sağlar. '
            'Kendini tanı, zayıf yönlerini keşfet, güçlü yanlarını geliştir.',
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE63946).withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFE63946).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_graph_rounded,
                  size: 14,
                  color: Color(0xFFE63946),
                ),
                const SizedBox(width: 6),
                Text(
                  'Düzenli veri girişi yapanlar %67 daha hızlı gelişiyor',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10.5 : 11.5,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTipsSection(BuildContext context, bool isSmallScreen) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  colorScheme.surface,
                  Color.lerp(colorScheme.surface, colorScheme.primary, 0.08)!,
                ]
              : [
                  Colors.white,
                  Color.lerp(Colors.white, colorScheme.primary, 0.05)!,
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withOpacity(isDark ? 0.3 : 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.tips_and_updates_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Günlük Rutin',
                style: TextStyle(
                  fontSize: isSmallScreen ? 15 : 16,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          _buildCompactTipRow(context, '1', 'Her gün aynı saatte giriş yap', isSmallScreen),
          SizedBox(height: isSmallScreen ? 7 : 8),
          _buildCompactTipRow(context, '2', 'Deneme çözdükten hemen sonra kaydet', isSmallScreen),
          SizedBox(height: isSmallScreen ? 7 : 8),
          _buildCompactTipRow(context, '3', 'Haftalık planını takip et, işaretle', isSmallScreen),
          SizedBox(height: isSmallScreen ? 7 : 8),
          _buildCompactTipRow(context, '4', 'Günlük 10 dk = 90 günde %40 net artışı', isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildScreenNavigationTips(BuildContext context, bool isSmallScreen) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  colorScheme.surface,
                  Color.lerp(colorScheme.surface, const Color(0xFF2E7D32), 0.08)!,
                ]
              : [
                  Colors.white,
                  Color.lerp(Colors.white, const Color(0xFF2E7D32), 0.05)!,
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2E7D32).withOpacity(isDark ? 0.3 : 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Keşfedilecek Ekranlar',
                style: TextStyle(
                  fontSize: isSmallScreen ? 15 : 16,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          _buildScreenTip(
            context,
            Icons.history_rounded,
            'Deneme Arşivi',
            'Tüm deneme sonuçlarını gör, karşılaştır',
            const Color(0xFF1565C0),
            isSmallScreen,
          ),
          SizedBox(height: isSmallScreen ? 7 : 8),
          _buildScreenTip(
            context,
            Icons.show_chart_rounded,
            'Deneme Gelişimi',
            'Grafik ve trendlerle ilerlemeyi takip et',
            const Color(0xFF2E7D32),
            isSmallScreen,
          ),
          SizedBox(height: isSmallScreen ? 7 : 8),
          _buildScreenTip(
            context,
            Icons.dashboard_rounded,
            'Genel Bakış',
            'Performansını toplu halde analiz et',
            const Color(0xFF5b3d88),
            isSmallScreen,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTipRow(BuildContext context, String number, String text, bool isSmallScreen) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: isSmallScreen ? 20 : 22,
          height: isSmallScreen ? 20 : 22,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.secondary],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: isSmallScreen ? 10.5 : 11.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenTip(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    Color color,
    bool isSmallScreen,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: isSmallScreen ? 32 : 36,
          height: isSmallScreen ? 32 : 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: isSmallScreen ? 16 : 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: isSmallScreen ? 13 : 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 12,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCTAButton(BuildContext context, bool isSmallScreen) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: isSmallScreen ? 14 : 16,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E3192).withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: const Color(0xFF1BFFFF).withOpacity(0.25),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Anladım, Başlayalım!',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 15 : 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// --- WIDGETS ---
// ====================================================================

class _AnimatedHeader extends StatelessWidget {
  final AnimationController slideController;
  final AnimationController fadeController;
  final bool isSmallScreen;

  const _AnimatedHeader({
    required this.slideController,
    required this.fadeController,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = isSmallScreen ? 28.0 : 34.0;
    final titleSize = isSmallScreen ? 22.0 : 26.0;
    final subtitleSize = isSmallScreen ? 12.5 : 14.0;
    final iconPadding = isSmallScreen ? 8.0 : 10.0;

    return Column(
      children: [
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: slideController,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: FadeTransition(
            opacity: fadeController,
            child: Container(
              padding: EdgeInsets.all(iconPadding),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E3192).withOpacity(0.4),
                    blurRadius: isSmallScreen ? 16 : 20,
                    spreadRadius: isSmallScreen ? 1 : 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFF1BFFFF).withOpacity(0.3),
                    blurRadius: isSmallScreen ? 20 : 26,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Icon(
                Icons.rocket_launch_rounded,
                size: iconSize,
                color: Colors.white,
                shadows: const [Shadow(color: Colors.black26, blurRadius: 8)],
              ),
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 10 : 12),
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: slideController,
              curve: const Interval(0.2, 1, curve: Curves.easeOutCubic),
            ),
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: fadeController,
              curve: const Interval(0.2, 1),
            ),
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                'Başarıya Giden Yol',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontSize: titleSize,
                  letterSpacing: -0.8,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 5 : 7),
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: slideController,
              curve: const Interval(0.4, 1, curve: Curves.easeOutCubic),
            ),
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: fadeController,
              curve: const Interval(0.4, 1),
            ),
            child: Text(
              'Verilerini kaydet, AI\'den öğren, hedefe koş',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
                fontWeight: FontWeight.w600,
                fontSize: subtitleSize,
                height: 1.3,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureSlideCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? badge;
  final bool isSmallScreen;

  const _FeatureSlideCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.badge,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardPadding = isSmallScreen ? 12.0 : 14.0;
    final iconSize = isSmallScreen ? 32.0 : 38.0;
    final iconInnerSize = isSmallScreen ? 18.0 : 20.0;
    final titleSize = isSmallScreen ? 13.5 : 15.0;
    final subtitleSize = isSmallScreen ? 11.0 : 12.0;
    final spacing = isSmallScreen ? 10.0 : 12.0;

    return Container(
      padding: EdgeInsets.all(cardPadding),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  colorScheme.surface,
                  Color.lerp(colorScheme.surface, color, 0.12)!,
                ]
              : [
                  Colors.white,
                  Color.lerp(Colors.white, color, 0.08)!,
                ],
        ),
        borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 18),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.5 : 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: isSmallScreen ? 16 : 20,
            spreadRadius: 0,
            offset: Offset(0, isSmallScreen ? 5 : 8),
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withOpacity(0.7)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: isSmallScreen ? 10 : 14,
                      spreadRadius: 0,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: iconInnerSize),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                        fontSize: titleSize,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallScreen ? 3 : 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.75),
                        fontSize: subtitleSize,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

