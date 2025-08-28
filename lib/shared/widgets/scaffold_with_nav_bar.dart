// lib/shared/widgets/scaffold_with_nav_bar.dart
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bilge_ai/features/onboarding/providers/tutorial_provider.dart';
import 'package:bilge_ai/features/onboarding/widgets/tutorial_overlay.dart';
import 'package:bilge_ai/features/onboarding/models/tutorial_step.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'package:bilge_ai/features/quests/logic/quest_completion_notifier.dart';
import 'package:bilge_ai/shared/widgets/quest_completion_toast.dart';
import 'package:bilge_ai/data/models/plan_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/shared/constants/highlight_keys.dart';

class ScaffoldWithNavBar extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TutorialStep> tutorialSteps = [
      TutorialStep(
        title: "Karargaha Hoş Geldin!",
        text: "Ben Bilge Baykuş! Zafer yolundaki en büyük destekçin ben olacağım. Sana hızlıca komuta merkezini tanıtayım.",
      ),
      TutorialStep(
        highlightKey: todaysPlanKey,
        title: "Burası Harekat Merkezin",
        text: "Günlük görevlerin, haftalık planın ve performans raporun... En kritik bilgiler burada. Sağa kaydırarak diğer kartları görebilirsin!",
        requiredScreenIndex: 0,
      ),
      TutorialStep(
        highlightKey: addTestKey,
        title: "Veri Güçtür!",
        text: "Buraya eklediğin her deneme, yapay zekanın seni daha iyi tanımasını ve sana özel stratejiler üretmesini sağlar! Hadi devam edelim.",
        requiredScreenIndex: 0,
      ),
      TutorialStep(
        highlightKey: coachKey,
        title: "Bilgi Galaksisi",
        text: "Şimdi en güçlü silahımızın olduğu yer, çözdüğün testlerin sonuçlarını bu kısıma girerek yapay zekanın sana özel koçluk yapmasını sağlayabilirsin.",
        buttonText: "Harika! ",
        isNavigational: true,
        requiredScreenIndex: 0,
      ),
      TutorialStep(
        highlightKey: aiHubFabKey,
        title: "İşte BilgeAI Çekirdeği!",
        text: "Burası sihrin gerçekleştiği yer! Buradan kişisel zafer planını oluşturabilir, en zayıf konularına özel çalışmalar yapabilirsin.",
        requiredScreenIndex: 1,
      ),
      TutorialStep(
        highlightKey: arenaKey,
        title: "Savaşçılar Arenası",
        text: "Diğer savaşçılar arasındaki yerini gör ve rekabetin tadını çıkar! Hadi Arena sekmesine dokun.",
        buttonText: "Arenayı Ziyaret Et!",
        isNavigational: true,
        requiredScreenIndex: 1,
      ),
      TutorialStep(
        highlightKey: profileKey,
        title: "Komuta Merkezin",
        text: "Son olarak burası senin profilin. Madalyalarını ve genel istatistiklerini buradan takip edebilirsin. Profil sekmesine dokun.",
        buttonText: "Profilime Gidelim!",
        isNavigational: true,
        requiredScreenIndex: 3,
      ),
      TutorialStep(
        title: "Keşif Turu Bitti!",
        text: "Harika! Artık karargahı tanıyorsun. Unutma, zafer azim, strateji ve doğru rehberlikle kazanılır. Ben her zaman buradayım!",
        buttonText: "Harika, Başlayalım!",
        requiredScreenIndex: 4,
      ),
    ];

    return ProviderScope(
      overrides: [
        tutorialProvider.overrideWith((ref) => TutorialNotifier(tutorialSteps.length, navigationShell, ref)),
      ],
      child: Consumer(
          builder: (context, ref, child) {
            final currentStepIndex = ref.watch(tutorialProvider);
            final shouldShowTutorial = currentStepIndex != null;
            final completedQuest = ref.watch(questCompletionProvider);

            ref.listen<Quest?>(questCompletionProvider, (previous, next) {
              if (next != null) {
                Future.delayed(3.seconds, () {
                  if (ref.read(questCompletionProvider) == next) {
                    ref.read(questCompletionProvider.notifier).clear();
                  }
                });
              }
            });

            return Stack(
              children: [
                Scaffold(
                  resizeToAvoidBottomInset: false,
                  body: Builder(
                    builder: (ctx){
                      final completedQuest = ref.watch(questCompletionProvider);
                      if(completedQuest != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_){
                          ScaffoldMessenger.of(ctx).clearSnackBars();
                        });
                      }
                      return navigationShell;
                    },
                  ),
                  extendBody: true,
                  floatingActionButton: FloatingActionButton(
                    key: aiHubFabKey,
                    heroTag: 'main_fab',
                    onPressed: () => _onTap(2, ref, tutorialSteps),
                    backgroundColor: AppTheme.secondaryColor,
                    child: const Icon(Icons.auto_awesome, color: AppTheme.primaryColor, size: 28),
                    elevation: 4.0,
                    shape: const CircleBorder(),
                  ).animate().scale(delay: 500.ms),
                  floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
                  bottomNavigationBar: BottomAppBar(
                    // shape: const CircularNotchedRectangle(),
                    // notchMargin: 10.0,
                    padding: EdgeInsets.zero,
                    height: 70,
                    color: AppTheme.cardColor.withOpacity(0.95),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(context, icon: Icons.dashboard_rounded, label: 'Panel', index: 0, key: null, ref: ref, steps: tutorialSteps),
                        _buildNavItem(context, icon: Icons.school_rounded, label: 'Galaksi', index: 1, key: coachKey, ref: ref, steps: tutorialSteps),
                        const SizedBox(width: 56),
                        _buildNavItem(context, icon: Icons.military_tech_rounded, label: 'Arena', index: 3, key: arenaKey, ref: ref, steps: tutorialSteps),
                        _buildNavItem(context, icon: Icons.person_rounded, label: 'Profil', index: 4, key: profileKey, ref: ref, steps: tutorialSteps),
                      ],
                    ),
                  ),
                ),
                if (shouldShowTutorial)
                  TutorialOverlay(steps: tutorialSteps),
                if (completedQuest != null && !shouldShowTutorial)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 80.0),
                      child: QuestCompletionToast(completedQuest: completedQuest),
                    ),
                  ),
                Consumer(builder: (context, r, _) {
                  final showWeeklyPopup = r.watch(weeklyPlanCompletionProvider);
                  if(!showWeeklyPopup) return const SizedBox.shrink();
                  return _WeeklyPlanVictoryOverlay(onDismiss: () async {
                    r.read(_weeklyPlanPopupShownProvider.notifier).state = true;
                    final user = r.read(userProfileProvider).value;
                    if(user!=null) {
                      await r.read(firestoreServiceProvider).usersCollection.doc(user.id).update({'weeklyPlanCompletedAt': Timestamp.now()});
                    }
                  });
                }),
              ],
            );
          }
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, {required IconData icon, required String label, required int index, required GlobalKey? key, required WidgetRef ref, required List<TutorialStep> steps}) {
    final isSelected = navigationShell.currentIndex == index;
    return IconButton(
      key: key,
      icon: Icon(icon, color: isSelected ? AppTheme.secondaryColor : AppTheme.secondaryTextColor, size: 28),
      onPressed: () => _onTap(index, ref, steps),
      tooltip: label,
      splashColor: AppTheme.secondaryColor.withOpacity(0.2),
      highlightColor: AppTheme.secondaryColor.withOpacity(0.1),
    );
  }

  void _onTap(int index, WidgetRef ref, List<TutorialStep> tutorialSteps) {
    final tutorialNotifier = ref.read(tutorialProvider.notifier);
    final currentStepIndex = ref.read(tutorialProvider);

    if (currentStepIndex != null) {
      if (currentStepIndex >= tutorialSteps.length) return;
      final step = tutorialSteps[currentStepIndex];
      if (step.isNavigational) {
        if ( (currentStepIndex == 3 && index == 1) ||
            (currentStepIndex == 5 && index == 3) ||
            (currentStepIndex == 6 && index == 4) ) {
          tutorialNotifier.next();
        }
      }
      return;
    }

    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

final _weeklyPlanPopupShownProvider = StateProvider<bool>((_) => false);
final weeklyPlanCompletionProvider = Provider<bool>((ref){
  final user = ref.watch(userProfileProvider).value;
  final planDoc = ref.watch(planProvider).value;
  final planMap = planDoc?.weeklyPlan;

  if(user == null || planMap == null) return false;
  final alreadyShown = ref.watch(_weeklyPlanPopupShownProvider);
  if(alreadyShown) return false;
  try {
    final weekly = WeeklyPlan.fromJson(planMap);
    DateTime startOfWeek(DateTime d)=> d.subtract(Duration(days: d.weekday-1));
    String dateKey(DateTime d) => '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    final now = DateTime.now();
    final thisWeekStart = startOfWeek(now);
    final dates = List.generate(7, (i) => thisWeekStart.add(Duration(days: i)));

    // Haftalık toplu okuma: tek seferde tüm günlerin tamamlananları
    final weekMap = ref.watch(completedTasksForWeekProvider(thisWeekStart))
        .maybeWhen(data: (m)=> m, orElse: ()=> const <String, List<String>>{});

    int planned = 0; int completed = 0;
    for(int i=0;i<weekly.plan.length;i++){
      final dp = weekly.plan[i];
      planned += dp.schedule.length;
      final dayDate = dates[i];
      final completedList = weekMap[dateKey(dayDate)] ?? const <String>[];
      int comp = 0;
      for (final s in dp.schedule) {
        final id='${s.time}-${s.activity}';
        if (completedList.contains(id)) comp++;
      }
      completed += comp;
    }
    if(planned>0 && completed>=planned) {
      if(user.weeklyPlanCompletedAt == null) return true;
      final saved = user.weeklyPlanCompletedAt!.toDate();
      if(startOfWeek(saved).isBefore(thisWeekStart)) return true;
    }
    return false;
  } catch(_){ return false; }
});

class _WeeklyPlanVictoryOverlay extends StatelessWidget {
  final VoidCallback onDismiss;
  const _WeeklyPlanVictoryOverlay({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: AnimatedOpacity(
          opacity: 1,
          duration: const Duration(milliseconds: 300),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.6), Colors.black.withOpacity(0.85)],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Material(
                    color: AppTheme.cardColor.withOpacity(0.95),
                    elevation: 12,
                    borderRadius: BorderRadius.circular(28),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events_rounded, size: 72, color: AppTheme.secondaryColor)
                              .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                          const SizedBox(height: 16),
                          Text('Haftalık Plan Tamamlandı!', textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),),
                          const SizedBox(height: 12),
                          Text('Planındaki tüm görevleri bitirdin. Stratejik disiplinin mükemmel! Yeni haftada sınırları daha da zorla.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor),),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: onDismiss,
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Harika!'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}