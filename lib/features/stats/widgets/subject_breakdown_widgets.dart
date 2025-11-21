// lib/features/stats/widgets/subject_breakdown_widgets.dart
import 'package:flutter/material.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/features/stats/models/subject_stats.dart';
import 'package:taktik/features/stats/widgets/mini_stat.dart';

/// Gelişmiş Ders Performans Kartı - Görsel çubuk grafikleriyle
class EnhancedSubjectBreakdown extends StatelessWidget {
  final List<TestModel> tests;
  final bool isDark;

  const EnhancedSubjectBreakdown({
    super.key,
    required this.tests,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, SubjectStats> subjectStats = {};

    for (final test in tests) {
      for (final entry in test.scores.entries) {
        final subject = entry.key;
        final scores = entry.value;
        final correct = scores['dogru'] ?? 0;
        final wrong = scores['yanlis'] ?? 0;
        final blank = scores['bos'] ?? 0;

        if (!subjectStats.containsKey(subject)) {
          subjectStats[subject] = SubjectStats(
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
              child: EnhancedSubjectRow(
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
class EnhancedSubjectRow extends StatelessWidget {
  final SubjectStats stat;
  final bool isDark;
  final int rank;
  final double maxNet;

  const EnhancedSubjectRow({
    super.key,
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
            MiniStat(
              icon: Icons.check_circle_rounded,
              value: '${stat.totalCorrect}',
              color: const Color(0xFF10B981),
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            MiniStat(
              icon: Icons.cancel_rounded,
              value: '${stat.totalWrong}',
              color: const Color(0xFFEF4444),
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            MiniStat(
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

