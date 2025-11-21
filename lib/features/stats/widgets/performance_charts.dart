// lib/features/stats/widgets/performance_charts.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/features/stats/models/chart_data.dart';
import 'package:taktik/features/stats/widgets/swipeable_performance_card.dart';

/// Akıllı performans grafik sistemi - Kaydırılabilir şık kartlar
class SmartPerformanceCharts extends StatelessWidget {
  final List<TestModel> tests;
  final bool isDark;
  final String examType;

  const SmartPerformanceCharts({
    super.key,
    required this.tests,
    required this.isDark,
    required this.examType,
  });

  @override
  Widget build(BuildContext context) {
    final List<ChartData> chartDataList = [];

    // YKS için TYT ve AYT'yi ayır
    if (examType == 'YKS') {
      final tytTests = tests.where((t) => t.sectionName.toUpperCase() == 'TYT').toList();
      final aytTests = tests.where((t) => t.sectionName.toUpperCase() == 'AYT').toList();

      if (tytTests.isNotEmpty) {
        chartDataList.add(ChartData(
          tests: tytTests,
          title: 'TYT',
          subtitle: 'Temel Yeterlilik',
          icon: Icons.lightbulb_rounded,
          baseColor: AppTheme.primaryBrandColor,
        ));
      }
      if (aytTests.isNotEmpty) {
        chartDataList.add(ChartData(
          tests: aytTests,
          title: 'AYT',
          subtitle: 'Alan Yeterlilik',
          icon: Icons.school_rounded,
          baseColor: AppTheme.secondaryBrandColor,
        ));
      }

      // Hiçbiri yoksa tüm testleri göster
      if (chartDataList.isEmpty) {
        chartDataList.add(ChartData(
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
          chartDataList.add(ChartData(
            tests: entry.value,
            title: entry.key,
            subtitle: '${entry.value.length} deneme',
            icon: icons[index % icons.length],
            baseColor: colors[index % colors.length],
          ));
          index++;
        }
      } else {
        chartDataList.add(ChartData(
          tests: tests,
          title: examType.toUpperCase(),
          subtitle: 'Genel Performans',
          icon: Icons.trending_up_rounded,
          baseColor: AppTheme.successBrandColor,
        ));
      }
    }

    return SizedBox(
      height: 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chartDataList.length,
        itemBuilder: (context, index) {
          final data = chartDataList[index];
          return Padding(
            padding: EdgeInsets.only(right: index < chartDataList.length - 1 ? 16 : 0),
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 32,
              child: SwipeablePerformanceCard(
                data: data,
                isDark: isDark,
              ).animate(delay: (200 + index * 50).ms)
                .fadeIn(duration: 250.ms)
                .slideX(begin: 0.1),
            ),
          );
        },
      ),
    );
  }
}

