// lib/features/home/widgets/dashboard_header.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
            Text(name, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            Text(title, style: textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontStyle: FontStyle.italic)),
          ],
        ),
        IconButton(
          icon: Icon(Icons.history_edu_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 28),
          tooltip: 'Deneme Arşivi',
          onPressed: () => context.go('/library'),
        ),
      ],
    );
  }
}