// lib/features/profile/widgets/warrior_id_card.dart
import 'package:flutter/material.dart';
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';

class WarriorIDCard extends StatelessWidget {
  final UserModel user;
  final String title;
  const WarriorIDCard({super.key, required this.user, required this.title});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 4,
      shadowColor: AppTheme.primaryColor.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppTheme.secondaryColor,
              child: Text(
                user.name?.substring(0, 1).toUpperCase() ?? 'B',
                style: textTheme.displaySmall?.copyWith(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name ?? 'İsimsiz Savaşçı', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(title, style: textTheme.titleMedium?.copyWith(color: AppTheme.secondaryColor, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '${user.engagementScore} Bilgelik Puanı',
                        style: textTheme.titleMedium?.copyWith(color: Colors.amber),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}