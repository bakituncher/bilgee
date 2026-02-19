// lib/features/home/widgets/dashboard_cards/weekly_plan_card_compact.dart
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:taktik/data/models/plan_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:taktik/core/navigation/app_routes.dart';

double _clamp01(num v) {
  if (v.isNaN) return 0.0;
  if (v < 0) return 0.0;
  if (v > 1) return 1.0;
  return v.toDouble();
}

/// Compact Weekly Plan Card - Premium Design for 180px height
/// Sektör seviyesinde, şık ve işlevsel tasarım
class WeeklyPlanCardCompact extends ConsumerWidget {
  const WeeklyPlanCardCompact({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planDoc = ref.watch(planProvider).value;
    final userId = ref.watch(userProfileProvider).value?.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (userId == null) return const SizedBox.shrink();

    final weeklyPlan = planDoc?.weeklyPlan != null
        ? WeeklyPlan.fromJson(planDoc!.weeklyPlan!)
        : null;

    // GÜNCELLEME: Plan yoksa veya süresi dolmuşsa Empty State göster
    if (weeklyPlan == null || weeklyPlan.plan.isEmpty || weeklyPlan.isExpired) {
      return _EmptyPlanCard(isDark: isDark);
    }

    return _CompactPlanContent(
      weeklyPlan: weeklyPlan,
      userId: userId,
      isDark: isDark,
    );
  }
}

class _CompactPlanContent extends ConsumerWidget {
  final WeeklyPlan weeklyPlan;
  final String userId;
  final bool isDark;

  const _CompactPlanContent({
    required this.weeklyPlan,
    required this.userId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Calculate weekly progress
    // Bugünün haftasının başını (Pazartesi) hesapla — provider cache'i bozmasın diye
    // normalize et (saat/dakika/saniye sıfır)
    final now = DateTime.now();
    final todayNormalized = DateTime(now.year, now.month, now.day);
    final startOfWeek = todayNormalized.subtract(Duration(days: todayNormalized.weekday - 1));

    final weeklyCompletedMap = ref.watch(completedTasksForWeekProvider(startOfWeek)).maybeWhen(
      data: (m) => m,
      orElse: () => const <String, List<String>>{},
    );

    int total = 0;
    int done = 0;

    // Progress: her plan gününü gün adına göre tarihe çevir
    for (int i = 0; i < weeklyPlan.plan.length; i++) {
      final dp = weeklyPlan.plan[i];
      total += dp.schedule.length;
      // Gün adından haftanın hangi günü olduğunu bul
      const trDays = ['pazartesi','salı','çarşamba','perşembe','cuma','cumartesi','pazar'];
      final dayIdx = trDays.indexOf(dp.day.toLowerCase().trim());
      if (dayIdx < 0) continue;
      // Bu haftada o günün tarihi
      final dayDate = startOfWeek.add(Duration(days: dayIdx));
      final dk = DateFormat('yyyy-MM-dd').format(dayDate);
      final completedList = weeklyCompletedMap[dk] ?? const <String>[];
      for (final s in dp.schedule) {
        if (completedList.contains(s.id)) done++;
      }
    }

    final double ratio = total == 0 ? 0.0 : done / total;

    // Bugünün Türkçe gün adını bul ve plan listesinde eşleştir
    const turkishDays = [
      'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'
    ];
    final todayTurkish = turkishDays[now.weekday - 1].toLowerCase();
    final todayPlanIndex = weeklyPlan.plan.indexWhere(
      (dp) => dp.day.toLowerCase().trim() == todayTurkish,
    );
    final todayPlan = todayPlanIndex >= 0 ? weeklyPlan.plan[todayPlanIndex] : null;

    // Today's completed tasks
    final todayDate = DateFormat('yyyy-MM-dd').format(now);
    final todayCompleted = weeklyCompletedMap[todayDate] ?? const <String>[];

    // Saate göre akıllı görev seçimi:
    // "HH:mm" formatındaki time string'ini dakikaya çevir
    int _timeToMinutes(String timeStr) {
      try {
        final parts = timeStr.trim().split(':');
        if (parts.length < 2) return -1;
        final h = int.tryParse(parts[0]) ?? -1;
        final m = int.tryParse(parts[1].split(' ')[0]) ?? 0;
        if (h < 0) return -1;
        return h * 60 + m;
      } catch (_) { return -1; }
    }

    final nowMinutes = now.hour * 60 + now.minute;
    final schedule = todayPlan?.schedule ?? [];

    ScheduleItem? currentTask;

    if (schedule.isNotEmpty) {
      // 1. Tamamlanmamış + saati geçmemiş olan ilk görevi bul
      currentTask = schedule.firstWhereOrNull((t) {
        final mins = _timeToMinutes(t.time);
        return mins >= nowMinutes && !todayCompleted.contains(t.id);
      });

      // 2. Yoksa tamamlanmamış herhangi bir görevi bul (saati geçmiş bile olsa)
      currentTask ??= schedule.firstWhereOrNull((t) => !todayCompleted.contains(t.id));

      // 3. Hepsi tamamlandıysa saate göre en yakın geçmiş görevi göster
      currentTask ??= (() {
        ScheduleItem? best;
        int bestDiff = 999999;
        for (final t in schedule) {
          final mins = _timeToMinutes(t.time);
          if (mins < 0) continue;
          final diff = (nowMinutes - mins).abs();
          if (diff < bestDiff) { bestDiff = diff; best = t; }
        }
        return best ?? schedule.last;
      })();
    }

    final todayTasks = currentTask != null ? [currentTask] : <ScheduleItem>[];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.7),
                  Theme.of(context).cardColor.withOpacity(0.95),
                ]
              : [
                  Theme.of(context).colorScheme.primary.withOpacity(0.15),
                  Theme.of(context).cardColor.withOpacity(0.98),
                  Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isDark
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with progress
          Row(
            children: [
              // Premium icon with gradient
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ratio >= 0.75 ? Colors.green : Theme.of(context).colorScheme.primary,
                      (ratio >= 0.75 ? Colors.green : Theme.of(context).colorScheme.primary).withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              // Title with underline
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Haftalık Plan',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 1),
                      height: 2,
                      width: 30,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.primary.withOpacity(0),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
              // Circular progress
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      value: _clamp01(ratio),
                      strokeWidth: 3.5,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.25),
                      valueColor: AlwaysStoppedAnimation(
                        ratio >= 0.75 ? Colors.green : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Text(
                    '%${(ratio * 100).round()}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Today's First Task Preview
          if (todayTasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3)
                    : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.self_improvement_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bugün dinlenme günü',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...todayTasks.map((task) {
              final taskId = task.id;
              final isCompleted = todayCompleted.contains(taskId);
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3)
                      : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCompleted
                        ? Colors.green.withOpacity(0.4)
                        : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: isCompleted ? Colors.green : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.activity,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isCompleted
                                  ? Theme.of(context).colorScheme.onSurfaceVariant
                                  : Theme.of(context).colorScheme.onSurface,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            task.time,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),

          const SizedBox(height: 8),

          // Action button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go('/home/weekly-plan'),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.visibility_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 5),
                      Text(
                        'Tüm Planı Gör',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: .12, curve: Curves.easeOut);
  }
}

class _EmptyPlanCard extends ConsumerWidget {
  final bool isDark;

  const _EmptyPlanCard({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.6),
          ]
              : [
            Theme.of(context).colorScheme.primary.withOpacity(0.12),
            Theme.of(context).cardColor.withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.7),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'Haftalık Planın Yok',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'AI ile stratejik plan oluştur',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                // ÇÖZÜM: Premium gate kontrolü
                onTap: () {
                  final isPremium = ref.read(premiumStatusProvider);
                  if (isPremium) {
                    context.go('${AppRoutes.aiHub}/${AppRoutes.strategicPlanning}');
                  } else {
                    context.go(AppRoutes.aiToolsOffer);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Plan Oluştur',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}