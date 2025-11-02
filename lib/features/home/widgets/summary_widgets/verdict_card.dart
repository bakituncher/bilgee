// lib/features/home/widgets/summary_widgets/verdict_card.dart
import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
            ? [
                colorScheme.primary.withOpacity(0.15),
                colorScheme.secondary.withOpacity(0.1),
              ]
            : [
                colorScheme.primary.withOpacity(0.08),
                colorScheme.secondary.withOpacity(0.06),
              ],
        ),
        border: Border.all(
          color: isDark
            ? colorScheme.primary.withOpacity(0.3)
            : colorScheme.onSurface.withOpacity(0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
              ? Colors.black.withOpacity(0.2)
              : colorScheme.primary.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.psychology_rounded,
              color: colorScheme.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              verdict['title']!,
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.3 : 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.onSurfaceVariant.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stars_rounded, color: colorScheme.secondary, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Taktik Puanın: ${wisdomScore.toStringAsFixed(1)}",
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withOpacity(0.6),
                  colorScheme.secondary.withOpacity(0.6),
                ],
              ),
            ),
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isDark
                  ? colorScheme.surface.withOpacity(0.6)
                  : colorScheme.surface.withOpacity(0.9),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (wisdomScore / 100).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [colorScheme.secondary, colorScheme.primary],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.2 : 0.3),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.onSurfaceVariant.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.25,
              ),
              child: SingleChildScrollView(
                child: Text(
                  "\"${verdict['verdict']}\"",
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}