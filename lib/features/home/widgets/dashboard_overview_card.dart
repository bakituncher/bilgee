// lib/features/home/widgets/dashboard_overview_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/home/providers/home_providers.dart';

/// Professional dashboard overview card displaying key metrics
class DashboardOverviewCard extends ConsumerWidget {
  const DashboardOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    
    final questProg = ref.watch(dailyQuestsProgressProvider);
    final plan = ref.watch(planProgressProvider);
    final userAsync = ref.watch(userProfileProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        return Card(
          elevation: isDark ? 6 : 5,
          shadowColor: isDark 
            ? Colors.black.withOpacity(0.35)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: isDark 
                ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.25)
                : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: isDark
                  ? [
                      theme.cardColor,
                      theme.colorScheme.primary.withOpacity(0.06),
                      theme.colorScheme.surfaceContainerHighest.withOpacity(0.1),
                    ]
                  : [
                      theme.cardColor,
                      theme.colorScheme.surfaceContainerHighest.withOpacity(0.08),
                      theme.cardColor.withOpacity(0.95),
                    ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(isDark ? 0.18 : 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(isDark ? 0.4 : 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.dashboard_customize_rounded, 
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bugünün Özeti',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Stats Grid
                Row(
                  children: [
                    Expanded(
                      child: _OverviewStat(
                        icon: Icons.shield_moon_rounded,
                        value: '${questProg.completed}/${questProg.total}',
                        label: 'Günlük Görevler',
                        progress: questProg.progress,
                        onTap: () => context.go('/home/quests'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _OverviewStat(
                        icon: Icons.checklist_rounded,
                        value: '%${(plan.ratio * 100).toStringAsFixed(0)}',
                        label: 'Haftalık Plan',
                        progress: plan.ratio,
                        onTap: () => context.go('/home/weekly-plan'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _OverviewStat(
                        icon: Icons.workspace_premium_rounded,
                        value: user.engagementScore.toString(),
                        label: 'Başarı Puanı',
                        onTap: () => context.go('/profile'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _OverviewStat(
                        icon: Icons.timer_outlined,
                        value: '${(user.totalStudyTime / 60).toStringAsFixed(0)}s',
                        label: 'Toplam Odak',
                        onTap: () => context.push('/home/pomodoro'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 300.ms, curve: Curves.easeOut).slideY(begin: .08, curve: Curves.easeOutCubic);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final double? progress;
  final VoidCallback? onTap;

  const _OverviewStat({
    required this.icon,
    required this.value,
    required this.label,
    this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasProgress = progress != null;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: isDark
              ? [
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.12),
                  theme.cardColor,
                ]
              : [
                  theme.cardColor,
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.05),
                ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isDark 
              ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.25)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon, 
                  color: theme.colorScheme.primary, 
                  size: 20,
                ),
                const Spacer(),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (hasProgress) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.2 : 0.3),
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
