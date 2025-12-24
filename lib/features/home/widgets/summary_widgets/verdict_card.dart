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
    final isDark = theme.brightness == Brightness.dark;
    final textTheme = theme.textTheme;

    // Skor bazlı renk
    final scoreColor = wisdomScore >= 70
        ? const Color(0xFF00C853)
        : wisdomScore >= 40
            ? const Color(0xFFFFB300)
            : const Color(0xFFFF5252);

    return Container(
      padding: const EdgeInsets.all(18),
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
        children: [
          // Üst Kısım: Başlık ve Skor
          Row(
            children: [
              // Başlık Badge
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    verdict['title'] ?? '',
                    style: textTheme.labelLarge?.copyWith(
                      color: scoreColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Skor Göstergesi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2E3D) : const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.insights_rounded, size: 18, color: scoreColor),
                    const SizedBox(width: 6),
                    Text(
                      wisdomScore.toStringAsFixed(0),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scoreColor,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: wisdomScore / 100,
              minHeight: 6,
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
            ),
          ),
          const SizedBox(height: 14),
          // Yorum Metni
          Text(
            verdict['verdict'] ?? '',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white70 : Colors.black54,
              height: 1.5,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}