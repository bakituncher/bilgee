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

// Constants
const int _maxRecentTests = 8;
const int _daysToShowVisits = 30;

/// Redesigned General Overview Screen with sector-level education analytics
/// Features: Modern design, comprehensive metrics, interactive charts, elegant UI
class GeneralOverviewScreen extends ConsumerWidget {
  const GeneralOverviewScreen({super.key});

  Future<void> _handleBack(BuildContext context) async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Compact Stats Grid
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
            ),
            delegate: SliverChildListDelegate([
              _CompactStatCard(
                icon: Icons.quiz_rounded,
                label: 'Deneme',
                value: '${user.testCount ?? 0}',
                color: AppTheme.secondaryBrandColor,
                isDark: isDark,
              ).animate().fadeIn(duration: 200.ms).scale(begin: const Offset(0.9, 0.9)),
              _CompactStatCard(
                icon: Icons.trending_up_rounded,
                label: 'Ort. Net',
                value: _calculateAvgNet(user, tests),
                color: AppTheme.successBrandColor,
                isDark: isDark,
              ).animate(delay: 50.ms).fadeIn(duration: 200.ms).scale(begin: const Offset(0.9, 0.9)),
              _CompactStatCard(
                icon: Icons.local_fire_department_rounded,
                label: 'Seri',
                value: '${_calculateStreak(tests)}',
                color: Colors.deepOrange,
                isDark: isDark,
              ).animate(delay: 100.ms).fadeIn(duration: 200.ms).scale(begin: const Offset(0.9, 0.9)),
              _CompactStatCard(
                icon: Icons.star_rounded,
                label: 'Puan',
                value: '${user.engagementScore ?? 0}',
                color: AppTheme.goldBrandColor,
                isDark: isDark,
              ).animate(delay: 150.ms).fadeIn(duration: 200.ms).scale(begin: const Offset(0.9, 0.9)),
            ]),
          ),
        ),

        // Performance Chart Section - Kaydırılabilir şık grafik kartları
        if (tests.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.analytics_rounded,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Performans Analizi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 240,
                  child: _SmartPerformanceCharts(
                    tests: tests,
                    isDark: isDark,
                    examType: user.selectedExam ?? 'YKS',
                  ).animate(delay: 200.ms).fadeIn(duration: 250.ms).slideX(begin: 0.02),
                ),
              ],
            ),
          ),

        // Daily Activity Tracker
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _DailyActivityCard(
              userId: user.id,
              isDark: isDark,
              tests: tests,
            ).animate(delay: 250.ms).fadeIn(duration: 250.ms).slideY(begin: 0.02),
          ),
        ),

        // Subject Performance Breakdown
        if (tests.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _SubjectBreakdownCard(
                tests: tests,
                isDark: isDark,
              ).animate(delay: 300.ms).fadeIn(duration: 250.ms).slideY(begin: 0.02),
            ),
          ),

        // Bottom spacing
        const SliverToBoxAdapter(
          child: SizedBox(height: 24),
        ),
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

/// Compact stat card for key metrics
class _CompactStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _CompactStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: chartDataList.length,
      itemBuilder: (context, index) {
        final data = chartDataList[index];
        return Padding(
          padding: EdgeInsets.only(right: index < chartDataList.length - 1 ? 12 : 0),
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
      width: MediaQuery.of(context).size.width * 0.85,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gradientStart.withOpacity(0.15),
            gradientEnd.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: trendColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: trendColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Arka plan deseni
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: trendColor.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: trendColor.withOpacity(0.05),
                ),
              ),
            ),

            // İçerik
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF1E293B) : Colors.white).withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık ve durum
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [gradientStart, gradientEnd],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: trendColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(data.icon, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              data.subtitle,
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
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: trendColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: trendColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(trendIcon, color: trendColor, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              trendText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: trendColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Ortalama net bilgisi
                  Row(
                    children: [
                      Text(
                        'Ort. Net: ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white.withOpacity(0.6)
                              : Colors.black.withOpacity(0.5),
                        ),
                      ),
                      Text(
                        avgNet.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: trendColor,
                          height: 1,
                        ),
                      ),
                      const Spacer(),
                      if (trend.abs() > 0.5)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: trendColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${trend > 0 ? '+' : ''}${trend.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: trendColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

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


