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

        // Performance Chart Section - YKS için TYT ve AYT ayrı
        if (tests.isNotEmpty && user.selectedExam == 'YKS')
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _YKSPerformanceCharts(
                tests: tests,
                isDark: isDark,
              ).animate(delay: 200.ms).fadeIn(duration: 250.ms).slideY(begin: 0.02),
            ),
          ),

        // Performance Chart Section - Diğer sınavlar için tek grafik
        if (tests.isNotEmpty && user.selectedExam != 'YKS')
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _PerformanceChart(
                tests: tests,
                isDark: isDark,
                title: 'Performans Trendi',
              ).animate(delay: 200.ms).fadeIn(duration: 250.ms).slideY(begin: 0.02),
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

/// YKS için TYT ve AYT performans grafiklerini ayrı gösteren widget
class _YKSPerformanceCharts extends StatelessWidget {
  final List<TestModel> tests;
  final bool isDark;

  const _YKSPerformanceCharts({
    required this.tests,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // TYT ve AYT testlerini ayır
    final tytTests = tests.where((t) => t.sectionName == 'TYT').toList();
    final aytTests = tests.where((t) => t.sectionName == 'AYT').toList();

    return Column(
      children: [
        // TYT Grafiği
        if (tytTests.isNotEmpty)
          _PerformanceChart(
            tests: tytTests,
            isDark: isDark,
            title: 'TYT Performans Trendi',
          ),

        // Boşluk
        if (tytTests.isNotEmpty && aytTests.isNotEmpty)
          const SizedBox(height: 12),

        // AYT Grafiği
        if (aytTests.isNotEmpty)
          _PerformanceChart(
            tests: aytTests,
            isDark: isDark,
            title: 'AYT Performans Trendi',
          ),
      ],
    );
  }
}

/// Performance chart showing test score trends
class _PerformanceChart extends StatelessWidget {
  final List<TestModel> tests;
  final bool isDark;
  final String title;

  const _PerformanceChart({
    required this.tests,
    required this.isDark,
    this.title = 'Performans Trendi',
  });

  @override
  Widget build(BuildContext context) {
    // Take last N tests and sort chronologically
    final recentTests = tests.length > _maxRecentTests
        ? (tests.toList()..sort((a, b) => b.date.compareTo(a.date)))
        .take(_maxRecentTests)
        .toList()
        .reversed
        .toList()
        : (tests.toList()..sort((a, b) => a.date.compareTo(b.date)));

    final nets = recentTests.map((t) => t.totalNet).toList();
    if (nets.isEmpty) return const SizedBox.shrink();

    // Calculate min and max
    var minNet = nets[0];
    var maxNet = nets[0];
    for (final net in nets) {
      if (net < minNet) minNet = net;
      if (net > maxNet) maxNet = net;
    }

    final minY = (minNet - 5).clamp(0.0, double.infinity).toDouble();
    final maxY = (maxNet + 5).toDouble();

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
                Icons.show_chart_rounded,
                color: AppTheme.successBrandColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark
                          ? Colors.white.withOpacity(0.04)
                          : Colors.black.withOpacity(0.04),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white.withOpacity(0.4)
                                  : Colors.black.withOpacity(0.4),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (int i = 0; i < nets.length; i++)
                        FlSpot(i.toDouble(), nets[i])
                    ],
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppTheme.successBrandColor,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3.5,
                          color: AppTheme.successBrandColor,
                          strokeWidth: 2,
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
                          AppTheme.successBrandColor.withOpacity(0.25),
                          AppTheme.successBrandColor.withOpacity(0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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


