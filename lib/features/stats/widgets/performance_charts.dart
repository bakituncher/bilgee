// lib/features/stats/widgets/performance_charts.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/features/stats/models/chart_data.dart';
import 'package:taktik/features/stats/widgets/swipeable_performance_card.dart';

/// Akıllı performans grafik sistemi - Kaydırılabilir şık kartlar
class SmartPerformanceCharts extends StatefulWidget {
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
  State<SmartPerformanceCharts> createState() => _SmartPerformanceChartsState();
}

class _SmartPerformanceChartsState extends State<SmartPerformanceCharts> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final tests = widget.tests;
    final examType = widget.examType;
    final List<ChartData> chartDataList = [];

    // Branş denemeleri için
    if (examType == 'BRANCH') {
      final groupedTests = <String, List<TestModel>>{};
      for (final test in tests) {
        (groupedTests[test.smartDisplayName] ??= []).add(test);
      }

      final colors = [
        const Color(0xFFF59E0B), // Amber
        const Color(0xFFEF4444), // Red
        const Color(0xFF8B5CF6), // Purple
        const Color(0xFF06B6D4), // Cyan
        const Color(0xFFEC4899), // Pink
        const Color(0xFF10B981), // Emerald
      ];
      final icons = [
        Icons.menu_book_rounded,
        Icons.science_rounded,
        Icons.calculate_rounded,
        Icons.language_rounded,
        Icons.public_rounded,
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
    }
    // YKS için TYT, AYT ve YDT ayrıştırması
    else if (examType == 'YKS') {
      final tytTests = tests.where((t) => t.sectionName.toUpperCase() == 'TYT').toList();
      final aytTests = tests.where((t) => t.sectionName.toUpperCase().startsWith('AYT')).toList();

      // --- DÜZELTME: YDT (Yabancı Dil) Denemelerini Yakala ---
      final ydtTests = tests.where((t) {
        final name = t.sectionName.toUpperCase();
        return name == 'YDT' || name == 'YABANCI DIL' || name == 'YABANCI DİL';
      }).toList();

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
      // --- DÜZELTME: YDT Grafiğini Ekle ---
      if (ydtTests.isNotEmpty) {
        chartDataList.add(ChartData(
          tests: ydtTests,
          title: 'YDT',
          subtitle: 'Yabancı Dil',
          icon: Icons.language_rounded,
          baseColor: const Color(0xFF06B6D4), // Cyan/Turkuaz
        ));
      }

      // Hiçbiri yoksa tüm testleri göster (Fallback)
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
      // Diğer sınavlar için (AGS, KPSS vb.) bölümlere göre grupla
      final groupedTests = <String, List<TestModel>>{};
      for (final test in tests) {
        (groupedTests[test.smartDisplayName] ??= []).add(test);
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
        // Tek bir grup varsa (Örn: Sadece KPSS veya AGS denemeleri var)
        final title = tests.isNotEmpty ? tests.first.smartDisplayName : examType;

        String displayTitle = title;

        // Eğer akıllı isim, normal bölüm ismiyle aynıysa (yani ana denemeyse)
        if (tests.isNotEmpty && title == tests.first.sectionName) {
          displayTitle = tests.first.examType.displayName;
        } else if (tests.isEmpty) {
          // Liste boşsa ve string olarak geldiyse, enum'dan kurtarmayı dene
          try {
            displayTitle = ExamType.values.byName(examType).displayName;
          } catch (_) {
            displayTitle = examType.toUpperCase();
          }
        }

        chartDataList.add(ChartData(
          tests: tests,
          title: displayTitle,
          subtitle: 'Genel Performansın',
          icon: Icons.trending_up_rounded,
          baseColor: AppTheme.successBrandColor,
        ));
      }
    }

    // Birden fazla grafik varsa kaydırma göstergesi göster
    final showIndicator = chartDataList.length > 1;

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: chartDataList.length,
            itemBuilder: (context, index) {
              final data = chartDataList[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SwipeablePerformanceCard(
                  data: data,
                  isDark: isDark,
                ).animate(delay: (200 + index * 50).ms)
                    .fadeIn(duration: 250.ms)
                    .slideX(begin: 0.1),
              );
            },
          ),
        ),
        // Şık kaydırma göstergesi
        if (showIndicator)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Sol ok göstergesi
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _currentPage > 0 ? 0.6 : 0.0,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 16,
                    color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.3),
                  ),
                ),
                const SizedBox(width: 4),
                // Dot göstergeleri
                ...List.generate(chartDataList.length, (index) {
                  final isActive = index == _currentPage;
                  final data = chartDataList[index];
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 6,
                    width: isActive ? 24 : 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: isActive
                          ? LinearGradient(
                        colors: [
                          data.baseColor,
                          data.baseColor.withOpacity(0.7),
                        ],
                      )
                          : null,
                      color: isActive
                          ? null
                          : isDark
                          ? Colors.white.withOpacity(0.2)
                          : Colors.black.withOpacity(0.15),
                      boxShadow: isActive
                          ? [
                        BoxShadow(
                          color: data.baseColor.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                          : null,
                    ),
                  );
                }),
                const SizedBox(width: 4),
                // Sağ ok göstergesi
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _currentPage < chartDataList.length - 1 ? 0.6 : 0.0,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}