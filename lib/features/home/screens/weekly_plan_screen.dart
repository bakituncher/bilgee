// lib/features/home/screens/weekly_plan_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:taktik/data/models/plan_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';
import 'package:flutter/services.dart'; // Haptic için
import 'package:go_router/go_router.dart';
import 'package:taktik/features/pomodoro/logic/pomodoro_notifier.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/data/providers/premium_provider.dart';

final _selectedDayProvider = StateProvider.autoDispose<int>((ref) {
  int todayIndex = DateTime.now().weekday - 1;
  return todayIndex.clamp(0, 6);
});

final _isExpiredWarningShownProvider = StateProvider.autoDispose<bool>((ref) => false);

class WeeklyPlanScreen extends ConsumerStatefulWidget {
  const WeeklyPlanScreen({super.key});

  @override
  ConsumerState<WeeklyPlanScreen> createState() => _WeeklyPlanScreenState();
}

class _WeeklyPlanScreenState extends ConsumerState<WeeklyPlanScreen> {
  void _maybeShowExpiredDialog(BuildContext context, WeeklyPlan weeklyPlan) {
    final alreadyShown = ref.read(_isExpiredWarningShownProvider);
    if (!weeklyPlan.isExpired || alreadyShown) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('⚠️ Planınızın Süresi Doldu'),
          content: const Text('Haftalık planınızın süresi doldu. Yeni bir plan oluşturmanız önerilir.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Şimdi Değil'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/ai-hub/strategic-planning');
              },
              child: const Text('Yeni Plan Oluştur'),
            ),
          ],
        ),
      );
      if (mounted) ref.read(_isExpiredWarningShownProvider.notifier).state = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).value;
    final planDoc = ref.watch(planProvider).value;
    final weeklyPlan = planDoc?.weeklyPlan != null ? WeeklyPlan.fromJson(planDoc!.weeklyPlan!) : null;

    if (user == null || weeklyPlan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Haftalık Plan')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today_outlined, size: 64, color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text("Aktif bir haftalık plan bulunamadı.", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text("Yeni bir plan oluşturmak için Strateji bölümünü ziyaret edin.", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  final isPremium = ref.read(premiumStatusProvider);
                  if (isPremium) {
                    context.go('/ai-hub/strategic-planning');
                  } else {
                    context.go(AppRoutes.aiToolsOffer);
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Plan Oluştur'),
              ),
            ],
          ),
        ),
      );
    }

    _maybeShowExpiredDialog(context, weeklyPlan);

    final creationDate = weeklyPlan.creationDate;
    final creationDayStart = DateTime(creationDate.year, creationDate.month, creationDate.day);
    final startOfWeek = creationDayStart.subtract(Duration(days: creationDayStart.weekday - 1));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Harekât Takvimi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Theme.of(context).colorScheme.surface, Theme.of(context).cardColor.withOpacity(0.8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (weeklyPlan.isExpired)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(child: Text('Bu planın süresi doldu', style: TextStyle(fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Stratejik Odak:",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    Text(
                      weeklyPlan.strategyFocus,
                      maxLines: 2, // 👈 Maksimum 2 satır
                      overflow: TextOverflow.ellipsis, // 👈 Uzunsa "..." ekle
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary, fontStyle: FontStyle.italic),
                    ),
                  ],
                ).animate().fadeIn(duration: 500.ms),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: WeeklyOverviewCard(weeklyPlan: weeklyPlan, userId: user.id, startOfWeek: startOfWeek),
              ),
              const SizedBox(height: 4),
              const _DaySelector(
                days: ['PZT', 'SAL', 'ÇAR', 'PER', 'CUM', 'CMT', 'PAZ'],
              ),
              const Divider(height: 1),
              _buildPlanView(context, ref, weeklyPlan, user.id, startOfWeek),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanView(BuildContext context, WidgetRef ref, WeeklyPlan weeklyPlan, String userId, DateTime startOfWeek) {
    final selectedDayIndex = ref.watch(_selectedDayProvider);
    final dayName = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'][selectedDayIndex];
    final dailyPlan = weeklyPlan.plan.firstWhere((p) => p.day == dayName, orElse: () => DailyPlan(day: dayName, schedule: []));

    return Expanded(
      child: AnimatedSwitcher(
        duration: 400.ms,
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
        child: dailyPlan.schedule.isEmpty
            ? _EmptyDayView(key: ValueKey(dayName))
            : _TaskListView(key: ValueKey(dayName), dailyPlan: dailyPlan, userId: userId, startOfWeek: startOfWeek),
      ),
    );
  }
}

class _DaySelector extends ConsumerWidget {
  final List<String> days;
  const _DaySelector({required this.days});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDayIndex = ref.watch(_selectedDayProvider);
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final isSelected = selectedDayIndex == index;
          return GestureDetector(
            onTap: () => ref.read(_selectedDayProvider.notifier).state = index,
            child: AnimatedContainer(
              duration: 300.ms,
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).cardColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: isSelected ? null : Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest),
              ),
              child: Center(
                child: Text(
                  days[index],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TaskListView extends ConsumerStatefulWidget {
  final DailyPlan dailyPlan; final String userId; final DateTime startOfWeek;
  const _TaskListView({super.key, required this.dailyPlan, required this.userId, required this.startOfWeek});
  @override
  ConsumerState<_TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends ConsumerState<_TaskListView> with AutomaticKeepAliveClientMixin<_TaskListView> {
  // Yerel override: dateKey -> (taskId -> isCompleted)
  final Map<String, Map<String, bool>> _overrides = {};
  Map<String, bool> _getOverrides(String dateKey) => _overrides.putIfAbsent(dateKey, () => <String, bool>{});
  @override bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dailyPlan = widget.dailyPlan; final userId = widget.userId;
    final startOfWeek = widget.startOfWeek;
    final dayIndex = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'].indexOf(dailyPlan.day);
    final dateForTab = startOfWeek.add(Duration(days: dayIndex));
    final dateKey = DateFormat('yyyy-MM-dd').format(dateForTab);

    // Haftalık tamamlanan görevleri tek seferde oku
    final weeklyCompletedMap = ref.watch(completedTasksForWeekProvider(startOfWeek)).maybeWhen(
      data: (m) => m,
      orElse: () => const <String, List<String>>{},
    );

    final totalTasks = dailyPlan.schedule.length;
    final baseCompletedList = weeklyCompletedMap[dateKey] ?? const <String>[];
    final overrides = _getOverrides(dateKey);

    final completedCount = dailyPlan.schedule.where((item) {
      final id = item.id;
      final base = baseCompletedList.contains(id);
      final forced = overrides[id];
      return forced ?? base;
    }).length;
    final progress = totalTasks == 0 ? 0.0 : completedCount / totalTasks;

    return Column(
      children: [
        _DaySummaryHeader(dayLabel: dailyPlan.day, date: dateForTab, completed: completedCount, total: totalTasks, progress: progress),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: dailyPlan.schedule.length,
            itemBuilder: (context, index) {
              final item = dailyPlan.schedule[index];
              final taskIdentifier = item.id;
              final base = baseCompletedList.contains(taskIdentifier);
              final forced = overrides[taskIdentifier];
              final isCompleted = forced ?? base;
              return RepaintBoundary(
                child: _TaskTimelineTile(
                  item: item,
                  isCompleted: isCompleted,
                  isFirst: index == 0,
                  isLast: index == dailyPlan.schedule.length - 1,
                  dateKey: dateKey,
                  onToggle: () async {
                    HapticFeedback.selectionClick();
                    final desired = !isCompleted;
                    // Eğer tamamlanmamış bir görevi bitirmek üzereyse, aksiyon sor
                    if (desired) {
                      final action = await _askAction(context, item.activity);
                      if (action == _TaskAction.startPomodoro) {
                        // Görevi Pomodoro’ya taşı ve ekranı aç
                        final id = taskIdentifier;
                        final pomodoro = ref.read(pomodoroProvider.notifier);
                        pomodoro.setTask(task: item.activity, identifier: id, dateKey: dateKey);
                        pomodoro.prepareForWork();
                        pomodoro.start();
                        if (context.mounted) context.go('/home/pomodoro');
                        return; // Tamamlama akışına girme
                      } else if (action == null) {
                        // Vazgeçildi
                        return;
                      }
                      // Aksi halde completeNow ile devam eder
                    }

                    // Optimistik: anında UI
                    setState(() { overrides[taskIdentifier] = desired; });
                    try {
                      await ref.read(firestoreServiceProvider).updateDailyTaskCompletion(
                        userId: userId,
                        dateKey: dateKey,
                        task: taskIdentifier,
                        isCompleted: desired,
                      );
                      final newMap = await ref.refresh(completedTasksForWeekProvider(startOfWeek).future);
                      final confirmed = (newMap[dateKey] ?? const <String>[]).contains(taskIdentifier) == desired;
                      if (confirmed) {
                        if (mounted) setState(() { overrides.remove(taskIdentifier); });
                      } else {
                        Future.microtask(() async {
                          await ref.refresh(completedTasksForWeekProvider(startOfWeek).future);
                          if (!mounted) return;
                          final recheck = ref.read(completedTasksForWeekProvider(startOfWeek)).maybeWhen(data: (m)=> m, orElse: ()=> const <String, List<String>>{});
                          final ok = (recheck[dateKey] ?? const <String>[]).contains(taskIdentifier) == desired;
                          if (ok) setState(() { overrides.remove(taskIdentifier); });
                        });
                      }
                    } catch (_) {
                      if (mounted) setState(() { overrides.remove(taskIdentifier); });
                    }
                    if(desired) {
                      ref.read(questNotifierProvider.notifier).userCompletedWeeklyPlanTask();
                      if(context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Plan görevi fethedildi: ${item.activity}')));
                      }
                    }
                  },
                ).animate().fadeIn(delay: (50 * index).ms).slideY(begin: .12, curve: Curves.easeOutCubic),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<_TaskAction?> _askAction(BuildContext context, String taskTitle) async {
    return showModalBottomSheet<_TaskAction>(
      context: context,
      backgroundColor: Theme.of(context).cardColor.withOpacity(0.95),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children:[
                Icon(Icons.play_circle_fill_rounded, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('Ne yapalım?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)))
              ]),
              const SizedBox(height: 8),
              Text("'$taskTitle' için bir aksiyon seç.", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: ()=> Navigator.of(context).pop(_TaskAction.startPomodoro),
                icon: const Icon(Icons.timer_outlined),
                label: const Text('Pomodoro Başlat'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: ()=> Navigator.of(context).pop(_TaskAction.completeNow),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Görevi Tamamla'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: ()=> Navigator.of(context).pop(null),
                child: const Text('Vazgeç'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _DaySummaryHeader extends StatelessWidget {
  final String dayLabel; final DateTime date; final int completed; final int total; final double progress;
  const _DaySummaryHeader({required this.dayLabel, required this.date, required this.completed, required this.total, required this.progress});
  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMM', 'tr_TR').format(date);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).cardColor.withOpacity(0.55),
        border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('$dayLabel • $dateStr', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Text('${(progress*100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.18),
              valueColor: AlwaysStoppedAnimation(progress >= 1 ? Colors.green : Theme.of(context).colorScheme.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text('$completed / $total görev', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class WeeklyOverviewCard extends ConsumerWidget {
  final WeeklyPlan weeklyPlan; final String userId; final DateTime startOfWeek;
  const WeeklyOverviewCard({super.key, required this.weeklyPlan, required this.userId, required this.startOfWeek});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);
    final dates = List.generate(7, (i)=> startOfWeek.add(Duration(days: i)));
    final todayIndex = today0.weekday - 1;
    final dateKeys = dates.map((d)=> DateFormat('yyyy-MM-dd').format(d)).toList();

    // Haftalık tamamlanan görevleri tek seferde oku
    final weeklyCompletedMap = ref.watch(completedTasksForWeekProvider(startOfWeek)).maybeWhen(
      data: (m) => m,
      orElse: () => const <String, List<String>>{},
    );

    final allDaily = weeklyPlan.plan;
    int totalTasks = 0; int completedTasks = 0; Map<String,int> dayTotals = {}; Map<String,int> dayCompleted = {};
    for (final d in allDaily) {
      final idx = ['Pazartesi','Salı','Çarşamba','Perşembe','Cuma','Cumartesi','Pazar'].indexOf(d.day);
      if (idx < 0) continue;
      final dk = dateKeys[idx];
      totalTasks += d.schedule.length;
      dayTotals[dk] = d.schedule.length;
      final completedList = weeklyCompletedMap[dk] ?? const <String>[];
      int compForDay = 0;
      for (final item in d.schedule) {
        final id = item.id;
        if (completedList.contains(id)) compForDay++;
      }
      completedTasks += compForDay;
      dayCompleted[dk] = compForDay;
    }
    final progress = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;
    final weekRange = '${DateFormat('d MMM', 'tr_TR').format(dates.first)} - ${DateFormat('d MMM', 'tr_TR').format(dates.last)}';

    return GestureDetector(
      onTap: () => _showWeekDetails(context, ref, dates, dateKeys, dayTotals, dayCompleted),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).cardColor.withOpacity(0.5),
          border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            SizedBox(
              height: 54, width: 54,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 5,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.18),
                  valueColor: AlwaysStoppedAnimation(progress>=1? Colors.green : Theme.of(context).colorScheme.primary),
                ),
                Text('${(progress*100).toStringAsFixed(0)}%', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Haftalık Plan', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(weekRange, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Text('$completedTasks / $totalTasks görev', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(7, (i){
                      final dk = dateKeys[i]; final total = dayTotals[dk] ?? 0; final done = dayCompleted[dk] ?? 0; final ratio = total==0?0.0: done/total;
                      final isToday = i == todayIndex;
                      return Expanded(
                        child: Container(
                          height: 6,
                          margin: EdgeInsets.only(right: i==6?0:4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: LinearGradient(
                              colors: [
                                (ratio>=1? Colors.green : Theme.of(context).colorScheme.primary).withOpacity(ratio==0 ? .15 : .85),
                                (ratio>=1? Colors.green : Theme.of(context).colorScheme.primary).withOpacity(ratio==0 ? .18 : 1),
                              ],
                            ),
                            border: isToday ? Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), width: 1) : null,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (totalTasks>0) Text(remainingLabel(completedTasks,totalTasks), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  String remainingLabel(int done, int total){
    if (total==0) return '-';
    final rem = total-done;
    if (rem==0) return 'Bitti';
    return 'Kalan $rem';
  }

  void _showWeekDetails(BuildContext context, WidgetRef ref, List<DateTime> dates, List<String> dateKeys, Map<String,int> dayTotals, Map<String,int> dayCompleted){
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor.withOpacity(0.9),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20,16,20,32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.insights_rounded, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Haftalık Detay', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              ...List.generate(7, (i){
                final dk = dateKeys[i]; final date = dates[i];
                final total = dayTotals[dk] ?? 0; final done = dayCompleted[dk] ?? 0; final ratio = total==0?0.0: done/total;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(width: 84, child: Text(DateFormat('E d MMM','tr_TR').format(date), style: Theme.of(context).textTheme.labelSmall)),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 6,
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation(ratio>=1? Colors.green : Theme.of(context).colorScheme.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(width: 54, child: Text('$done/$total', textAlign: TextAlign.end, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)))
                    ],
                  ),
                );
              })
            ],
          ),
        );
      },
    );
  }
}

class _EmptyDayView extends StatelessWidget {
  const _EmptyDayView({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.self_improvement_rounded, color: Theme.of(context).colorScheme.primary, size: 64),
          const SizedBox(height: 8),
          Text('Dinlenme Günü', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Zihinsel depoları doldur 🧘 yarın yeniden hücum.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _TaskTimelineTile extends StatelessWidget {
  final ScheduleItem item; final bool isCompleted; final bool isFirst; final bool isLast; final String dateKey; final VoidCallback onToggle;
  const _TaskTimelineTile({required this.item, required this.isCompleted, required this.isFirst, required this.isLast, required this.dateKey, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (isCompleted? Colors.green : Theme.of(context).colorScheme.surfaceContainerHighest).withOpacity(0.35)),
        gradient: LinearGradient(colors:[ (isCompleted? Colors.green : Theme.of(context).colorScheme.primary).withOpacity(0.08), Theme.of(context).cardColor.withOpacity(0.35)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle, color: (isCompleted? Colors.green : Theme.of(context).colorScheme.primary).withOpacity(0.18)),
                child: Icon(Icons.schedule_rounded, color: isCompleted? Colors.green : Theme.of(context).colorScheme.primary),
              ),
              if (!isLast) Container(width: 2, height: 24, color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3))
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.activity, style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: isCompleted? TextDecoration.lineThrough : TextDecoration.none,
                  color: isCompleted? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface,
                )),
                const SizedBox(height: 4),
                Text(item.time, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            icon: AnimatedSwitcher(
              duration: 250.ms,
              switchInCurve: Curves.elasticOut,
              child: Icon(isCompleted? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                key: ValueKey<bool>(isCompleted),
                color: isCompleted? Colors.green : Theme.of(context).colorScheme.surfaceContainerHighest,
                size: 28,
              ),
            ),
            onPressed: onToggle,
          )
        ],
      ),
    );
  }
}

enum _TaskAction { startPomodoro, completeNow }
