// lib/features/home/widgets/daily_progress_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/features/home/providers/home_providers.dart';
import 'package:taktik/features/quests/logic/optimized_quests_provider.dart';
import 'package:taktik/shared/widgets/section_header.dart';

class DailyProgressCard extends ConsumerWidget {
  const DailyProgressCard({super.key});

  String _formatDuration(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}g';
    if (d.inHours >= 1) return '${d.inHours}s';
    final minutes = d.inMinutes;
    return minutes <= 0 ? 'az kaldı' : '${minutes}dk';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questProgress = ref.watch(dailyQuestsProgressProvider);
    final hasClaimable = ref.watch(hasClaimableQuestsProvider);

    final completed = questProgress.completed;
    final total = questProgress.total;
    final progress = questProgress.progress;
    final remaining = questProgress.remaining;

    final double displayProgress = total == 0 ? 0.0 : progress.clamp(0.0, 1.0);
    final statusColor = hasClaimable
        ? AppTheme.goldColor
        : (displayProgress >= 1.0
            ? AppTheme.successColor
            : AppTheme.secondaryColor);

    return Card(
      elevation: hasClaimable ? 14 : 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      shadowColor: statusColor.withOpacity(0.5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/home/quests'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                statusColor.withOpacity(0.18),
                AppTheme.cardColor.withOpacity(0.85),
              ],
            ),
            border: Border.all(
              color: statusColor.withOpacity(0.55),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SectionHeader(
                icon: hasClaimable
                    ? Icons.military_tech_rounded
                    : Icons.local_fire_department_rounded,
                title: hasClaimable
                    ? 'Ödül Zamanı'
                    : 'Günlük Ritüellerin',
                subtitle: total == 0
                    ? 'Bugüne ait görev planı henüz oluşturulmadı.'
                    : '${completed ~/ 1} / $total görev tamamlandı • Kalan ${_formatDuration(remaining)}',
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasClaimable
                            ? Icons.celebration_rounded
                            : Icons.schedule_rounded,
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasClaimable
                            ? 'Ödül Hazır'
                            : total == 0
                                ? 'Hazırlan'
                                : '${(displayProgress * 100).round()}%',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: total == 0 ? null : displayProgress,
                  minHeight: 10,
                  backgroundColor:
                      AppTheme.lightSurfaceColor.withOpacity(0.35),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _StatusPill(
                    icon: Icons.flag_rounded,
                    label: 'Tamamlanan',
                    value: '$completed',
                  ),
                  const SizedBox(width: 10),
                  _StatusPill(
                    icon: Icons.checklist_rounded,
                    label: 'Planlanan',
                    value: '$total',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Detayları açmak için dokun',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: AppTheme.secondaryTextColor,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: .06, curve: Curves.easeOut);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightSurfaceColor.withOpacity(.45)),
        color: AppTheme.lightSurfaceColor.withOpacity(.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.secondaryColor),
          const SizedBox(width: 6),
          Text(
            '$label · $value',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondaryTextColor,
                ),
          ),
        ],
      ),
    );
  }
}
