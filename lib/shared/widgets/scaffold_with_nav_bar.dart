// lib/shared/widgets/scaffold_with_nav_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/features/onboarding/providers/tutorial_provider.dart';
import 'package:taktik/features/onboarding/widgets/tutorial_overlay.dart';
import 'package:taktik/features/onboarding/widgets/tutorial_completion_celebration.dart';
import 'package:taktik/features/onboarding/models/tutorial_step.dart';
import 'package:taktik/features/quests/logic/quest_completion_notifier.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';
import 'package:taktik/shared/widgets/quest_completion_celebration.dart';
import 'package:taktik/data/models/plan_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/shared/constants/highlight_keys.dart';
import 'package:taktik/shared/widgets/side_panel_drawer.dart';

// Drawer'ı başka ekranlardan açmak için kök Scaffold anahtarı
final GlobalKey<ScaffoldState> rootScaffoldKey = GlobalKey<ScaffoldState>();

class ScaffoldWithNavBar extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // QuestNotifier'ı canlı tut (arkaplan olaylarını dinlesin)
    ref.watch(questNotifierProvider);
    final List<TutorialStep> tutorialSteps = [
      TutorialStep(
        title: "Taktik'e Hoş Geldin! 🎯",
        text: "Merhaba! Ben senin kişisel başarı koçunum. Sana uygulamamızın en güçlü özelliklerini tanıtacağım ve başarıya giden yolda rehberlik edeceğim. Hazır mısın?",
        buttonText: "Hadi Başlayalım!",
      ),
      TutorialStep(
        highlightKey: todaysPlanKey,
        title: "📊 Komuta Merkezi",
        text: "İşte karşında ana gösterge panelin! Burada günlük görevlerini, haftalık çalışma planını ve performans istatistiklerini görebilirsin. Başarıya giden yolda her şey burada takip altında!",
        buttonText: "Anladım, Devam!",
        requiredScreenIndex: 0,
      ),
      TutorialStep(
        highlightKey: addTestKey,
        title: "📝 Deneme Ekle",
        text: "Her çözdüğün denemeyi buradan ekle! Yapay zeka, sonuçlarını analiz ederek senin için özel stratejiler geliştirecek ve zayıf yönlerini güçlendirecek. Ne kadar çok veri, o kadar akıllı koçluk!",
        buttonText: "Harika! 🚀",
        requiredScreenIndex: 0,
      ),
      TutorialStep(
        highlightKey: coachKey,
        title: "🎓 Koçluk Merkezi",
        text: "Deneme sonuçlarını girdikten sonra buradan yapay zeka koçunla konuşabilirsin. Sana özel ders çalışma stratejileri, konu anlatımları ve motivasyon desteği alabilirsin!",
        buttonText: "Süper! 💪",
        isNavigational: true,
        requiredScreenIndex: 0,
      ),
      TutorialStep(
        highlightKey: aiHubFabKey,
        title: "🤖 TaktikAI Merkezi",
        text: "Burası sihrin gerçekleştiği yer! AI asistanın ile stratejik planlama yap, zayıf konularını çalış, sorularına cevap bul. 7/24 yanında olan kişisel öğretmenin!",
        buttonText: "Muhteşem! ✨",
        requiredScreenIndex: 1,
      ),
      TutorialStep(
        highlightKey: arenaKey,
        title: "🏆 Arena - Rekabet Et",
        text: "Diğer kullanıcılarla yarış! Lider tablosundaki yerini gör, başarılarını karşılaştır ve motivasyonunu her zaman yüksek tut. En iyiler arasına sen de katıl!",
        buttonText: "Rekabete Hazırım! 🔥",
        isNavigational: true,
        requiredScreenIndex: 1,
      ),
      TutorialStep(
        highlightKey: profileKey,
        title: "👤 Profil & İstatistikler",
        text: "Burada başarı hikayeni yaz! Kazandığın rozetleri, tamamladığın görevleri ve genel performans istatistiklerini incele. İlerleme kaydını buradan takip et.",
        buttonText: "Profilime Bakalım! 📈",
        isNavigational: true,
        requiredScreenIndex: 3,
      ),
      TutorialStep(
        title: "🎉 Hazırsın!",
        text: "Tebrikler! Artık Taktik'in tüm özelliklerini biliyorsun. Başarı yolculuğunda her adımda yanındayız. Unutma: Düzenli çalışma + Akıllı strateji = Kesin başarı! Şimdi harekete geç ve hedefe ulaş! 💯",
        buttonText: "Başarıya Doğru! 🚀",
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
            final completionState = ref.watch(questCompletionProvider);
            final completedQuest = completionState.completedQuest;

            ref.listen<QuestCompletionState>(questCompletionProvider, (previous, next) {
              final nextQuest = next.completedQuest;
              if (nextQuest != null) {
                Future.delayed(3.seconds, () {
                  if (ref.read(questCompletionProvider).completedQuest == nextQuest) {
                    ref.read(questCompletionProvider.notifier).clear();
                  }
                });
              }
            });

            final showTutorialCelebration = ref.watch(showTutorialCelebrationProvider);

            return Stack(
              children: [
                Scaffold(
                  key: rootScaffoldKey,
                  resizeToAvoidBottomInset: false,
                  body: SafeArea(
                    top: false,
                    bottom: true,
                    child: Builder(
                      builder: (ctx){
                        final completedQuest = ref.watch(questCompletionProvider).completedQuest;
                        if(completedQuest != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_){
                            ScaffoldMessenger.of(ctx).clearSnackBars();
                          });
                        }
                        return navigationShell;
                      },
                    ),
                  ),
                  extendBody: true,
                  drawer: const SidePanelDrawer(),
                  drawerScrimColor: Theme.of(context).colorScheme.surface.withOpacity(0.6),
                  drawerEdgeDragWidth: 48,
                  floatingActionButton: FloatingActionButton(
                    key: aiHubFabKey,
                    heroTag: 'main_fab',
                    onPressed: () => _onTap(2, ref, tutorialSteps),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    elevation: 4.0,
                    shape: const CircleBorder(),
                    child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.onPrimary, size: 28),
                  ).animate().scale(delay: 500.ms),
                  floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
                  bottomNavigationBar: BottomAppBar(
                    // shape: const CircularNotchedRectangle(),
                    // notchMargin: 10.0,
                    padding: EdgeInsets.zero,
                    height: 70,
                    color: Theme.of(context).cardColor.withOpacity(0.95),
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
                if (showTutorialCelebration)
                  TutorialCompletionCelebration(
                    onDismiss: () {
                      ref.read(showTutorialCelebrationProvider.notifier).state = false;
                    },
                  ),
                if (completedQuest != null && !shouldShowTutorial)
                  QuestCompletionCelebration(completedQuest: completedQuest),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return IconButton(
      key: key,
      icon: Icon(icon, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant, size: 28),
      onPressed: () => _onTap(index, ref, steps),
      tooltip: label,
      splashColor: colorScheme.primary.withOpacity(0.2),
      highlightColor: colorScheme.primary.withOpacity(0.1),
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
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.85),
                ],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Material(
                    color: Theme.of(context).cardColor.withOpacity(0.95),
                    elevation: 12,
                    borderRadius: BorderRadius.circular(28),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events_rounded, size: 72, color: Theme.of(context).colorScheme.primary)
                              .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                          const SizedBox(height: 16),
                          Text('Haftalık Plan Tamamlandı!', textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),),
                          const SizedBox(height: 12),
                          Text('Planındaki tüm görevleri bitirdin. Stratejik disiplinin mükemmel! Yeni haftada sınırları daha da zorla.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),),
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