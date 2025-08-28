// lib/features/home/widgets/dashboard_widgets/dashboard_stats_row.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/shared/widgets/stat_card.dart';

class DashboardStatsRow extends StatelessWidget {
  final double avgNet;
  final double bestNet;
  final int streak;

  const DashboardStatsRow({
    super.key,
    required this.avgNet,
    required this.bestNet,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(child: StatCard(icon: Icons.track_changes_rounded, value: avgNet.toStringAsFixed(1), label: 'Ortalama Net', color: Colors.blueAccent, onTap: () => context.push('/home/stats'))),
          const SizedBox(width: 12),
          Expanded(child: StatCard(icon: Icons.emoji_events_rounded, value: bestNet.toStringAsFixed(1), label: 'En Yüksek Net', color: Colors.amber, onTap: () => context.push('/home/stats'))),
          const SizedBox(width: 12),
          Expanded(child: StatCard(icon: Icons.local_fire_department_rounded, value: streak.toString(), label: 'Günlük Seri', color: Colors.orangeAccent, onTap: () => context.push('/home/stats'))),
        ],
      ),
    );
  }
}