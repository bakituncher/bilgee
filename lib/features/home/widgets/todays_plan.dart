// lib/features/home/widgets/todays_plan.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/models/plan_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/core/navigation/app_routes.dart';

import 'dashboard_cards/mission_card.dart';
import 'dashboard_cards/weekly_plan_card.dart';


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
      const WeeklyPlanCard(),
    ];

    if (isPlanBehind) {
      final weeklyPlanCard = pages.removeAt(1);
      pages.insert(0, weeklyPlanCard);
    }

    return Column(
      children: [
        SizedBox(
          height: 400,
          child: PageView(
            controller: _pageController,
            padEnds: false,
            children: pages,
          ),
        ),
        const SizedBox(height: 12),
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
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: _currentPage == index ? 24 : 8,
          decoration: BoxDecoration(
            color: _currentPage == index ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
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
        elevation: isDark ? 6 : 5,
        shadowColor: isDark 
          ? Colors.black.withOpacity(0.35)
          : Theme.of(context).colorScheme.primary.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: isDark 
              ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.25)
              : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35),
            width: 1.5,
          ),
        ),
        child: Container(
          height: 400,
          padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 26.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: isDark
                ? [
                    Theme.of(context).colorScheme.primary.withOpacity(0.12),
                    Theme.of(context).cardColor,
                    Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.08),
                  ]
                : [
                    Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    Theme.of(context).cardColor,
                    Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.05),
                  ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(isDark ? 0.4 : 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary, size: 50),
              ),
              const SizedBox(height: 20),
              Text(
                'Yeni Bir Hafta, Yeni Bir Strateji!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Geçen haftanın planı tamamlandı. Performansını güncelleyerek bu hafta için yeni bir zafer yolu çizelim.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant, 
                  height: 1.6,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => context.go('${AppRoutes.aiHub}/${AppRoutes.strategicPlanning}'),
                icon: const Icon(Icons.insights_rounded, size: 22),
                label: const Text('Yeni Stratejini Oluştur'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  elevation: isDark ? 6 : 4,
                ),
              )
            ],
          ),
        ),
      ).animate().fadeIn(duration: 500.ms, curve: Curves.easeOutCubic).scale(begin: const Offset(0.96, 0.96), curve: Curves.easeOutCubic),
    );
  }
}