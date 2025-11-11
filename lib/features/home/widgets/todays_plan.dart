// lib/features/home/widgets/todays_plan.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/models/plan_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/core/navigation/app_routes.dart';

import 'dashboard_cards/mission_card.dart';
import 'dashboard_cards/weekly_plan_card_compact.dart';


class TodaysPlan extends ConsumerStatefulWidget {
  const TodaysPlan({super.key});

  @override
  ConsumerState<TodaysPlan> createState() => _TodaysPlanState();
}

class _TodaysPlanState extends ConsumerState<TodaysPlan> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
    _pageController.addListener(() {
      if (_pageController.page?.round() != _currentPage) {
        if(mounted){
          setState(() {
            _currentPage = _pageController.page!.round();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).value;
    final planDoc = ref.watch(planProvider).value;

    if (user == null) {
      return const SizedBox(height: 420);
    }

    final weeklyPlan = planDoc?.weeklyPlan != null ? WeeklyPlan.fromJson(planDoc!.weeklyPlan!) : null;

    if (weeklyPlan != null && DateTime.now().difference(weeklyPlan.creationDate).inDays >= 7) {
      return const _NewPlanPromptCard();
    }

    int totalTasksSoFar = 0;
    int completedTasksSoFar = 0;
    bool isPlanBehind = false;

    if (weeklyPlan != null) {
      final today = DateTime.now();
      final currentDayIndex = today.weekday - 1;
      final startOfWeek = today.subtract(Duration(days: currentDayIndex));

      final relevantDays = weeklyPlan.plan.take(currentDayIndex + 1).toList();
      totalTasksSoFar = relevantDays.expand((day) => day.schedule).length;

      if (totalTasksSoFar > 0) {
        for (int i = 0; i <= currentDayIndex; i++) {
          if (i >= weeklyPlan.plan.length) continue;

          final dailyPlan = weeklyPlan.plan[i];
          final dateForDay = startOfWeek.add(Duration(days: i));
          final completedForThisDay = ref.watch(completedTasksForDateProvider(dateForDay)).maybeWhen(data: (list)=> list, orElse: ()=> const <String>[]);

          for (var task in dailyPlan.schedule) {
            final taskIdentifier = '${task.time}-${task.activity}';
            if (completedForThisDay.contains(taskIdentifier)) {
              completedTasksSoFar++;
            }
          }
        }
        isPlanBehind = (completedTasksSoFar / totalTasksSoFar) < 0.5;
      }
    }

    List<Widget> pages = [
      const MissionCard(),
      const WeeklyPlanCardCompact(),
    ];

    if (isPlanBehind) {
      final weeklyPlanCard = pages.removeAt(1);
      pages.insert(0, weeklyPlanCard);
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView(
            controller: _pageController,
            padEnds: false,
            children: pages,
          ),
        ),
        const SizedBox(height: 6),
        _buildPageIndicator(pages.length),
      ],
    );
  }

  Widget _buildPageIndicator(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        return AnimatedContainer(
          duration: 300.ms,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 6,
          width: _currentPage == index ? 18 : 6,
          decoration: BoxDecoration(
            color: _currentPage == index ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _NewPlanPromptCard extends StatelessWidget {
  const _NewPlanPromptCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        elevation: isDark ? 6 : 4,
        shadowColor: isDark
            ? Colors.black.withOpacity(0.4)
            : Theme.of(context).colorScheme.primary.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark
                ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                : Colors.transparent,
          ),
        ),
        child: Container(
          height: 180,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary, size: 32),
              const SizedBox(height: 8),
              Text(
                'Yeni Hafta, Yeni Strateji!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Bu hafta için taze bir plan çıkaralım.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.3, fontSize: 11),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => context.go('${AppRoutes.aiHub}/${AppRoutes.strategicPlanning}'),
                icon: const Icon(Icons.insights_rounded, size: 18),
                label: const Text('Plan Oluştur', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                ),
              )
            ],
          ),
        ),
      ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.95, 0.95)),
    );
  }
}