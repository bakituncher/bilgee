// lib/features/home/widgets/summary_widgets/subject_highlights.dart
import 'package:flutter/material.dart';

class SubjectHighlights extends StatelessWidget {
  final Map<String, MapEntry<String, double>> keySubjects;
  const SubjectHighlights({super.key, required this.keySubjects});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: _PremiumHighlightCard(
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFF00C853),
            label: "Güçlü Alan",
            subject: keySubjects['strongest']!.key,
            value: keySubjects['strongest']!.value,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _PremiumHighlightCard(
            icon: Icons.trending_up_rounded,
            iconColor: const Color(0xFFFF9800),
            label: "Gelişim Fırsatı",
            subject: keySubjects['weakest']!.key,
            value: keySubjects['weakest']!.value,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _PremiumHighlightCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subject;
  final double value;
  final bool isDark;

  const _PremiumHighlightCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subject,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                "%${value.toStringAsFixed(0)}",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                "başarı",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}