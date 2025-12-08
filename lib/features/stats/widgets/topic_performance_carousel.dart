// lib/features/stats/widgets/topic_performance_carousel.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/models/performance_summary.dart';
import 'package:taktik/data/providers/firestore_providers.dart';

/// Yatay kaydırılabilir konu performansı kartları
/// Kullanıcının coach screen'den girdiği konu performanslarını gösterir
class TopicPerformanceCarousel extends ConsumerStatefulWidget {
  final bool isDark;

  const TopicPerformanceCarousel({
    super.key,
    required this.isDark,
  });

  @override
  ConsumerState<TopicPerformanceCarousel> createState() => _TopicPerformanceCarouselState();
}

class _TopicPerformanceCarouselState extends ConsumerState<TopicPerformanceCarousel> {
  _FilterType _filterType = _FilterType.best;

  @override
  Widget build(BuildContext context) {
    final performanceAsync = ref.watch(performanceProvider);

    return performanceAsync.when(
      data: (performance) {
        if (performance == null || performance.topicPerformances.isEmpty) {
          return const SizedBox.shrink();
        }

        final topicStats = _calculateTopicStats(performance, _filterType);

        if (topicStats.isEmpty) return const SizedBox.shrink();

        return _buildCarousel(context, topicStats);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCarousel(BuildContext context, List<_TopicStat> topicStats) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.secondaryBrandColor.withOpacity(0.2),
                      AppTheme.primaryBrandColor.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.topic_rounded,
                  color: AppTheme.secondaryBrandColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Konu Performansı',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'İlk 10 ${_filterType == _FilterType.best ? "en iyi" : "en kötü"}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark
                            ? Colors.white.withOpacity(0.5)
                            : Colors.black.withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Filtre butonları
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              _FilterChip(
                label: 'En İyi',
                icon: Icons.trending_up_rounded,
                isSelected: _filterType == _FilterType.best,
                onTap: () => setState(() => _filterType = _FilterType.best),
                isDark: widget.isDark,
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'En Kötü',
                icon: Icons.trending_down_rounded,
                isSelected: _filterType == _FilterType.worst,
                onTap: () => setState(() => _filterType = _FilterType.worst),
                isDark: widget.isDark,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: topicStats.length,
            itemBuilder: (context, index) {
              final stat = topicStats[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _TopicStatCard(
                  stat: stat,
                  isDark: widget.isDark,
                  index: index,
                ),
              );
            },
          ),
        ).animate()
          .fadeIn(duration: 400.ms)
          .slideY(begin: 0.05, curve: Curves.easeOutCubic),
      ],
    );
  }

  List<_TopicStat> _calculateTopicStats(PerformanceSummary performance, _FilterType filterType) {
    final List<_TopicStat> stats = [];

    // Her subject altındaki her topic için stat oluştur
    performance.topicPerformances.forEach((subject, topics) {
      topics.forEach((topicName, topicPerf) {
        final total = topicPerf.questionCount;
        if (total == 0) return; // Hiç soru çözülmemiş ise atla

        final accuracy = total > 0
            ? (topicPerf.correctCount / total * 100)
            : 0.0;

        // Mastery hesapla (doğruluk oranına göre)
        double mastery = 0.0;
        if (topicPerf.questionCount > 0) {
          mastery = (topicPerf.correctCount / topicPerf.questionCount) * 100;
        }

        // İsimleri temizle: "__" -> " ", gereksiz kısımları kaldır
        final cleanTopicName = _cleanTopicName(topicName);
        final cleanSubjectName = _cleanSubjectName(subject);

        stats.add(_TopicStat(
          name: cleanTopicName,
          subject: cleanSubjectName,
          totalCorrect: topicPerf.correctCount,
          totalWrong: topicPerf.wrongCount,
          totalEmpty: topicPerf.blankCount,
          totalQuestions: topicPerf.questionCount,
          accuracy: accuracy,
          mastery: mastery,
        ));
      });
    });

    // Filtreye göre sırala
    if (filterType == _FilterType.best) {
      stats.sort((a, b) => b.accuracy.compareTo(a.accuracy));
    } else {
      stats.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    }

    // İlk 10'u al
    return stats.take(10).toList();
  }

  String _cleanTopicName(String name) {
    // "__" karakterlerini boşluk ile değiştir
    String cleaned = name.replaceAll('__', ' ').replaceAll('_', ' ');

    // Gereksiz kısımları kaldır (örn: " - Genel Yetenek")
    if (cleaned.contains(' - ')) {
      cleaned = cleaned.split(' - ')[0];
    }

    return cleaned.trim();
  }

  String _cleanSubjectName(String name) {
    // "__" karakterlerini boşluk ile değiştir
    String cleaned = name.replaceAll('__', ' ').replaceAll('_', ' ');

    // Gereksiz kısımları kaldır
    if (cleaned.contains(' - ')) {
      cleaned = cleaned.split(' - ')[0];
    }

    return cleaned.trim();
  }
}

class _TopicStatCard extends StatelessWidget {
  final _TopicStat stat;
  final bool isDark;
  final int index;

  const _TopicStatCard({
    required this.stat,
    required this.isDark,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      [const Color(0xFFEC4899), const Color(0xFFF43F5E)],
      [const Color(0xFF10B981), const Color(0xFF059669)],
      [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
      [const Color(0xFF06B6D4), const Color(0xFF3B82F6)],
      [const Color(0xFF8B5CF6), const Color(0xFFEC4899)],
    ];

    final colorPair = colors[index % colors.length];

    return Container(
      width: 180,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorPair[0].withOpacity(isDark ? 0.25 : 0.15),
            colorPair[1].withOpacity(isDark ? 0.15 : 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorPair[0].withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorPair[0].withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Başlık ve konu adı - Sabit yükseklik
            SizedBox(
              height: 52,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat.subject,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colorPair[0].withOpacity(0.8),
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      stat.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Ana metrik - Doğruluk oranı - Sabit yükseklik
            SizedBox(
              height: 38,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${stat.accuracy.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: colorPair[0],
                      height: 1,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'doğruluk',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white.withOpacity(0.5)
                            : Colors.black.withOpacity(0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // İlerleme çubuğu
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stat.accuracy / 100,
                minHeight: 6,
                backgroundColor: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
                valueColor: AlwaysStoppedAnimation(colorPair[0]),
              ),
            ),
            const SizedBox(height: 8),

            // İstatistikler - Sabit yükseklik
            SizedBox(
              height: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MiniStat(
                    icon: Icons.check_circle_rounded,
                    value: stat.totalCorrect.toString(),
                    color: Colors.green,
                    isDark: isDark,
                  ),
                  _MiniStat(
                    icon: Icons.cancel_rounded,
                    value: stat.totalWrong.toString(),
                    color: Colors.red,
                    isDark: isDark,
                  ),
                  _MiniStat(
                    icon: Icons.remove_circle_rounded,
                    value: stat.totalEmpty.toString(),
                    color: Colors.orange,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Toplam soru sayısı ve mastery badge - Sabit yükseklik
            SizedBox(
              height: 28,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorPair[0].withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.quiz_rounded,
                          size: 11,
                          color: colorPair[0],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${stat.totalQuestions} soru',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: colorPair[0],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (stat.mastery >= 80)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.withOpacity(0.3),
                            Colors.orange.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.stars_rounded,
                            size: 10,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Uzman',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
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
        Icon(
          icon,
          size: 12,
          color: color.withOpacity(0.8),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

class _TopicStat {
  final String name;
  final String subject;
  final int totalCorrect;
  final int totalWrong;
  final int totalEmpty;
  final int totalQuestions;
  final double accuracy;
  final double mastery;

  _TopicStat({
    required this.name,
    required this.subject,
    required this.totalCorrect,
    required this.totalWrong,
    required this.totalEmpty,
    required this.totalQuestions,
    required this.accuracy,
    required this.mastery,
  });
}

enum _FilterType { best, worst }

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppTheme.primaryBrandColor.withOpacity(0.2),
                    AppTheme.secondaryBrandColor.withOpacity(0.1),
                  ],
                )
              : null,
          color: !isSelected
              ? (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03))
              : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBrandColor.withOpacity(0.4)
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? AppTheme.primaryBrandColor
                  : (isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.5)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? AppTheme.primaryBrandColor
                    : (isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

