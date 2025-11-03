// lib/features/home/widgets/resume_cta.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/home/providers/home_providers.dart';

class ResumeCta extends ConsumerWidget {
  const ResumeCta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value; // sadece null kontrolü için
    final activity = ref.watch(lastActivityProvider);
    if (user == null) return const SizedBox.shrink();

    final label = activity.label;
    final icon = activity.icon;
    void onTap() => context.go(activity.route);
    final color = activity.color;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Theme.of(context).cardColor, Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.45)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant)
          ],
        ),
      ),
    );
  }
}
