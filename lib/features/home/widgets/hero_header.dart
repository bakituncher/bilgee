// lib/features/home/widgets/hero_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/profile/logic/rank_service.dart';
import 'package:taktik/features/home/providers/home_providers.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';

class HeroHeader extends ConsumerWidget {
  const HeroHeader({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'İyi Geceler';
    if (hour < 11) return 'Günaydın';
    if (hour < 17) return 'Kolay Gelsin';
    if (hour < 22) return 'İyi Akşamlar';
    return 'İyi Geceler';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        final info = RankService.getRankInfo(user.engagementScore);
        final current = info.current;
        final progress = info.progress; // 0..1
        final plan = ref.watch(planProgressProvider);

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.8),
                      Theme.of(context).cardColor.withOpacity(0.9),
                    ]
                  : [
                      Theme.of(context).cardColor,
                      Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.25),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: isDark
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08),
                blurRadius: isDark ? 16 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_greeting()}, ${user.name ?? 'Taktik'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        // Row -> Wrap (overflow fix)
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.6), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.workspace_premium_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(current.name, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            if (plan.total>0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.checklist_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Text('%${(plan.ratio*100).toStringAsFixed(0)} Plan', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.25),
                  valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('TP ${user.engagementScore}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                  const SizedBox(width: 6),
                  Text('%${(progress*100).toStringAsFixed(0)} rütbe', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 72, child: LogoLoader(size: 60)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

