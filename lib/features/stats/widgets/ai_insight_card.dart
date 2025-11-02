// lib/features/stats/widgets/ai_insight_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/features/stats/logic/stats_analysis.dart';

class AiInsightCard extends StatelessWidget {
  final StatsAnalysis analysis;
  const AiInsightCard({required this.analysis, super.key});

  @override
  Widget build(BuildContext context) {
    if (analysis.tacticalAdvice.isEmpty) {
      return _buildEmptyState(context);
    }

    // En önemli 3 öneriyi al
    final prioritizedAdvice = _prioritizeAdvice(analysis.tacticalAdvice);
    final topAdvice = prioritizedAdvice.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).cardColor,
            Theme.of(context).cardColor.withOpacity(0.96),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.28),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.secondary.withOpacity(0.18),
                  Theme.of(context).colorScheme.secondary.withOpacity(0.06),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.secondary,
                        Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.psychology_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Taktiksel Analiz',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'En önemli ${topAdvice.length} öneri',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.speed,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Akıllı',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content - Vertical scrollable list
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: topAdvice.asMap().entries.map((entry) {
                final index = entry.key;
                final advice = entry.value;
                final isLast = index == topAdvice.length - 1;

                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          advice.color.withOpacity(0.08),
                          advice.color.withOpacity(0.03),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: advice.color.withOpacity(0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: advice.color.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: advice.color.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: advice.color.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            advice.icon,
                            color: advice.color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            advice.text,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              height: 1.6,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: (index * 80).ms, duration: 350.ms).slideX(begin: 0.08, end: 0),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<TacticalAdvice> _prioritizeAdvice(List<TacticalAdvice> advice) {
    // Öncelik sıralaması: Kırmızı/Turuncu > Yeşil/Mavi > Diğerleri
    final priorityMap = <Color, int>{
      Colors.red: 1,
      Colors.deepOrange: 2,
      Colors.orange: 3,
      Colors.amber: 4,
      Colors.green: 5,
      const Color(0xFF34D399): 6,
      Colors.teal: 7,
      Colors.blue: 8,
    };

    final sorted = List<TacticalAdvice>.from(advice);
    sorted.sort((a, b) {
      final aPriority = priorityMap[a.color] ?? 99;
      final bPriority = priorityMap[b.color] ?? 99;
      return aPriority.compareTo(bPriority);
    });

    return sorted;
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).cardColor,
            Theme.of(context).cardColor.withOpacity(0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                  Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline,
              color: Theme.of(context).colorScheme.secondary,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Henüz Yeterli Veri Yok',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Daha fazla deneme ekledikçe özel taktiksel öneriler burada görünecek.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}