// lib/features/stats/widgets/subject_stat_card.dart
import 'package:flutter/material.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/features/stats/logic/stats_analysis.dart';

class SubjectStatCard extends StatelessWidget {
  final String subjectName;
  final SubjectAnalysis analysis;
  final VoidCallback onTap;

  const SubjectStatCard({required this.subjectName, required this.analysis, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final double minNet = -(analysis.questionCount * analysis.penaltyCoefficient);
    final double maxNet = analysis.questionCount.toDouble();
    final double progress = (maxNet - minNet) == 0 ? 0.0 : (analysis.averageNet - minNet) / (maxNet - minNet);

    final Color progressColor = Color.lerp(AppTheme.accentColor, AppTheme.successColor, progress.clamp(0.0, 1.0))!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      subjectName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Ort: ${analysis.averageNet.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppTheme.secondaryTextColor),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Tooltip(
                message: "Hakimiyet: %${(progress * 100).toStringAsFixed(0)}",
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: AppTheme.lightSurfaceColor.withOpacity(0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}