// lib/features/home/widgets/dashboard_stats_overview.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/stats/utils/stats_calculator.dart';

/// Dashboard için kompakt istatistik özet kartı
class DashboardStatsOverview extends ConsumerWidget {
  const DashboardStatsOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final testsAsync = ref.watch(testsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        final tests = testsAsync.valueOrNull ?? [];

        // Genel bakış istatistikleri branş denemelerinden etkilenmesin.
        // Bu kart, sadece ana sınav denemeleri (TYT/AYT/LGS/KPSS/AGS/YDT) üzerinden hesap yapar.
        final mainExamTests = tests.where((t) => !t.isBranchTest).toList();

        // MERKEZİ SİSTEM: Streak Firebase'den alınır, hesaplanmaz
        final streak = StatsCalculator.getStreak(user);
        final avgNet = StatsCalculator.calculateAvgNet(user, mainExamTests);
        final motivationColor = _getMotivationColor(streak, mainExamTests.length);

        // Basit hesaplamalar - test yoksa 0 değerleri
        final lastTestNet = mainExamTests.isEmpty ? 0.0 : (() {
          final sortedTests = [...mainExamTests]..sort((a, b) => b.date.compareTo(a.date));
          return sortedTests.first.totalNet;
        })();
        final bestNet = mainExamTests.isEmpty
            ? 0.0
            : mainExamTests.map((e) => e.totalNet).reduce((a, b) => a > b ? a : b);

        return GestureDetector(
          onTap: () => context.push('/stats/overview'),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: motivationColor.withOpacity(0.25),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: motivationColor.withOpacity(isDark ? 0.15 : 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            motivationColor.withOpacity(0.2),
                            motivationColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.insights_rounded,
                        color: motivationColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Genel Bakış',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                      size: 18,
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Ana İstatistikler - 4 sütun
                Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        icon: Icons.assignment_turned_in_rounded,
                        label: 'Deneme',
                        value: '${mainExamTests.length}',
                        color: const Color(0xFF8B5CF6),
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.trending_up_rounded,
                        label: 'Ortalama',
                        value: avgNet,
                        color: const Color(0xFF10B981),
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.emoji_events_rounded,
                        label: 'En İyi',
                        value: bestNet.toStringAsFixed(1),
                        color: const Color(0xFFFFA726),
                        theme: theme,
                        isHighlight: bestNet >= 80,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.access_time_rounded,
                        label: 'Son',
                        value: lastTestNet.toStringAsFixed(1),
                        color: const Color(0xFF3B82F6),
                        theme: theme,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Color _getMotivationColor(int streak, int testCount) {
    if (streak >= 7) return const Color(0xFFEF4444);
    if (streak >= 3) return const Color(0xFFF97316);
    if (testCount >= 20) return const Color(0xFF8B5CF6);
    if (testCount >= 10) return const Color(0xFF10B981);
    return const Color(0xFF3B82F6);
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? suffix;
  final Color color;
  final ThemeData theme;
  final bool isHighlight;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.suffix,
    required this.color,
    required this.theme,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(isHighlight ? 0.25 : 0.12),
          width: isHighlight ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 14,
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 1),
                Text(
                  suffix!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                    fontSize: 8,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w600,
              fontSize: 8.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
