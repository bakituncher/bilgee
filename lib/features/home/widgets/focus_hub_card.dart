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
      elevation: isDark ? 8 : 6,
      shadowColor: isDark 
        ? Colors.black.withOpacity(0.4)
        : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: isDark 
            ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.25)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: isDark
              ? [
                  Theme.of(context).cardColor,
                  Theme.of(context).colorScheme.primary.withOpacity(0.06),
                ]
              : [
                  Theme.of(context).cardColor,
                  Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.1),
                ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: InkWell(
          onTap: primary,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst CTA
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(isDark ? 0.4 : 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),

              const SizedBox(height: 16),
              // Ayrıştırıcı çizgi (Enhanced)
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.3 : 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

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
      ),
    ).animate().fadeIn(duration: 280.ms, curve: Curves.easeOut).slideY(begin: .06, curve: Curves.easeOutCubic);
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
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isDark
              ? [
                  Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.12),
                  Theme.of(context).cardColor,
                ]
              : [
                  Theme.of(context).cardColor,
                  Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.08),
                ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isDark 
              ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35)
              : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
            const SizedBox(height: 7),
            Text(
              label, 
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 160.ms).scale(begin: const Offset(0.95, 0.95), duration: 160.ms, curve: Curves.easeOutCubic);
  }
}
