// lib/features/stats/screens/general_overview_screen.dart
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:taktik/core/services/admob_service.dart';
import 'package:taktik/utils/age_helper.dart';

// Constants
const int _maxRecentTests = 8;
const int _daysToShowVisits = 30;

/// Redesigned General Overview Screen with sector-level education analytics
/// Features: Modern design, comprehensive metrics, interactive charts, elegant UI
class GeneralOverviewScreen extends ConsumerStatefulWidget {
  const GeneralOverviewScreen({super.key});

  @override
  ConsumerState<GeneralOverviewScreen> createState() => _GeneralOverviewScreenState();
}

class _GeneralOverviewScreenState extends ConsumerState<GeneralOverviewScreen> {
  @override
  void initState() {
    super.initState();
    // Show interstitial ad on screen entry (only for non-premium users)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userProfileProvider).value;
      if (user != null) {
        final isUnder18 = AgeHelper.isUnder18(user.dateOfBirth);
        final isPremium = user.isPremium;
        AdMobService().showInterstitialAd(isUnder18: isUnder18, isPremium: isPremium);
      }
    });
  }

  Future<void> _handleBack(BuildContext context) async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final testsAsync = ref.watch(testsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Genel Bakış',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          tooltip: 'Geri',
          onPressed: () => _handleBack(context),
        ),
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Kullanıcı verisi yüklenemedi'));
          }

          final tests = testsAsync.valueOrNull ?? <TestModel>[];
          return _OverviewContent(user: user, tests: tests, isDark: isDark);
        },
        loading: () => const LogoLoader(),
        error: (e, s) => Center(
          child: Text(
            'Hata: $e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}

/// Main content widget with all overview sections
class _OverviewContent extends ConsumerWidget {
  final UserModel user;
  final List<TestModel> tests;
  final bool isDark;

  const _OverviewContent({
    required this.user,
    required this.tests,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = _calculateStreak(tests);
    final avgNet = _calculateAvgNet(user, tests);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Premium Hero Kartı - Sektör seviyesinde tasarım
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _PremiumHeroCard(
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
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
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
                  child: _SmartPerformanceCharts(
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  // Aktivite Haritası
                  _EnhancedActivityCard(
                    userId: user.id,
                    isDark: isDark,
                    tests: tests,
                  ).animate(delay: 400.ms)
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.05, curve: Curves.easeOutCubic),

                  const SizedBox(height: 8),

                  // Ders Performansı
                  _EnhancedSubjectBreakdown(
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
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: _MotivationalFooter(
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

  String _calculateAvgNet(dynamic user, List<TestModel> tests) {
    final testCount = user.testCount ?? tests.length;
    final totalNet = user.totalNetSum ??
        tests.fold<double>(0, (sum, t) => sum + t.totalNet);
    final avgNet = testCount > 0 ? (totalNet / testCount) : 0.0;
    return avgNet.toStringAsFixed(1);
  }

  int _calculateStreak(List<TestModel> tests) {
    if (tests.isEmpty) return 0;

    // Testleri tarihe göre sırala (en yeni en başta)
    final sortedTests = tests.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    int streak = 0;
    DateTime? lastDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final test in sortedTests) {
      final testDate = DateTime(test.date.year, test.date.month, test.date.day);

      if (lastDate == null) {
        // İlk test - bugün veya dün olmalı
        final daysDiff = today.difference(testDate).inDays;
        if (daysDiff <= 1) {
          streak = 1;
          lastDate = testDate;
        } else {
          break; // Seri kırılmış
        }
      } else {
        // Bir önceki günde test var mı?
        final daysDiff = lastDate.difference(testDate).inDays;
        if (daysDiff == 1) {
          streak++;
          lastDate = testDate;
        } else if (daysDiff == 0) {
          // Aynı gün içinde birden fazla test - sayma
          continue;
        } else {
          break; // Seri kırılmış
        }
      }
    }

    return streak;
  }
}

/// Premium Hero Kartı - Sektör seviyesinde tasarım
class _PremiumHeroCard extends StatelessWidget {
  final UserModel user;
  final List<TestModel> tests;
  final bool isDark;
  final int streak;
  final String avgNet;

  const _PremiumHeroCard({
    required this.user,
    required this.tests,
    required this.isDark,
    required this.streak,
    required this.avgNet,
  });

  @override
  Widget build(BuildContext context) {
    final motivationMessage = _getMotivationMessage();
    final motivationColor = _getMotivationColor();
    final progressPercentage = _calculateProgress();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: motivationColor.withOpacity(0.3),
            blurRadius: 32,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Arka plan gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    motivationColor.withOpacity(0.15),
                    motivationColor.withOpacity(0.05),
                    isDark ? const Color(0xFF0F172A) : Colors.white,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Animasyonlu arka plan desenleri
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      motivationColor.withOpacity(0.1),
                      motivationColor.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      motivationColor.withOpacity(0.08),
                      motivationColor.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),

            // İçerik
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst kısım - Karşılama ve durum
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [motivationColor, motivationColor.withOpacity(0.7)],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(isDark ? 0.1 : 0.3),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: motivationColor.withOpacity(0.5),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getMotivationIcon(),
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hoşgeldin, ${user.firstName.isNotEmpty ? user.firstName : 'Öğrenci'}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white.withOpacity(0.6)
                                    : Colors.black.withOpacity(0.5),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              motivationMessage,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                height: 1.2,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Durum rozeti
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [motivationColor, motivationColor.withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: motivationColor.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(),
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getStatusText(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // İstatistik kartları - Grid
                  Row(
                    children: [
                      Expanded(
                        child: _PremiumStatItem(
                          icon: Icons.assignment_turned_in_rounded,
                          label: 'Deneme',
                          value: '${user.testCount ?? 0}',
                          color: const Color(0xFF8B5CF6),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PremiumStatItem(
                          icon: Icons.trending_up_rounded,
                          label: 'Ort. Net',
                          value: avgNet,
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PremiumStatItem(
                          icon: Icons.local_fire_department_rounded,
                          label: 'Seri',
                          value: '$streak',
                          suffix: 'gün',
                          color: const Color(0xFFEF4444),
                          isDark: isDark,
                          isHighlight: streak >= 3,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PremiumStatItem(
                          icon: Icons.emoji_events_rounded,
                          label: 'Puan',
                          value: '${user.engagementScore ?? 0}',
                          color: AppTheme.goldBrandColor,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // İlerleme barı
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Haftalık İlerleme',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.black.withOpacity(0.5),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '${(progressPercentage * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: motivationColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: progressPercentage.clamp(0.0, 1.0),
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    motivationColor,
                                    motivationColor.withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: motivationColor.withOpacity(0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMotivationMessage() {
    if (tests.isEmpty) return 'İlk denemeni ekle';
    if (streak >= 7) return 'Muhteşem performans! 🔥';
    if (streak >= 3) return 'Harika gidiyorsun! 💪';
    if (tests.length >= 20) return 'Süper çalışkansın! 📚';
    if (tests.length >= 10) return 'İyi ilerliyorsun! 🎯';
    return 'Yolculuğuna devam et! 🚀';
  }

  Color _getMotivationColor() {
    if (streak >= 7) return const Color(0xFFEF4444);
    if (streak >= 3) return const Color(0xFFF97316);
    if (tests.length >= 20) return const Color(0xFF8B5CF6);
    if (tests.length >= 10) return const Color(0xFF10B981);
    return AppTheme.primaryBrandColor;
  }

  IconData _getMotivationIcon() {
    if (streak >= 7) return Icons.emoji_events_rounded;
    if (streak >= 3) return Icons.local_fire_department_rounded;
    if (tests.length >= 20) return Icons.military_tech_rounded;
    if (tests.length >= 10) return Icons.trending_up_rounded;
    return Icons.rocket_launch_rounded;
  }

  IconData _getStatusIcon() {
    if (streak >= 7) return Icons.auto_awesome_rounded;
    if (streak >= 3) return Icons.bolt_rounded;
    if (tests.length >= 10) return Icons.star_rounded;
    return Icons.thumb_up_rounded;
  }

  String _getStatusText() {
    if (streak >= 7) return 'ÇOK İYİ';
    if (streak >= 3) return 'GÜZEL';
    if (tests.length >= 10) return 'AKTİF';
    return 'YENİ';
  }

  double _calculateProgress() {
    if (tests.isEmpty) return 0.0;
    // Haftalık hedef: 5 test
    final weeklyGoal = 5;
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekTests = tests.where((t) => t.date.isAfter(weekStart)).length;
    return (weekTests / weeklyGoal).clamp(0.0, 1.0);
  }
}

/// Premium istatistik öğesi
class _PremiumStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? suffix;
  final Color color;
  final bool isDark;
  final bool isHighlight;

  const _PremiumStatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.suffix,
    required this.color,
    required this.isDark,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1E293B) : Colors.white).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlight
              ? color.withOpacity(0.5)
              : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Text(
                    suffix!,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: color.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? Colors.white.withOpacity(0.5)
                  : Colors.black.withOpacity(0.4),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hızlı istatistik rozeti
class _QuickStatBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;
  final bool isHighlight;

  const _QuickStatBadge({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1E293B) : Colors.white).withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlight ? color.withOpacity(0.5) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? Colors.white.withOpacity(0.5)
                      : Colors.black.withOpacity(0.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modern istatistik kartı - Yatay scroll için
class _ModernStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? suffix;
  final Color color;
  final Gradient gradient;
  final bool isDark;
  final bool isSpecial;

  const _ModernStatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.suffix,
    required this.color,
    required this.gradient,
    required this.isDark,
    this.isSpecial = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.12),
            color.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: -1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: color,
                        height: 1,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (suffix != null) ...[
                    const SizedBox(width: 3),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: Text(
                        suffix!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Colors.white.withOpacity(0.6)
                      : Colors.black.withOpacity(0.5),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Akıllı performans grafik sistemi - Kaydırılabilir şık kartlar
class _SmartPerformanceCharts extends StatelessWidget {
  final List<TestModel> tests;
  final bool isDark;
  final String examType;

  const _SmartPerformanceCharts({
    required this.tests,
    required this.isDark,
    required this.examType,
  });

  @override
  Widget build(BuildContext context) {
    final List<_ChartData> chartDataList = [];

    // YKS için TYT ve AYT'yi ayır
    if (examType == 'YKS') {
      final tytTests = tests.where((t) => t.sectionName.toUpperCase() == 'TYT').toList();
      final aytTests = tests.where((t) => t.sectionName.toUpperCase() == 'AYT').toList();

      if (tytTests.isNotEmpty) {
        chartDataList.add(_ChartData(
          tests: tytTests,
          title: 'TYT',
          subtitle: 'Temel Yeterlilik',
          icon: Icons.lightbulb_rounded,
          baseColor: AppTheme.primaryBrandColor,
        ));
      }
      if (aytTests.isNotEmpty) {
        chartDataList.add(_ChartData(
          tests: aytTests,
          title: 'AYT',
          subtitle: 'Alan Yeterlilik',
          icon: Icons.school_rounded,
          baseColor: AppTheme.secondaryBrandColor,
        ));
      }

      // Hiçbiri yoksa tüm testleri göster
      if (chartDataList.isEmpty) {
        chartDataList.add(_ChartData(
          tests: tests,
          title: 'Tüm Testler',
          subtitle: 'Genel Performans',
          icon: Icons.trending_up_rounded,
          baseColor: AppTheme.successBrandColor,
        ));
      }
    } else {
      // Diğer sınavlar için bölümlere göre grupla
      final groupedTests = <String, List<TestModel>>{};
      for (final test in tests) {
        (groupedTests[test.sectionName] ??= []).add(test);
      }

      if (groupedTests.length > 1) {
        final colors = [
          AppTheme.primaryBrandColor,
          AppTheme.secondaryBrandColor,
          AppTheme.successBrandColor,
          Colors.deepOrange,
        ];
        final icons = [
          Icons.menu_book_rounded,
          Icons.science_rounded,
          Icons.calculate_rounded,
          Icons.psychology_rounded,
        ];

        int index = 0;
        for (final entry in groupedTests.entries) {
          chartDataList.add(_ChartData(
            tests: entry.value,
            title: entry.key,
            subtitle: '${entry.value.length} deneme',
            icon: icons[index % icons.length],
            baseColor: colors[index % colors.length],
          ));
          index++;
        }
      } else {
        chartDataList.add(_ChartData(
          tests: tests,
          title: examType,
          subtitle: 'Genel Performans',
          icon: Icons.trending_up_rounded,
          baseColor: AppTheme.successBrandColor,
        ));
      }
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: chartDataList.length,
      itemBuilder: (context, index) {
        final data = chartDataList[index];
        return Padding(
          padding: EdgeInsets.only(right: index < chartDataList.length - 1 ? 10 : 0),
          child: _SwipeablePerformanceCard(
            data: data,
            isDark: isDark,
          ).animate(delay: (200 + index * 50).ms)
            .fadeIn(duration: 250.ms)
            .slideX(begin: 0.1),
        );
      },
    );
  }
}

/// Grafik verisi için model
class _ChartData {
  final List<TestModel> tests;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color baseColor;

  _ChartData({
    required this.tests,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.baseColor,
  });

  // Performans trendini hesapla (son 3 test vs önceki 3 test)
  double get performanceTrend {
    if (tests.length < 2) return 0.0;

    final sortedTests = tests.toList()..sort((a, b) => a.date.compareTo(b.date));
    final halfPoint = (sortedTests.length / 2).floor();

    final firstHalf = sortedTests.take(halfPoint);
    final secondHalf = sortedTests.skip(halfPoint);

    final firstAvg = firstHalf.isEmpty ? 0.0 : firstHalf.fold<double>(0.0, (sum, t) => sum + t.totalNet) / firstHalf.length;
    final secondAvg = secondHalf.isEmpty ? 0.0 : secondHalf.fold<double>(0.0, (sum, t) => sum + t.totalNet) / secondHalf.length;

    return (secondAvg - firstAvg).toDouble();
  }

  // Ortalama net
  double get averageNet {
    if (tests.isEmpty) return 0.0;
    return (tests.fold<double>(0.0, (sum, t) => sum + t.totalNet) / tests.length).toDouble();
  }
}

/// Kaydırılabilir şık performans kartı - Performansa göre dinamik renkler
class _SwipeablePerformanceCard extends StatelessWidget {
  final _ChartData data;
  final bool isDark;

  const _SwipeablePerformanceCard({
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final trend = data.performanceTrend;
    final avgNet = data.averageNet;

    // Trend durumuna göre renk belirle
    Color trendColor;
    Color gradientStart;
    Color gradientEnd;
    IconData trendIcon;
    String trendText;

    if (trend > 5) {
      trendColor = const Color(0xFF10B981); // Yeşil - Harika yükseliş
      gradientStart = const Color(0xFF10B981);
      gradientEnd = const Color(0xFF059669);
      trendIcon = Icons.trending_up_rounded;
      trendText = 'Harika Yükseliş!';
    } else if (trend > 2) {
      trendColor = const Color(0xFF3B82F6); // Mavi - İyi yükseliş
      gradientStart = const Color(0xFF3B82F6);
      gradientEnd = const Color(0xFF2563EB);
      trendIcon = Icons.trending_up_rounded;
      trendText = 'İyi Gidiyor';
    } else if (trend > -2) {
      trendColor = AppTheme.goldBrandColor; // Sarı - Stabil
      gradientStart = AppTheme.goldBrandColor;
      gradientEnd = const Color(0xFFD97706);
      trendIcon = Icons.trending_flat_rounded;
      trendText = 'Stabil';
    } else if (trend > -5) {
      trendColor = const Color(0xFFEF4444); // Kırmızı - Düşüş
      gradientStart = const Color(0xFFEF4444);
      gradientEnd = const Color(0xFFDC2626);
      trendIcon = Icons.trending_down_rounded;
      trendText = 'Dikkat Et';
    } else {
      trendColor = const Color(0xFF991B1B); // Koyu kırmızı - Ciddi düşüş
      gradientStart = const Color(0xFFEF4444);
      gradientEnd = const Color(0xFF991B1B);
      trendIcon = Icons.trending_down_rounded;
      trendText = 'Çalışman Lazım';
    }

    return Container(
      width: MediaQuery.of(context).size.width * 0.80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gradientStart.withOpacity(0.15),
            gradientEnd.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: trendColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: trendColor.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Arka plan deseni - daha küçük
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: trendColor.withOpacity(0.04),
                ),
              ),
            ),
            Positioned(
              left: -15,
              bottom: -15,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: trendColor.withOpacity(0.04),
                ),
              ),
            ),

            // İçerik
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF1E293B) : Colors.white).withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık ve durum
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [gradientStart, gradientEnd],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: trendColor.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(data.icon, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              data.subtitle,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.black.withOpacity(0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: trendColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: trendColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(trendIcon, color: trendColor, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              trendText,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: trendColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Ortalama net bilgisi
                  Row(
                    children: [
                      Text(
                        'Ort. Net: ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white.withOpacity(0.6)
                              : Colors.black.withOpacity(0.5),
                        ),
                      ),
                      Text(
                        avgNet.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: trendColor,
                          height: 1,
                        ),
                      ),
                      const Spacer(),
                      if (trend.abs() > 0.5)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: trendColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '${trend > 0 ? '+' : ''}${trend.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: trendColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Mini grafik
                  Expanded(
                    child: _MiniPerformanceChart(
                      tests: data.tests,
                      color: trendColor,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini performans grafiği
class _MiniPerformanceChart extends StatelessWidget {
  final List<TestModel> tests;
  final Color color;
  final bool isDark;

  const _MiniPerformanceChart({
    required this.tests,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final recentTests = tests.length > _maxRecentTests
        ? (tests.toList()..sort((a, b) => b.date.compareTo(a.date)))
        .take(_maxRecentTests)
        .toList()
        .reversed
        .toList()
        : (tests.toList()..sort((a, b) => a.date.compareTo(b.date)));

    final nets = recentTests.map((t) => t.totalNet).toList();
    if (nets.isEmpty) return const SizedBox.shrink();

    var minNet = nets[0];
    var maxNet = nets[0];
    for (final net in nets) {
      if (net < minNet) minNet = net;
      if (net > maxNet) maxNet = net;
    }

    final minY = (minNet - 5).clamp(0.0, double.infinity).toDouble();
    final maxY = (maxNet + 5).toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 3,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.03),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (maxY - minY) / 3,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white.withOpacity(0.35)
                          : Colors.black.withOpacity(0.35),
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => color.withOpacity(0.9),
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  spot.y.toStringAsFixed(1),
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (int i = 0; i < nets.length; i++)
                FlSpot(i.toDouble(), nets[i])
            ],
            isCurved: true,
            curveSmoothness: 0.4,
            color: color,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: color,
                  strokeWidth: 2.5,
                  strokeColor: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withOpacity(0.3),
                  color.withOpacity(0.05),
                  color.withOpacity(0.0),
                ],
              ),
            ),
            shadow: Shadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gelişmiş Aktivite Kartı - GitHub tarzı ısı haritası
class _EnhancedActivityCard extends StatelessWidget {
  final String userId;
  final bool isDark;
  final List<TestModel> tests;

  const _EnhancedActivityCard({
    required this.userId,
    required this.isDark,
    required this.tests,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, int> dailyTests = {};
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: _daysToShowVisits - 1));

    for (int i = 0; i < _daysToShowVisits; i++) {
      final date = startDate.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      dailyTests[key] = 0;
    }

    for (final test in tests) {
      final testDate = test.date;
      if (testDate.isAfter(startDate.subtract(const Duration(days: 1)))) {
        final key = DateFormat('yyyy-MM-dd').format(testDate);
        if (dailyTests.containsKey(key)) {
          dailyTests[key] = dailyTests[key]! + 1;
        }
      }
    }

    final sortedDates = dailyTests.keys.toList()..sort();
    final activeDays = dailyTests.values.where((count) => count > 0).length;
    final maxStreak = _calculateMaxStreak(dailyTests, sortedDates);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBrandColor.withOpacity(0.08),
            AppTheme.secondaryBrandColor.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
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
                      AppTheme.primaryBrandColor,
                      AppTheme.primaryBrandColor.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBrandColor.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aktivite Haritası',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Son 30 günlük çalışma geçmişin',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white.withOpacity(0.5)
                            : Colors.black.withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.successBrandColor,
                      AppTheme.successBrandColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.successBrandColor.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '$activeDays/${_daysToShowVisits}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildEnhancedActivityGrid(dailyTests, sortedDates),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildLegendItem('Az', AppTheme.primaryBrandColor.withOpacity(0.2)),
                  const SizedBox(width: 8),
                  _buildLegendItem('Orta', AppTheme.primaryBrandColor.withOpacity(0.5)),
                  const SizedBox(width: 8),
                  _buildLegendItem('Çok', AppTheme.primaryBrandColor),
                ],
              ),
              if (maxStreak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.deepOrange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                        color: Colors.deepOrange, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Rekor: $maxStreak gün',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.deepOrange,
                        ),
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

  Widget _buildEnhancedActivityGrid(Map<String, int> dailyTests, List<String> sortedDates) {
    return SizedBox(
      height: 70,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellSize = (constraints.maxWidth / 30).clamp(8.0, 11.0);
          return Wrap(
            spacing: 3,
            runSpacing: 3,
            children: sortedDates.map((dateKey) {
              final count = dailyTests[dateKey] ?? 0;
              return _buildEnhancedActivityCell(count, cellSize);
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedActivityCell(int count, double size) {
    Color color;
    if (count == 0) {
      color = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    } else if (count == 1) {
      color = AppTheme.primaryBrandColor.withOpacity(0.3);
    } else if (count == 2) {
      color = AppTheme.primaryBrandColor.withOpacity(0.6);
    } else {
      color = AppTheme.primaryBrandColor;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        boxShadow: count > 0 ? [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark
                ? Colors.white.withOpacity(0.5)
                : Colors.black.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  int _calculateMaxStreak(Map<String, int> dailyTests, List<String> sortedDates) {
    int maxStreak = 0;
    int currentStreak = 0;

    for (final dateKey in sortedDates) {
      if (dailyTests[dateKey]! > 0) {
        currentStreak++;
        if (currentStreak > maxStreak) maxStreak = currentStreak;
      } else {
        currentStreak = 0;
      }
    }

    return maxStreak;
  }
}

/// Daily activity tracker showing test activity over time
class _DailyActivityCard extends StatelessWidget {
  final String userId;
  final bool isDark;
  final List<TestModel> tests;

  const _DailyActivityCard({
    required this.userId,
    required this.isDark,
    required this.tests,
  });

  @override
  Widget build(BuildContext context) {
    // Group tests by date
    final Map<String, int> dailyTests = {};
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: _daysToShowVisits - 1));

    // Initialize all dates with 0
    for (int i = 0; i < _daysToShowVisits; i++) {
      final date = startDate.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      dailyTests[key] = 0;
    }

    // Count tests per day
    for (final test in tests) {
      final testDate = test.date;
      if (testDate.isAfter(startDate.subtract(const Duration(days: 1)))) {
        final key = DateFormat('yyyy-MM-dd').format(testDate);
        if (dailyTests.containsKey(key)) {
          dailyTests[key] = dailyTests[key]! + 1;
        }
      }
    }

    final sortedDates = dailyTests.keys.toList()..sort();
    final activeDays = dailyTests.values.where((count) => count > 0).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                color: AppTheme.primaryBrandColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Son 30 Gün Aktivite',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successBrandColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$activeDays aktif gün',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.successBrandColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActivityGrid(dailyTests, sortedDates),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Yok', isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              const SizedBox(width: 12),
              _buildLegendItem('1 test', AppTheme.primaryBrandColor.withOpacity(0.3)),
              const SizedBox(width: 12),
              _buildLegendItem('2 test', AppTheme.primaryBrandColor.withOpacity(0.6)),
              const SizedBox(width: 12),
              _buildLegendItem('3+ test', AppTheme.primaryBrandColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityGrid(Map<String, int> dailyVisits, List<String> sortedDates) {
    return SizedBox(
      height: 80,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellSize = (constraints.maxWidth / 30).clamp(8.0, 12.0);

          return Wrap(
            spacing: 3,
            runSpacing: 3,
            children: sortedDates.map((dateKey) {
              final count = dailyVisits[dateKey] ?? 0;
              return _buildActivityCell(count, cellSize);
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildActivityCell(int count, double size) {
    Color color;
    if (count == 0) {
      color = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    } else if (count == 1) {
      color = AppTheme.primaryBrandColor.withOpacity(0.3);
    } else if (count == 2) {
      color = AppTheme.primaryBrandColor.withOpacity(0.6);
    } else {
      color = AppTheme.primaryBrandColor;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark
                ? Colors.white.withOpacity(0.5)
                : Colors.black.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}

/// Gelişmiş Ders Performans Kartı - Görsel çubuk grafikleriyle
class _EnhancedSubjectBreakdown extends StatelessWidget {
  final List<TestModel> tests;
  final bool isDark;

  const _EnhancedSubjectBreakdown({
    required this.tests,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, _SubjectStats> subjectStats = {};

    for (final test in tests) {
      for (final entry in test.scores.entries) {
        final subject = entry.key;
        final scores = entry.value;
        final correct = scores['dogru'] ?? 0;
        final wrong = scores['yanlis'] ?? 0;
        final blank = scores['bos'] ?? 0;

        if (!subjectStats.containsKey(subject)) {
          subjectStats[subject] = _SubjectStats(
            subject: subject,
            totalCorrect: 0,
            totalWrong: 0,
            totalBlank: 0,
          );
        }

        subjectStats[subject]!.totalCorrect += correct;
        subjectStats[subject]!.totalWrong += wrong;
        subjectStats[subject]!.totalBlank += blank;
      }
    }

    final sortedSubjects = subjectStats.values.toList()
      ..sort((a, b) => b.net.compareTo(a.net));

    final topSubjects = sortedSubjects.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.goldBrandColor.withOpacity(0.08),
            AppTheme.successBrandColor.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
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
                      AppTheme.goldBrandColor,
                      AppTheme.goldBrandColor.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.goldBrandColor.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ders Performansı',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'En yüksek net ortalamaları',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white.withOpacity(0.5)
                            : Colors.black.withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...topSubjects.asMap().entries.map((entry) {
            final index = entry.key;
            final stat = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: index < topSubjects.length - 1 ? 10 : 0),
              child: _EnhancedSubjectRow(
                stat: stat,
                isDark: isDark,
                rank: index + 1,
                maxNet: sortedSubjects.first.net,
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Gelişmiş ders satırı - Progress bar ile
class _EnhancedSubjectRow extends StatelessWidget {
  final _SubjectStats stat;
  final bool isDark;
  final int rank;
  final double maxNet;

  const _EnhancedSubjectRow({
    required this.stat,
    required this.isDark,
    required this.rank,
    required this.maxNet,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = maxNet > 0 ? (stat.net / maxNet) : 0.0;
    final color = _getColorForRank(rank);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                stat.subject,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                '${stat.net.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              widthFactor: percentage.clamp(0.0, 1.0),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _MiniStat(
              icon: Icons.check_circle_rounded,
              value: '${stat.totalCorrect}',
              color: const Color(0xFF10B981),
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _MiniStat(
              icon: Icons.cancel_rounded,
              value: '${stat.totalWrong}',
              color: const Color(0xFFEF4444),
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _MiniStat(
              icon: Icons.radio_button_unchecked_rounded,
              value: '${stat.totalBlank}',
              color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
              isDark: isDark,
            ),
            const Spacer(),
            Text(
              '${(stat.accuracy * 100).toStringAsFixed(0)}% doğru',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? Colors.white.withOpacity(0.5)
                    : Colors.black.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getColorForRank(int rank) {
    switch (rank) {
      case 1: return const Color(0xFFF59E0B); // Altın
      case 2: return const Color(0xFF94A3B8); // Gümüş
      case 3: return const Color(0xFFF97316); // Bronz
      default: return AppTheme.primaryBrandColor;
    }
  }
}

/// Mini istatistik göstergesi
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  final bool isDark;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark
                ? Colors.white.withOpacity(0.7)
                : Colors.black.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

/// Motivasyonel Alt Bilgi - Kullanıcıyı teşvik eden mesajlar
class _MotivationalFooter extends StatelessWidget {
  final List<TestModel> tests;
  final int streak;
  final bool isDark;

  const _MotivationalFooter({
    required this.tests,
    required this.streak,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final message = _getFooterMessage();
    final icon = _getFooterIcon();
    final color = _getFooterColor();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white.withOpacity(0.7)
                        : Colors.black.withOpacity(0.6),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({String title, String subtitle}) _getFooterMessage() {
    if (streak >= 7) {
      return (
        title: 'Durmak yok! 🔥',
        subtitle: '$streak günlük serinle harika gidiyorsun. Bu temponu koru!'
      );
    }
    if (streak >= 3) {
      return (
        title: 'Süper gidiyorsun! 💪',
        subtitle: 'Çalışma temponu mükemmel. Böyle devam et!'
      );
    }
    if (tests.length >= 20) {
      return (
        title: 'İnanılmaz çalışkansın! 📚',
        subtitle: '${tests.length} deneme çözdün. Başarı yakın!'
      );
    }
    if (tests.length >= 10) {
      return (
        title: 'Güzel bir ilerleme! 🎯',
        subtitle: 'Çalışmalarına devam et, başarı seni bekliyor!'
      );
    }
    if (tests.isEmpty) {
      return (
        title: 'Hadi başlayalım! 🚀',
        subtitle: 'İlk denemeni ekle ve yolculuğuna başla!'
      );
    }
    return (
      title: 'Doğru yoldasın! ⭐',
      subtitle: 'Her deneme seni hedefe bir adım daha yaklaştırıyor!'
    );
  }

  IconData _getFooterIcon() {
    if (streak >= 7) return Icons.local_fire_department_rounded;
    if (streak >= 3) return Icons.bolt_rounded;
    if (tests.length >= 20) return Icons.emoji_events_rounded;
    if (tests.length >= 10) return Icons.trending_up_rounded;
    if (tests.isEmpty) return Icons.rocket_launch_rounded;
    return Icons.star_rounded;
  }

  Color _getFooterColor() {
    if (streak >= 7) return Colors.deepOrange;
    if (streak >= 3) return const Color(0xFFF97316);
    if (tests.length >= 20) return const Color(0xFF8B5CF6);
    if (tests.length >= 10) return const Color(0xFF10B981);
    if (tests.isEmpty) return AppTheme.primaryBrandColor;
    return AppTheme.goldBrandColor;
  }
}

/// Subject breakdown showing performance by subject
class _SubjectBreakdownCard extends StatelessWidget {
  final List<TestModel> tests;
  final bool isDark;

  const _SubjectBreakdownCard({
    required this.tests,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Aggregate scores by subject across all tests
    final Map<String, _SubjectStats> subjectStats = {};

    for (final test in tests) {
      for (final entry in test.scores.entries) {
        final subject = entry.key;
        final scores = entry.value;
        final correct = scores['dogru'] ?? 0;
        final wrong = scores['yanlis'] ?? 0;
        final blank = scores['bos'] ?? 0;

        if (!subjectStats.containsKey(subject)) {
          subjectStats[subject] = _SubjectStats(
            subject: subject,
            totalCorrect: 0,
            totalWrong: 0,
            totalBlank: 0,
          );
        }

        subjectStats[subject]!.totalCorrect += correct;
        subjectStats[subject]!.totalWrong += wrong;
        subjectStats[subject]!.totalBlank += blank;
      }
    }

    final sortedSubjects = subjectStats.values.toList()
      ..sort((a, b) => b.net.compareTo(a.net));

    // Take top 5 subjects
    final topSubjects = sortedSubjects.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.school_rounded,
                color: AppTheme.goldBrandColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Ders Performansı',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...topSubjects.map((stat) => _SubjectStatRow(
            stat: stat,
            isDark: isDark,
          )),
        ],
      ),
    );
  }
}

class _SubjectStats {
  final String subject;
  int totalCorrect;
  int totalWrong;
  int totalBlank;

  _SubjectStats({
    required this.subject,
    required this.totalCorrect,
    required this.totalWrong,
    required this.totalBlank,
  });

  double get net => totalCorrect - (totalWrong * 0.25);
  int get total => totalCorrect + totalWrong + totalBlank;
  double get accuracy =>
      (totalCorrect + totalWrong) > 0
          ? totalCorrect / (totalCorrect + totalWrong)
          : 0;
}

class _SubjectStatRow extends StatelessWidget {
  final _SubjectStats stat;
  final bool isDark;

  const _SubjectStatRow({
    required this.stat,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  stat.subject,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${stat.net.toStringAsFixed(1)} net',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.successBrandColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stat.accuracy,
              minHeight: 6,
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.successBrandColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'D: ${stat.totalCorrect} • Y: ${stat.totalWrong} • B: ${stat.totalBlank}',
            style: TextStyle(
              fontSize: 10,
              color: isDark
                  ? Colors.white.withOpacity(0.45)
                  : Colors.black.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}


