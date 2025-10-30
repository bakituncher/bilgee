// lib/features/stats/widgets/subject_stat_card.dart
import 'package:flutter/material.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/features/stats/logic/stats_analysis.dart';

class SubjectStatCard extends StatefulWidget {
  final String subjectName;
  final SubjectAnalysis analysis;
  final VoidCallback onTap;

  const SubjectStatCard({required this.subjectName, required this.analysis, required this.onTap, super.key});

  @override
  State<SubjectStatCard> createState() => _SubjectStatCardState();
}

class _SubjectStatCardState extends State<SubjectStatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final double minNet = -(widget.analysis.questionCount * widget.analysis.penaltyCoefficient);
    final double maxNet = widget.analysis.questionCount.toDouble();
    final double progress = (maxNet - minNet) == 0 ? 0.0 : (widget.analysis.averageNet - minNet) / (maxNet - minNet);

    final Color progressColor = Color.lerp(AppTheme.accentColor, AppTheme.successColor, progress.clamp(0.0, 1.0))!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (hover) => setState(() => _isHovered = hover),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  progressColor.withOpacity(_isHovered ? 0.12 : 0.08),
                  progressColor.withOpacity(_isHovered ? 0.08 : 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: progressColor.withOpacity(_isHovered ? 0.4 : 0.25),
                width: 1.5,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: progressColor.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: progressColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.menu_book_rounded,
                              color: progressColor,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.subjectName,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.2,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            progressColor.withOpacity(0.25),
                            progressColor.withOpacity(0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.analysis.averageNet.toStringAsFixed(2),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: progressColor,
                                ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: progressColor,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Hakimiyet',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.secondaryTextColor,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                      fontSize: 11,
                                    ),
                              ),
                              Text(
                                '%${(progress * 100).toStringAsFixed(0)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: progressColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.lightSurfaceColor.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Stack(
                                children: [
                                  FractionallySizedBox(
                                    widthFactor: progress.clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            progressColor,
                                            progressColor.withOpacity(0.8),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}