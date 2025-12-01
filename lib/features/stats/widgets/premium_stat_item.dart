// lib/features/stats/widgets/premium_stat_item.dart
import 'package:flutter/material.dart';

/// Premium istatistik öğesi
class PremiumStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? suffix;
  final Color color;
  final bool isDark;
  final bool isHighlight;

  const PremiumStatItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.suffix,
    required this.color,
    required this.isDark,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF1E293B) : Colors.white).withOpacity(0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHighlight
                ? color.withOpacity(0.5)
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: 1.5),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 0.5),
                    child: Text(
                      suffix!,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: color.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 1.5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Colors.white.withOpacity(0.5)
                      : Colors.black.withOpacity(0.4),
                  letterSpacing: 0.1,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

