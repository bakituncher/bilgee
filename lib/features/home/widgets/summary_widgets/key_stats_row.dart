// lib/features/home/widgets/summary_widgets/key_stats_row.dart
import 'package:flutter/material.dart';
import 'package:taktik/data/models/test_model.dart';

class KeyStatsRow extends StatelessWidget {
  final TestModel test;
  const KeyStatsRow({super.key, required this.test});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
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
              : colorScheme.primary.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatColumn(
            label: "Toplam Net",
            value: test.totalNet.toStringAsFixed(1),
            icon: Icons.calculate_outlined,
            color: colorScheme.primary,
          ),
          _StatColumn(
            label: "Doğru",
            value: test.totalCorrect.toString(),
            icon: Icons.check_circle_outline,
            color: colorScheme.secondary,
          ),
          _StatColumn(
            label: "Yanlış",
            value: test.totalWrong.toString(),
            icon: Icons.cancel_outlined,
            color: colorScheme.error,
          ),
          _StatColumn(
            label: "Boş",
            value: test.totalBlank.toString(),
            icon: Icons.radio_button_unchecked,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}