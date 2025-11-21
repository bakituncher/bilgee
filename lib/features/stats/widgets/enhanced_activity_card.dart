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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E293B),
                  const Color(0xFF0F172A),
                ]
              : [
                  Colors.white,
                  const Color(0xFFFAFAFA),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : AppTheme.primaryBrandColor.withOpacity(0.08),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryBrandColor,
                      AppTheme.secondaryBrandColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBrandColor.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.grid_4x4_rounded,
                  color: Colors.white,
                  size: 18,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Son 30 günlük çalışma ritmin',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppTheme.successBrandColor,
                      Color(0xFF10B981),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.successBrandColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$activeDays/$daysToShowVisits',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEnhancedActivityGrid(dailyTests, sortedDates),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildLegendItem('Az', AppTheme.successBrandColor.withOpacity(isDark ? 0.35 : 0.3)),
                  const SizedBox(width: 6),
                  _buildLegendItem('Orta', AppTheme.successBrandColor.withOpacity(isDark ? 0.65 : 0.6)),
                  const SizedBox(width: 6),
                  _buildLegendItem('Çok', AppTheme.successBrandColor),
                ],
              ),
              if (maxStreak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.deepOrange.withOpacity(0.2),
                        Colors.deepOrange.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.deepOrange.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                        color: Colors.deepOrange, size: 16),
                      const SizedBox(width: 5),
                      Text(
                        '$maxStreak gün',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.deepOrange.shade300 : Colors.deepOrange.shade700,
                          letterSpacing: 0.3,
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
      height: 80,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellSize = (constraints.maxWidth / 30).clamp(9.0, 12.0);
          return Wrap(
            spacing: 4,
            runSpacing: 4,
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
      color = isDark
          ? const Color(0xFF334155).withOpacity(0.5)
          : const Color(0xFFE2E8F0);
    } else if (count == 1) {
      color = isDark
          ? AppTheme.successBrandColor.withOpacity(0.35)
          : AppTheme.successBrandColor.withOpacity(0.3);
    } else if (count == 2) {
      color = isDark
          ? AppTheme.successBrandColor.withOpacity(0.65)
          : AppTheme.successBrandColor.withOpacity(0.6);
    } else {
      color = isDark
          ? AppTheme.successBrandColor
          : AppTheme.successBrandColor;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: count > 0 && isDark
            ? Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 0.5,
              )
            : null,
        boxShadow: count > 0 ? [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.5 : 0.3),
            blurRadius: count > 2 ? 6 : 3,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withOpacity(0.7)
                  : Colors.black.withOpacity(0.6),
            ),
          ),
        ],
      ),
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

