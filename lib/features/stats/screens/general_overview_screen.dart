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
const int _maxRecentTests = 10;
const int _maxWeeklyTasksDisplay = 10; // Maximum tasks to display per day for chart scaling

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
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: (now.weekday - 1)));
    final weekTasksAsync = ref.watch(completedTasksForWeekProvider(weekStart));

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Hero Stats Header
        SliverToBoxAdapter(
          child: _HeroStatsHeader(
            user: user,
            tests: tests,
            isDark: isDark,
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.02),
        ),

        // Key Performance Indicators
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            delegate: SliverChildListDelegate([
              _KPICard(
                icon: Icons.assignment_turned_in_rounded,
                title: 'Toplam Deneme',
                value: '${user.testCount}',
                subtitle: 'Çözülen test',
                color: AppTheme.secondaryBrandColor,
                isDark: isDark,
              ).animate(delay: 100.ms).fadeIn(duration: 250.ms).scale(begin: const Offset(0.8, 0.8)),
              _KPICard(
                icon: Icons.trending_up_rounded,
                title: 'Ortalama Net',
                value: _calculateAvgNet(user, tests),
                subtitle: 'Genel ortalama',
                color: AppTheme.successBrandColor,
                isDark: isDark,
              ).animate(delay: 150.ms).fadeIn(duration: 250.ms).scale(begin: const Offset(0.8, 0.8)),
              _KPICard(
                icon: Icons.local_fire_department_rounded,
                title: 'Seri',
                value: '${user.streak ?? 0}',
                subtitle: 'Gün üst üste',
                color: Colors.deepOrange,
                isDark: isDark,
              ).animate(delay: 200.ms).fadeIn(duration: 250.ms).scale(begin: const Offset(0.8, 0.8)),
              _KPICard(
                icon: Icons.military_tech_rounded,
                title: 'Puan',
                value: '${user.engagementScore ?? 0}',
                subtitle: 'Bağlılık puanı',
                color: AppTheme.goldBrandColor,
                isDark: isDark,
              ).animate(delay: 250.ms).fadeIn(duration: 250.ms).scale(begin: const Offset(0.8, 0.8)),
            ]),
          ),
        ),

        // Performance Chart Section
        if (tests.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _PerformanceChart(
                tests: tests,
                isDark: isDark,
              ).animate(delay: 300.ms).fadeIn(duration: 300.ms).slideY(begin: 0.03),
            ),
          ),

        // Weekly Activity Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: weekTasksAsync.when(
              data: (map) => _WeeklyActivityCard(
                weekStart: weekStart,
                data: map,
                isDark: isDark,
              ).animate(delay: 350.ms).fadeIn(duration: 300.ms).slideY(begin: 0.03),
              loading: () => const SizedBox(height: 200, child: LogoLoader()),
              error: (e, s) => const SizedBox.shrink(),
            ),
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
              ).animate(delay: 400.ms).fadeIn(duration: 300.ms).slideY(begin: 0.03),
            ),
          ),

        // Recent Activity & Insights
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _RecentInsightsCard(
              user: user,
              tests: tests,
              isDark: isDark,
            ).animate(delay: 450.ms).fadeIn(duration: 300.ms).slideY(begin: 0.03),
          ),
        ),

        // Monthly Stats
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: _MonthlyStatsCard(
              userId: user.id,
              isDark: isDark,
            ).animate(delay: 500.ms).fadeIn(duration: 300.ms).slideY(begin: 0.03),
          ),
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
}

/// Hero header showing primary stats in an attractive layout
class _HeroStatsHeader extends StatelessWidget {
  final UserModel user;
  final List<TestModel> tests;
  final bool isDark;

  const _HeroStatsHeader({
    required this.user,
    required this.tests,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final testCount = user.testCount ?? tests.length;
    final totalNet = user.totalNetSum ?? 
        tests.fold<double>(0, (sum, t) => sum + t.totalNet);
    final avgNet = testCount > 0 ? (totalNet / testCount) : 0.0;

    DateTime? lastDate;
    double? lastNet;
    if (tests.isNotEmpty) {
      final sorted = [...tests]..sort((a, b) => b.date.compareTo(a.date));
      lastDate = sorted.first.date;
      lastNet = sorted.first.totalNet;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppTheme.secondaryBrandColor.withOpacity(0.2),
                  AppTheme.primaryBrandColor.withOpacity(0.4),
                ]
              : [
                  AppTheme.secondaryBrandColor.withOpacity(0.1),
                  Colors.white,
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryBrandColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  color: AppTheme.secondaryBrandColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performans Özeti',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastDate != null 
                          ? 'Son güncelleme: ${_humanize(lastDate)}'
                          : 'Henüz test girilmemiş',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _HeroStatItem(
                  label: 'Ortalama Net',
                  value: avgNet.toStringAsFixed(1),
                  isDark: isDark,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1),
              ),
              Expanded(
                child: _HeroStatItem(
                  label: 'Son Net',
                  value: lastNet?.toStringAsFixed(1) ?? '—',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _humanize(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 0) return '${diff.inDays}g önce';
    if (diff.inHours > 0) return '${diff.inHours}s önce';
    final m = diff.inMinutes;
    return m <= 1 ? 'az önce' : '${m}dk önce';
  }
}

class _HeroStatItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _HeroStatItem({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark
                ? Colors.white.withOpacity(0.6)
                : Colors.black.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}

/// KPI Card showing individual metrics
class _KPICard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final bool isDark;

  const _KPICard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? Colors.white.withOpacity(0.5)
                      : Colors.black.withOpacity(0.4),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Performance chart showing test score trends
class _PerformanceChart extends StatelessWidget {
  final List<TestModel> tests;
  final bool isDark;

  const _PerformanceChart({
    required this.tests,
    required this.isDark,
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

    // Calculate min and max in a single pass
    var minNet = nets[0];
    var maxNet = nets[0];
    for (final net in nets) {
      if (net < minNet) minNet = net;
      if (net > maxNet) maxNet = net;
    }
    
    final minY = (minNet - 5).clamp(0, double.infinity);
    final maxY = maxNet + 5;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Net Performans Trendi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.white.withOpacity(0.5)
                                : Colors.black.withOpacity(0.5),
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
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
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
                          AppTheme.successBrandColor.withOpacity(0.3),
                          AppTheme.successBrandColor.withOpacity(0.05),
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

/// Weekly activity card showing task completion by day
class _WeeklyActivityCard extends StatelessWidget {
  final DateTime weekStart;
  final Map<String, List<String>> data;
  final bool isDark;

  const _WeeklyActivityCard({
    required this.weekStart,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final days = List<DateTime>.generate(
      7,
      (i) => weekStart.add(Duration(days: i)),
    );
    final counts = days.map((d) {
      final key =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return (data[key]?.length ?? 0).toDouble();
    }).toList();
    // Cap maximum display at _maxWeeklyTasksDisplay for better chart scaling
    final maxY = (counts.isEmpty ? 1 : counts.reduce((a, b) => a > b ? a : b))
        .clamp(1, _maxWeeklyTasksDisplay.toDouble())
        .toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
                Icons.calendar_month_rounded,
                color: AppTheme.secondaryBrandColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Haftalık Aktivite',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 3,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= days.length) {
                          return const SizedBox.shrink();
                        }
                        const labels = [
                          'Pzt',
                          'Sal',
                          'Çar',
                          'Per',
                          'Cum',
                          'Cmt',
                          'Paz'
                        ];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.black.withOpacity(0.5),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (int i = 0; i < counts.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: counts[i],
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppTheme.secondaryBrandColor.withOpacity(0.6),
                              AppTheme.secondaryBrandColor,
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
                maxY: maxY,
              ),
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Ders Bazında Performans',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
      padding: const EdgeInsets.only(bottom: 12),
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
              minHeight: 8,
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.successBrandColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Doğru: ${stat.totalCorrect} • Yanlış: ${stat.totalWrong} • Boş: ${stat.totalBlank}',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? Colors.white.withOpacity(0.5)
                  : Colors.black.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent insights showing latest achievements and trends
class _RecentInsightsCard extends StatelessWidget {
  final UserModel user;
  final List<TestModel> tests;
  final bool isDark;

  const _RecentInsightsCard({
    required this.user,
    required this.tests,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final insights = _generateInsights();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
                Icons.lightbulb_rounded,
                color: Colors.amber,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Öne Çıkan Bilgiler',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...insights.map((insight) => _InsightItem(
                icon: insight['icon'] as IconData,
                text: insight['text'] as String,
                isDark: isDark,
              )),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _generateInsights() {
    final insights = <Map<String, dynamic>>[];

    // Streak insight
    final streak = user.streak ?? 0;
    if (streak > 0) {
      insights.add({
        'icon': Icons.local_fire_department_rounded,
        'text': '$streak gün üst üste aktif! Harika bir çaba. 🔥',
      });
    }

    // Test count insight
    final testCount = tests.length;
    if (testCount > 0) {
      insights.add({
        'icon': Icons.quiz_rounded,
        'text': 'Toplam $testCount deneme çözdün. Her deneme bir adım!',
      });
    }

    // Recent improvement - sort once and reuse
    if (tests.length >= 3) {
      final sortedTests = tests.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      final last3 = sortedTests.take(3).toList();
      final avgRecent = last3.fold<double>(0, (sum, t) => sum + t.totalNet) / 3;
      final avgAll = tests.fold<double>(0, (sum, t) => sum + t.totalNet) / tests.length;

      if (avgRecent > avgAll) {
        insights.add({
          'icon': Icons.trending_up_rounded,
          'text': 'Son performansın ortalamanın üstünde! Yükseliştesin. 📈',
        });
      }
    }

    // Engagement score
    final engagementScore = user.engagementScore ?? 0;
    if (engagementScore > 50) {
      insights.add({
        'icon': Icons.star_rounded,
        'text': 'Bağlılık puanın $engagementScore. Mükemmel katılım! ⭐',
      });
    }

    // Default insights if none
    if (insights.isEmpty) {
      insights.add({
        'icon': Icons.rocket_launch_rounded,
        'text': 'Yeni yolculuğuna hoş geldin! İlk testini çöz ve gelişimini izle.',
      });
    }

    return insights;
  }
}

class _InsightItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;

  const _InsightItem({
    required this.icon,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.secondaryBrandColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppTheme.secondaryBrandColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? Colors.white.withOpacity(0.8)
                    : Colors.black.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Monthly stats showing visit count
class _MonthlyStatsCard extends ConsumerWidget {
  final String userId;
  final bool isDark;

  const _MonthlyStatsCard({
    required this.userId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref
          .read(firestoreServiceProvider)
          .getVisitsForMonth(userId, DateTime.now()),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 100, child: LogoLoader());
        }
        if (snap.hasError) {
          return const SizedBox.shrink();
        }

        final visits = (snap.data ?? const <Timestamp>[]) as List;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      AppTheme.goldBrandColor.withOpacity(0.2),
                      AppTheme.primaryBrandColor.withOpacity(0.4),
                    ]
                  : [
                      AppTheme.goldBrandColor.withOpacity(0.1),
                      Colors.white,
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.goldBrandColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  color: AppTheme.goldBrandColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${visits.length}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bu Ay Ziyaret',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.trending_up_rounded,
                color: AppTheme.goldBrandColor,
                size: 28,
              ),
            ],
          ),
        );
      },
    );
  }
}


