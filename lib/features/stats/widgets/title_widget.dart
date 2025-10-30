// lib/features/stats/widgets/title_widget.dart
import 'package:flutter/material.dart';
import 'package:taktik/core/theme/app_theme.dart';

class TitleWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  const TitleWidget({required this.title, required this.subtitle, super.key});

  IconData _getIconForTitle(String title) {
    if (title.contains('Kader')) return Icons.show_chart_rounded;
    if (title.contains('Zafer')) return Icons.emoji_events_rounded;
    if (title.contains('Taktik')) return Icons.auto_awesome_rounded;
    if (title.contains('Ders')) return Icons.map_rounded;
    return Icons.star_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.secondaryColor.withOpacity(0.2),
                  AppTheme.secondaryColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getIconForTitle(title),
              color: AppTheme.secondaryColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryTextColor,
                        height: 1.2,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}