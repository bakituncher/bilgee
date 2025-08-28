// lib/features/profile/widgets/war_stats.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/shared/widgets/stat_card.dart';
import 'package:bilge_ai/core/navigation/app_routes.dart';

class WarStats extends StatelessWidget {
  final int testCount;
  final double avgNet;
  final int streak;
  const WarStats({super.key, required this.testCount, required this.avgNet, required this.streak});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ProfileStatCard(
            value: testCount.toString(),
            label: 'Toplam Deneme',
            icon: Icons.library_books_rounded,
            onTap: () => context.push(AppRoutes.library),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ProfileStatCard(
            value: avgNet.toStringAsFixed(2),
            label: 'Ortalama Net',
            icon: Icons.track_changes_rounded,
            onTap: () => context.push('/home/stats'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ProfileStatCard(
            value: streak.toString(),
            label: 'Günlük Seri',
            icon: Icons.local_fire_department_rounded,
          ),
        ),
      ],
    );
  }
}