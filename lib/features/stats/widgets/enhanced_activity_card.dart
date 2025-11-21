// lib/features/stats/widgets/enhanced_activity_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/models/test_model.dart';

const int daysToShowVisits = 30;

/// Gelişmiş Aktivite Kartı - GitHub tarzı ısı haritası
class EnhancedActivityCard extends StatelessWidget {
  final String userId;
  final bool isDark;
  final List<TestModel> tests;

  const EnhancedActivityCard({
    super.key,
    required this.userId,
    required this.isDark,
    required this.tests,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, int> dailyTests = {};
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: daysToShowVisits - 1));

    for (int i = 0; i < daysToShowVisits; i++) {
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
                  '$activeDays/$daysToShowVisits',
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

