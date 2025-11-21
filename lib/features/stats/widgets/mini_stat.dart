// lib/features/stats/widgets/mini_stat.dart
import 'package:flutter/material.dart';

/// Mini istatistik göstergesi
class MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  final bool isDark;

  const MiniStat({
    super.key,
    required this.icon,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark
                ? Colors.white.withOpacity(0.7)
                : Colors.black.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

