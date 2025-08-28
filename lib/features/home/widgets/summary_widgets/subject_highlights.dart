// lib/features/home/widgets/summary_widgets/subject_highlights.dart
import 'package:flutter/material.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';

class SubjectHighlights extends StatelessWidget {
  final Map<String, MapEntry<String, double>> keySubjects;
  const SubjectHighlights({super.key, required this.keySubjects});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _HighlightCard(
                icon: Icons.shield_rounded,
                iconColor: AppTheme.successColor,
                title: "Kal'en (En Güçlü Alan)",
                subject: keySubjects['strongest']!.key,
                net: keySubjects['strongest']!.value,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _HighlightCard(
                icon: Icons.construction_rounded,
                iconColor: AppTheme.secondaryColor,
                title: "Cevher (Gelişim Fırsatı)",
                subject: keySubjects['weakest']!.key,
                net: keySubjects['weakest']!.value,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          "En zayıf alanına odaklanmak, netlerini en hızlı artıracak stratejidir.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor),
        )
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor)),
            const SizedBox(height: 8),
            Text(subject, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("${net.toStringAsFixed(2)} Net", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: iconColor)),
          ],
        ),
      ),
    );
  }
}