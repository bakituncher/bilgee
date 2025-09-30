// lib/features/home/widgets/focus_hub_card.dart
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/features/home/providers/home_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/shared/widgets/section_header.dart';

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
      _QuickAction(
        icon: Icons.add_chart_rounded,
        label: 'Deneme',
        description: 'Yeni sonuç ekleyerek verilerini canlı tut.',
        onTap: () => context.push('/home/add-test'),
      ),
      _QuickAction(
        icon: Icons.timer_rounded,
        label: 'Odaklan',
        description: '25 dk derin çalışma seansı başlat.',
        onTap: () => context.push('/home/pomodoro'),
      ),
      _QuickAction(
        icon: Icons.construction_rounded,
        label: 'Atölye',
        description: 'Yapay zekâ ile zayıf konunu güçlendir.',
        onTap: () => context.go('/ai-hub/weakness-workshop'),
      ),
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                icon: icon,
                title: title,
                subtitle: subtitle,
                trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.secondaryTextColor),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: actions,
              ),
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
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppTheme.cardColor,
          border: Border.all(color: AppTheme.lightSurfaceColor.withValues(alpha: .45)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryColor.withValues(alpha: .12),
              ),
              child: Icon(icon, color: AppTheme.secondaryColor, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryTextColor,
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 180.ms).scale(begin: const Offset(0.97, 0.97));
  }
}
