// lib/features/home/widgets/resume_cta.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/home/providers/home_providers.dart';

class ResumeCta extends ConsumerWidget {
  const ResumeCta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value; // sadece null kontrolü için
    final activity = ref.watch(lastActivityProvider);
    if (user == null) return const SizedBox.shrink();

    final label = activity.label;
    final icon = activity.icon;
    final onTap = () => context.go(activity.route);
    final color = activity.color;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [AppTheme.cardColor, AppTheme.lightSurfaceColor.withValues(alpha: .35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppTheme.lightSurfaceColor.withValues(alpha: .45)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: .15),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: AppTheme.secondaryTextColor)
          ],
        ),
      ),
    );
  }
}
