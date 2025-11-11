// lib/features/home/widgets/focus_hub_card.dart
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: isDark ? 8 : 10,
      shadowColor: isDark
          ? Colors.black.withOpacity(0.4)
          : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark
              ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
              : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35),
        ),
      ),
      child: InkWell(
        onTap: primary,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst CTA
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.6)),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
                ],
              ),

              const SizedBox(height: 10),
              // Ayrıştırıcı çizgi
              Divider(color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35), height: 1),
              const SizedBox(height: 10),

              // Hızlı İşlemler
              Row(
                children: actions
                    .map((a) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: a)))
                    .toList(),
              ),
              const SizedBox(height: 2),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: isDark
                ? [
                    Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.5),
                    Theme.of(context).cardColor.withOpacity(0.7),
                  ]
                : [
                    Theme.of(context).cardColor,
                    Theme.of(context).cardColor,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isDark
                ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3)
                : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.45),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 11)),
          ],
        ),
      ),
    ).animate().scale(duration: 120.ms, curve: Curves.easeOut);
  }
}
