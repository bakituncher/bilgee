// lib/features/stats/widgets/overview_content.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/features/stats/utils/stats_calculator.dart';
import 'package:taktik/features/stats/widgets/enhanced_activity_card.dart';
import 'package:taktik/features/stats/widgets/motivational_footer.dart';
import 'package:taktik/features/stats/widgets/performance_charts.dart';
import 'package:taktik/features/stats/widgets/premium_hero_card.dart';
import 'package:taktik/features/stats/widgets/subject_breakdown_widgets.dart';

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
    final streak = StatsCalculator.calculateStreak(tests);
    final avgNet = StatsCalculator.calculateAvgNet(user, tests);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Premium Hero Kartı - Sektör seviyesinde tasarım
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryBrandColor.withOpacity(0.2),
                              AppTheme.secondaryBrandColor.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.insights_rounded,
                          color: AppTheme.primaryBrandColor,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Performans Trendleri',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Gelişimini takip et',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white.withOpacity(0.5)
                                  : Colors.black.withOpacity(0.45),
                            ),
                          ),
                        ],
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

        const SliverToBoxAdapter(child: SizedBox(height: 4)),

        // Daily Activity & Subject Performance - Kompakt
        if (tests.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Aktivite Haritası
                  EnhancedActivityCard(
                    userId: user.id,
                    isDark: isDark,
                    tests: tests,
                  ).animate(delay: 400.ms)
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.05, curve: Curves.easeOutCubic),

                  const SizedBox(height: 8),

                  // Ders Performansı
                  EnhancedSubjectBreakdown(
                    tests: tests,
                    isDark: isDark,
                  ).animate(delay: 450.ms)
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: MotivationalFooter(
                tests: tests,
                streak: streak,
                isDark: isDark,
              ).animate(delay: 500.ms)
                .fadeIn(duration: 300.ms)
                .scale(begin: const Offset(0.95, 0.95)),
            ),
          ),

        // Bottom spacing
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }
}

