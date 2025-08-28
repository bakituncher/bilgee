// lib/features/stats/widgets/ai_insight_card.dart
import 'package:flutter/material.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/features/stats/logic/stats_analysis.dart';

class AiInsightCard extends StatelessWidget {
  final StatsAnalysis analysis;
  const AiInsightCard({required this.analysis, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.lightSurfaceColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: analysis.tacticalAdvice.map((advice) {
            final isLast = advice == analysis.tacticalAdvice.last;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(advice.icon, color: advice.color, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      advice.text,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textColor, height: 1.5),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}