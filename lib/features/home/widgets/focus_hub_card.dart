// lib/features/home/widgets/focus_hub_card.dart
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/features/home/providers/home_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FocusHubCard extends ConsumerWidget {
  const FocusHubCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quests = ref.watch(dailyQuestsProgressProvider);
    final plan = ref.watch(planProgressProvider);
    final lastTests = ref.watch(lastTestsSummaryProvider); // YENİ

    // Önceliklendirme (üst bölüm CTA)
    String title = 'Bir Sonraki Adım';
    String subtitle = 'Hedefe doğru küçük ama kararlı bir adım at.';
    IconData icon = Icons.flag_rounded;
    VoidCallback? primary;

    if (quests.total > 0 && quests.progress < 1.0) {
      title = 'Günlük Görevler';
      subtitle = '${quests.completed}/${quests.total} tamamlandı • Kalan ${_humanize(quests.remaining)}';
      icon = Icons.shield_moon_rounded;
      primary = () => context.go('/home/quests');
    } else if (plan.total > 0 && plan.ratio < 1.0) {
      title = 'Planını Tamamla';
      final pct = (plan.ratio * 100).clamp(0, 100).toStringAsFixed(0);
      subtitle = '%$pct tamamlandı • Disiplin gücün';
      icon = Icons.checklist_rounded;
      primary = () => context.go('/home/weekly-plan');
    } else {
      final lastDate = lastTests.lastDate; // YENİ
      final diff = lastDate == null ? null : DateTime.now().difference(lastDate);
      if (lastDate == null || (diff != null && diff > const Duration(days: 2))) {
        title = 'Deneme Ekle';
        subtitle = 'Öğrenen zihin için yeni veri ekle';
        icon = Icons.add_chart_rounded;
        primary = () => context.push('/home/add-test');
      } else {
        title = 'Odaklanma Mabedi';
        subtitle = '25 dk pomodoro ile derin odak';
        icon = Icons.timer_rounded;
        primary = () => context.push('/home/pomodoro');
      }
    }

    // Hızlı eylemler şeridi
    final actions = [
      _QuickAction(icon: Icons.add_chart_rounded, label: 'Deneme', onTap: () => context.push('/home/add-test')),
      _QuickAction(icon: Icons.timer_rounded, label: 'Odaklan', onTap: () => context.push('/home/pomodoro')),
      _QuickAction(icon: Icons.construction_rounded, label: 'Atölye', onTap: () => context.go('/ai-hub/weakness-workshop')),
    ];

    return Card(
      elevation: 10,
      shadowColor: AppTheme.lightSurfaceColor.withValues(alpha: .45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppTheme.lightSurfaceColor.withValues(alpha: .35)),
      ),
      child: InkWell(
        onTap: primary,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst CTA
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.secondaryColor.withValues(alpha: .6)),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Icon(icon, color: AppTheme.secondaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondaryTextColor)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.secondaryTextColor),
                ],
              ),

              const SizedBox(height: 14),
              // Ayrıştırıcı çizgi
              Divider(color: AppTheme.lightSurfaceColor.withValues(alpha: .35), height: 1),
              const SizedBox(height: 12),

              // Hızlı İşlemler
              Row(
                children: actions
                    .map((a) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: a)))
                    .toList(),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 220.ms).slideY(begin: .04, curve: Curves.easeOut);
  }

  String _humanize(Duration d) {
    final h = d.inHours; final m = d.inMinutes.remainder(60);
    if (d.inDays > 0) return '${d.inDays}g';
    if (h > 0) return '${h}s';
    return '${m}dk';
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppTheme.cardColor,
          border: Border.all(color: AppTheme.lightSurfaceColor.withValues(alpha: .45)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.secondaryColor),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ).animate().scale(duration: 120.ms, curve: Curves.easeOut);
  }
}
