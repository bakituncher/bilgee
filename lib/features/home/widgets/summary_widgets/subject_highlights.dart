// lib/features/home/widgets/summary_widgets/subject_highlights.dart
import 'package:flutter/material.dart';

class SubjectHighlights extends StatelessWidget {
  final Map<String, MapEntry<String, double>> keySubjects;
  const SubjectHighlights({super.key, required this.keySubjects});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _HighlightCard(
                icon: Icons.shield_rounded,
                iconColor: colorScheme.secondary,
                title: "Kal'en (En Güçlü)",
                subject: keySubjects['strongest']!.key,
                net: keySubjects['strongest']!.value,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HighlightCard(
                icon: Icons.construction_rounded,
                iconColor: colorScheme.primary,
                title: "Cevher (Gelişim)",
                subject: keySubjects['weakest']!.key,
                net: keySubjects['weakest']!.value,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.onSurfaceVariant.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.tips_and_updates_outlined, color: colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "En zayıf alanına odaklanmak, netlerini en hızlı artıracak stratejidir.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subject;
  final double net;

  const _HighlightCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subject,
    required this.net,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.cardColor,
        border: Border.all(
          color: isDark
            ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
            : colorScheme.onSurface.withOpacity(0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
              ? Colors.black.withOpacity(0.15)
              : iconColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subject,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: iconColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              "${net.toStringAsFixed(1)} Net",
              style: theme.textTheme.titleMedium?.copyWith(
                color: iconColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}