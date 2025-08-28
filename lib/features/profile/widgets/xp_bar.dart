// lib/features/profile/widgets/xp_bar.dart
import 'package:flutter/material.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';

class XpBar extends StatelessWidget {
  final int currentXp;
  final int nextLevelXp;
  final String rankName;

  const XpBar({
    super.key,
    required this.currentXp,
    required this.nextLevelXp,
    required this.rankName,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = (currentXp / nextLevelXp).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(rankName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
            Text('$currentXp / $nextLevelXp BP', style: const TextStyle(color: AppTheme.secondaryTextColor, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: AppTheme.lightSurfaceColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    width: constraints.maxWidth * progress,
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.successColor, AppTheme.secondaryColor],
                        stops: [0.3, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.secondaryColor.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                  );
                }
            ),
          ],
        ),
      ],
    );
  }
}