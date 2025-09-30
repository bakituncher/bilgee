// lib/features/home/widgets/dashboard_cards/weekly_plan_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/models/plan_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';
import 'dart:ui';

double _clamp01(num v) {
  if (v.isNaN) return 0.0;
  if (v < 0) return 0.0;
  if (v > 1) return 1.0;
  return v.toDouble();
}

final _selectedDayProvider = StateProvider.autoDispose<int>((ref) {
  int todayIndex = DateTime.now().weekday - 1;
  return todayIndex.clamp(0, 6);
});

class WeeklyPlanCard extends ConsumerWidget {
  const WeeklyPlanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planDoc = ref.watch(planProvider).value;
    final userId = ref.watch(userProfileProvider).value?.id;

    if (userId == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: .85),
            AppTheme.primaryColor.withValues(alpha: .55),
            AppTheme.cardColor.withValues(alpha: .40),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppTheme.lightSurfaceColor.withValues(alpha: .35), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.35), blurRadius: 18, offset: const Offset(0, 8))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: _PlanView(
          weeklyPlan: planDoc?.weeklyPlan != null ? WeeklyPlan.fromJson(planDoc!.weeklyPlan!) : null,
          userId: userId,
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: .12, curve: Curves.easeOut);
  }
}

class _PlanView extends ConsumerWidget {
  final WeeklyPlan? weeklyPlan;
  final String userId;
  final List<String> _daysOfWeek = const ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
  final List<String> _daysOfWeekShort = const ['PZT', 'SAL', 'ÇAR', 'PER', 'CUM', 'CMT', 'PAZ'];

  const _PlanView({required this.weeklyPlan, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (weeklyPlan == null || weeklyPlan!.plan.isEmpty) return const _EmptyStateCard();
    final selectedDayIndex = ref.watch(_selectedDayProvider);
    final dayName = _daysOfWeek[selectedDayIndex];
    final dailyPlan = weeklyPlan!.plan.firstWhere((p) => p.day == dayName, orElse: () => DailyPlan(day: dayName, schedule: []));

    // Normalize edilmiş hafta başlangıcı (00:00)
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final startOfWeek = dayStart.subtract(Duration(days: dayStart.weekday - 1));
    final dateForTab = startOfWeek.add(Duration(days: selectedDayIndex));
    final dateKey = DateFormat('yyyy-MM-dd').format(dateForTab);

    // Haftalık tamamlanan görevleri tek seferde oku (normalize edilmiş parametre)
    final weeklyCompletedMap = ref.watch(completedTasksForWeekProvider(startOfWeek)).maybeWhen(
      data: (m) => m,
      orElse: () => const <String, List<String>>{},
    );

    return Column(children: [
      _HeaderBar(dateForTab: dateForTab, weeklyPlan: weeklyPlan!, userId: userId, completedByDate: weeklyCompletedMap),
      _DaySelector(days: _daysOfWeekShort),
      const SizedBox(height: 8),
      Expanded(
        child: AnimatedSwitcher(
          duration: 300.ms,
          switchInCurve: Curves.easeOut,
          child: dailyPlan.schedule.isEmpty
              ? const _RestDay()
              : ListView.separated(
                  key: PageStorageKey<String>(dayName),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: dailyPlan.schedule.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final scheduleItem = dailyPlan.schedule[index];
                    return _TaskTile(
                      key: ValueKey('$dateKey-${scheduleItem.time}-${scheduleItem.activity}'),
                      item: scheduleItem,
                      dateForTile: dateForTab,
                      dateKey: dateKey,
                      userId: userId,
                      completedByDate: weeklyCompletedMap,
                    ).animate().fadeIn(delay: (40 * index).ms).slideX(begin: .15, curve: Curves.easeOutCubic);
                  },
                ),
        ),
      ),
    ]);
  }
}

class _HeaderBar extends ConsumerWidget {
  final DateTime dateForTab; final WeeklyPlan weeklyPlan; final String userId; final Map<String, List<String>> completedByDate;
  const _HeaderBar({required this.dateForTab, required this.weeklyPlan, required this.userId, required this.completedByDate});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int total=0; int done=0;
    final now=DateTime.now();
    final sow=now.subtract(Duration(days: now.weekday-1));
    for(int i=0;i<weeklyPlan.plan.length;i++){
      final dp=weeklyPlan.plan[i];
      total+=dp.schedule.length;
      final d=sow.add(Duration(days:i));
      final dk = DateFormat('yyyy-MM-dd').format(d);
      final completedList = completedByDate[dk] ?? const <String>[];
      for (final s in dp.schedule) {
        final id='${s.time}-${s.activity}';
        if (completedList.contains(id)) done++;
      }
    }
    final double ratio = total==0?0.0: done/total;
    return Container(
      padding: const EdgeInsets.fromLTRB(20,18,20,16),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
        gradient: LinearGradient(colors:[AppTheme.secondaryColor.withOpacity(.18), AppTheme.secondaryColor.withOpacity(.04)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children:[
        Stack(alignment: Alignment.center, children:[
          SizedBox(height:58,width:58,child:CircularProgressIndicator(strokeWidth:6,value:_clamp01(ratio),backgroundColor:AppTheme.lightSurfaceColor.withOpacity(.35),valueColor:AlwaysStoppedAnimation(ratio>=.75?AppTheme.successColor:AppTheme.secondaryColor)) ),
          Column(mainAxisSize: MainAxisSize.min,children:[Text('${(ratio*100).round()}%',style: const TextStyle(fontWeight: FontWeight.bold,fontSize:14)), const Text('Hafta',style: TextStyle(fontSize:10,color:AppTheme.secondaryTextColor))])
        ]),
        const SizedBox(width:16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          Text('Haftalık Plan', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height:4),
          Text(DateFormat.yMMMMd('tr').format(dateForTab), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondaryTextColor)),
          const SizedBox(height:6),
          ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(minHeight:6,value:_clamp01(ratio),backgroundColor:AppTheme.lightSurfaceColor.withOpacity(.25), valueColor:AlwaysStoppedAnimation(ratio>=.75?AppTheme.successColor:AppTheme.secondaryColor)))
        ])),
        IconButton(tooltip:'Planı Aç', onPressed: ()=> context.go('/home/weekly-plan'), icon: const Icon(Icons.open_in_new_rounded,color:AppTheme.secondaryColor))
      ]),
    );
  }
}

class _RestDay extends StatelessWidget { const _RestDay(); @override Widget build(BuildContext context){ return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[ const Icon(Icons.self_improvement_rounded,size:48,color:AppTheme.secondaryColor), const SizedBox(height:12), Text('Dinlenme Günü', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height:6), Text('Zihinsel depoları doldur – yarın yeniden hücum.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor)) ]).animate().fadeIn(duration: 400.ms)); } }

class _DaySelector extends ConsumerWidget {
  final List<String> days;
  const _DaySelector({required this.days});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDayIndex = ref.watch(_selectedDayProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(days.length, (index) {
            final isSelected = selectedDayIndex == index;
            return GestureDetector(
              onTap: () => ref.read(_selectedDayProvider.notifier).state = index,
              child: AnimatedContainer(
                duration: 250.ms,
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.secondaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  days[index],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  final ScheduleItem item;
  final String dateKey;
  final String userId;
  final DateTime dateForTile;
  final Map<String, List<String>> completedByDate;

  const _TaskTile({super.key, required this.item, required this.dateKey, required this.userId, required this.dateForTile, required this.completedByDate});

  IconData _getIconForTaskType(String type) {
    switch (type.toLowerCase()) {
      case 'study': return Icons.book_rounded;
      case 'practice': case 'routine': return Icons.edit_note_rounded;
      case 'test': return Icons.quiz_rounded;
      case 'review': return Icons.history_edu_rounded;
      case 'break': return Icons.self_improvement_rounded;
      default: return Icons.shield_moon_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskIdentifier = '${item.time}-${item.activity}';
    final completedList = completedByDate[dateKey] ?? const <String>[];
    final isCompleted = completedList.contains(taskIdentifier);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => isCompleted ? null : ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Görevi tamamlamak için butona dokun.'))),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: (isCompleted? AppTheme.successColor: AppTheme.lightSurfaceColor).withOpacity(.35), width: 1),
            gradient: LinearGradient(colors:[ (isCompleted? AppTheme.successColor: AppTheme.secondaryColor).withOpacity(.08), AppTheme.cardColor.withOpacity(.35)], begin: Alignment.topLeft,end: Alignment.bottomRight),
          ),
          padding: const EdgeInsets.fromLTRB(14,12,6,12),
          child: Row(children:[
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(shape: BoxShape.circle, color: (isCompleted? AppTheme.successColor: AppTheme.secondaryColor).withOpacity(.18)), child: Animate(target: isCompleted?1:0, effects:[ScaleEffect(duration:300.ms, curve: Curves.easeOutBack)], child: Icon(_getIconForTaskType(item.type), color: isCompleted? AppTheme.successColor: AppTheme.secondaryColor))),
            const SizedBox(width:14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              Text(item.activity, maxLines:2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize:15,fontWeight:FontWeight.w600,letterSpacing:.3,color: isCompleted? AppTheme.secondaryTextColor: Colors.white, decoration: isCompleted? TextDecoration.lineThrough: TextDecoration.none, decorationColor: AppTheme.secondaryTextColor)),
              const SizedBox(height:4),
              Row(children:[ Icon(Icons.schedule,size:13,color:AppTheme.secondaryTextColor.withOpacity(.9)), const SizedBox(width:4), Text(item.time, style: const TextStyle(color: AppTheme.secondaryTextColor,fontSize:11)) ])
            ])),
            IconButton(
              icon: AnimatedSwitcher(duration:250.ms, switchInCurve: Curves.elasticOut, child: Icon(isCompleted? Icons.check_circle_rounded: Icons.radio_button_unchecked_rounded, key: ValueKey<bool>(isCompleted), color: isCompleted? AppTheme.successColor: AppTheme.lightSurfaceColor, size:30)),
              onPressed: () async {
                await ref.read(firestoreServiceProvider).updateDailyTaskCompletion(
                  userId: userId,
                  dateKey: dateKey,
                  task: taskIdentifier,
                  isCompleted: !isCompleted,
                );
                // Normalize edilmiş hafta başlangıcı ile weekly provider’ı yenile ve bekle
                final now = DateTime.now();
                final dayStart = DateTime(now.year, now.month, now.day);
                final startOfWeek = dayStart.subtract(Duration(days: dayStart.weekday - 1));
                await ref.refresh(completedTasksForWeekProvider(startOfWeek).future);
                // İsteğe bağlı: günlük provider kullanan diğer yerler için
                ref.invalidate(completedTasksForDateProvider(dateForTile));
                if(!isCompleted){
                  final questId='schedule_${dateKey}_${taskIdentifier.hashCode}';
                  ref.read(questNotifierProvider.notifier).updateQuestProgressById(questId);
                  if(context.mounted){
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Plan görevi fethedildi: ${item.activity}')));
                  }
                }
              },
            )
          ]),
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome, color: AppTheme.secondaryColor, size: 40),
          const SizedBox(height: 16),
          Text('Kader parşömenin mühürlenmeyi bekliyor.',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Stratejik planını oluşturarak görevlerini buraya yazdır.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('${AppRoutes.aiHub}/${AppRoutes.strategicPlanning}'),
            child: const Text('Stratejini Oluştur'),
          )
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}