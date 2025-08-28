// lib/features/home/widgets/dashboard_header.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.name,
    required this.title,
  });

  final String name;
  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
            Text(title, style: textTheme.titleMedium?.copyWith(color: AppTheme.secondaryColor, fontStyle: FontStyle.italic)),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.history_edu_rounded, color: AppTheme.secondaryTextColor, size: 28),
          tooltip: 'Performans Arşivi',
          onPressed: () => context.go('/library'),
        ),
      ],
    );
  }
}