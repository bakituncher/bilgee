// lib/features/home/widgets/summary_widgets/verdict_card.dart
import 'package:flutter/material.dart';
import 'package:taktik/core/theme/app_theme.dart';

class VerdictCard extends StatelessWidget {
  final Map<String, String> verdict;
  final double wisdomScore;

  const VerdictCard({
    super.key,
    required this.verdict,
    required this.wisdomScore,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 4,
      shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(verdict['title']!, style: textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "Taktik Puanın: ${wisdomScore.toStringAsFixed(1)}",
                style: textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: wisdomScore / 100,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.25,
              ),
              child: SingleChildScrollView(
                child: Text(
                  "\"${verdict['verdict']}\"",
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic, height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}