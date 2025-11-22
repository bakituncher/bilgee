// lib/features/home/widgets/summary_widgets/subject_highlights.dart
import 'package:flutter/material.dart';

class SubjectHighlights extends StatelessWidget {
  final Map<String, MapEntry<String, double>> keySubjects;
  const SubjectHighlights({super.key, required this.keySubjects});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _HighlightCard(
                icon: Icons.shield_rounded,
                iconColor: Colors.green,
                title: "Kalen (En Güçlü Alan)",
                subject: keySubjects['strongest']!.key,
                net: keySubjects['strongest']!.value,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _HighlightCard(
                icon: Icons.construction_rounded,
                iconColor: Theme.of(context).colorScheme.primary,
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
  final double net; // Artık yüzde değeri tutuyor

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
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: Center(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  subject,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "%${net.toStringAsFixed(1)} Başarı",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: iconColor,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}