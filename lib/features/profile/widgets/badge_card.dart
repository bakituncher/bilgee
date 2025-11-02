// lib/features/profile/widgets/badge_card.dart
import 'package:flutter/material.dart';
import 'package:taktik/features/profile/models/badge_model.dart' as app_badge;

class BadgeCard extends StatelessWidget {
  final app_badge.Badge badge;
  const BadgeCard({super.key, required this.badge});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showBadgeDetails(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: badge.isUnlocked
              ? badge.color.withOpacity(0.1)
              : Theme.of(context).cardColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: badge.isUnlocked
                  ? badge.color
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Icon(
              badge.isUnlocked ? badge.icon : Icons.lock_outline_rounded,
              size: 40,
              color: badge.isUnlocked ? badge.color : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: badge.isUnlocked
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              badge.isUnlocked ? badge.icon : Icons.lock_outline_rounded,
              color: badge.isUnlocked ? badge.color : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(badge.name)),
          ],
        ),
        content: Text(badge.description),
        actions: [
          TextButton(
            child: const Text("Anlaşıldı"),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
    );
  }
}