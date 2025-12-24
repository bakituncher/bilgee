// lib/features/stats/widgets/overview_content.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/stats/utils/stats_calculator.dart';
import 'package:taktik/features/stats/widgets/enhanced_activity_card.dart';
import 'package:taktik/features/stats/widgets/motivational_footer.dart';
import 'package:taktik/features/stats/widgets/performance_charts.dart';
import 'package:taktik/features/stats/widgets/premium_hero_card.dart';
import 'package:taktik/features/stats/widgets/subject_breakdown_widgets.dart';
import 'package:taktik/features/stats/widgets/topic_performance_carousel.dart';

/// Main content widget with all overview sections
class OverviewContent extends ConsumerWidget {
  final UserModel user;
  final List<TestModel> tests;
  final bool isDark;

  const OverviewContent({
    super.key,
    required this.user,
    required this.tests,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eğer kullanıcının hiç testi yoksa boş durum ekranı göster
    if (tests.isEmpty) {
      return _buildEmptyState(context, ref);
    }

    final streak = StatsCalculator.calculateStreak(tests);
    final avgNet = StatsCalculator.calculateAvgNet(user, tests);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Premium Hero Kartı - Sektör seviyesinde tasarım
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: PremiumHeroCard(
              user: user,
              tests: tests,
              isDark: isDark,
              streak: streak,
              avgNet: avgNet,
            ).animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: -0.05, duration: 500.ms, curve: Curves.easeOutCubic)
              .shimmer(duration: 1500.ms, delay: 300.ms),
          ),
        ),

        // Performans Grafikleri - Kompakt kaydırılabilir kartlar
        if (tests.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryBrandColor,
                              AppTheme.secondaryBrandColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBrandColor.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.insights_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Performans Trendleri',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Gelişimini grafiklerle takip et',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.black.withOpacity(0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Kaydırma ipucu
                      if (user.selectedExam == 'YKS')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : AppTheme.primaryBrandColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.12)
                                  : AppTheme.primaryBrandColor.withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.swipe_rounded,
                                size: 14,
                                color: isDark
                                    ? Colors.white.withOpacity(0.6)
                                    : AppTheme.primaryBrandColor.withOpacity(0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Kaydır',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.6)
                                      : AppTheme.primaryBrandColor.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ).animate(delay: 300.ms).fadeIn().slideX(begin: -0.05),
                ),
                SizedBox(
                  height: 220,
                  child: SmartPerformanceCharts(
                    tests: tests,
                    isDark: isDark,
                    examType: user.selectedExam ?? 'YKS',
                  ).animate(delay: 350.ms).fadeIn(duration: 300.ms),
                ),
              ],
            ),
          ),

        // Konu Performansı Carousel - Yatay kaydırılabilir (Coach screen'den girilen veriler)
        SliverToBoxAdapter(
          child: TopicPerformanceCarousel(
            isDark: isDark,
          ).animate(delay: 400.ms)
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.05, curve: Curves.easeOutCubic),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // Daily Activity & Subject Performance - Kompakt
        if (tests.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Aktivite Haritası (üstte)
                  EnhancedActivityCard(
                    userId: user.id,
                    isDark: isDark,
                    tests: tests,
                  ).animate(delay: 450.ms)
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.05, curve: Curves.easeOutCubic),

                  const SizedBox(height: 12),

                  // Ders Performansı (altta)
                  EnhancedSubjectBreakdown(
                    tests: tests,
                    isDark: isDark,
                  ).animate(delay: 500.ms)
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.05, curve: Curves.easeOutCubic),
                ],
              ),
            ),
          ),

        // Motivasyonel Alt Bilgi
        if (tests.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: MotivationalFooter(
                tests: tests,
                streak: streak,
                isDark: isDark,
              ).animate(delay: 550.ms)
                .fadeIn(duration: 300.ms)
                .scale(begin: const Offset(0.95, 0.95)),
            ),
          ),

        // Bottom spacing
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
      ],
    );
  }

  /// Test ekleme sayfasına yönlendir
  void _handleTestAdd(BuildContext context, WidgetRef ref) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null || user.selectedExam == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen önce bir sınav türü seçin')),
        );
      }
      return;
    }
    // Test ekleme sayfasına yönlendir
    context.push('/coach/select-subject');
  }

  /// Deneme ekleme sayfasına yönlendir
  void _handleTrialAdd(BuildContext context, WidgetRef ref) {
    context.push('/home/add-test');
  }

  /// Boş durum ekranı - Kullanıcının analiz edilecek verisi olmadığında gösterilir
  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lottie Animasyonu
              Container(
                constraints: const BoxConstraints(
                  maxWidth: 320,
                  maxHeight: 320,
                ),
                child: Lottie.asset(
                  'assets/lotties/Data Analysis.json',
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ).animate()
                .fadeIn(duration: 500.ms)
                .scale(begin: const Offset(0.8, 0.8), duration: 600.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 24),

              // Başlık
              Text(
                'Henüz Analiz Verisi Yok',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 200.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.1, duration: 500.ms),

              const SizedBox(height: 12),

              // Açıklama
              Text(
                'İstatistiklerini ve performans analizini görmek için test veya deneme ekle, Taktik senin için analiz etsin.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark
                    ? Colors.white.withOpacity(0.6)
                    : Colors.black.withOpacity(0.5),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 300.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.1, duration: 500.ms),

              const SizedBox(height: 32),

              // Aksiyon Butonları
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      context: context,
                      icon: Icons.library_books_rounded,
                      label: 'Test Ekle',
                      description: 'Çözdüğün testleri kaydet',
                      isDark: isDark,
                      onTap: () => _handleTestAdd(context, ref),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      context: context,
                      icon: Icons.add_chart_rounded,
                      label: 'Deneme Ekle',
                      description: 'Çözdüğün denemeleri kaydet',
                      isDark: isDark,
                      onTap: () => _handleTrialAdd(context, ref),
                    ),
                  ),
                ],
              ).animate(delay: 400.ms)
                .fadeIn(duration: 500.ms)
                .slideY(begin: 0.15, duration: 600.ms, curve: Curves.easeOutCubic)
                .shimmer(delay: 800.ms, duration: 1500.ms),
            ],
          ),
        ),
      ),
    );
  }

  /// Dinamik font boyutu hesaplama
  double _calculateFontSize(String text, double maxWidth, {
    double minFontSize = 11.0,
    double maxFontSize = 15.0,
    FontWeight fontWeight = FontWeight.w800,
  }) {
    for (double fontSize = maxFontSize; fontSize >= minFontSize; fontSize -= 0.5) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            letterSpacing: -0.3,
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();

      if (textPainter.width <= maxWidth) {
        return fontSize;
      }
    }
    return minFontSize;
  }

  /// Aksiyon butonu widget'ı - Sektör Seviyesi Tasarım
  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String description,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth - 32;
        final labelFontSize = _calculateFontSize(
          label,
          maxWidth,
          maxFontSize: 15.0,
          minFontSize: 12.0,
        );
        final descFontSize = _calculateFontSize(
          description,
          maxWidth,
          maxFontSize: 12.0,
          minFontSize: 10.0,
          fontWeight: FontWeight.w500,
        );

        final isSmallScreen = constraints.maxWidth < 160;
        final iconSize = isSmallScreen ? 26.0 : 32.0;
        final iconPadding = isSmallScreen ? 12.0 : 14.0;
        final verticalPadding = isSmallScreen ? 16.0 : 20.0;
        final spaceBetween = isSmallScreen ? 10.0 : 14.0;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF2E3192).withOpacity(0.25),
                        const Color(0xFF1BFFFF).withOpacity(0.15),
                      ]
                    : [
                        const Color(0xFF2E3192).withOpacity(0.08),
                        const Color(0xFF1BFFFF).withOpacity(0.05),
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF2E3192).withOpacity(isDark ? 0.4 : 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E3192).withOpacity(isDark ? 0.2 : 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gradient Icon Container
                Container(
                  padding: EdgeInsets.all(iconPadding),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E3192).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
                SizedBox(height: spaceBetween),
                // Gradient Text Label
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: descFontSize,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white.withOpacity(0.7)
                        : Colors.black.withOpacity(0.6),
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

