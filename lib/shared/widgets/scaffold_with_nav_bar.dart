// lib/shared/widgets/scaffold_with_nav_bar.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

    return Consumer(
        builder: (context, ref, child) {
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
                floatingActionButton: _AnimatedBunnyButton(
                  key: aiHubFabKey,
                  isActive: navigationShell.currentIndex == 2,
                  onTap: () => navigationShell.goBranch(
                    2,
                    initialLocation: 2 == navigationShell.currentIndex,
                  ),
                ).animate().scale(delay: 500.ms, curve: Curves.easeOutBack),
                floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
                bottomNavigationBar: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withOpacity(0.95),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: BottomAppBar(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    height: 72,
                    elevation: 0,
                    color: Colors.transparent,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(context, icon: Icons.dashboard_rounded, index: 0, ref: ref),
                        _buildNavItem(context, icon: Icons.school_rounded, index: 1, ref: ref),
                        const SizedBox(width: 72),
                        _buildNavItem(context, icon: Icons.military_tech_rounded, index: 3, ref: ref),
                        _buildNavItem(context, icon: Icons.person_rounded, index: 4, ref: ref),
                      ],
                    ),
                  ),
                ),
              ),
              if (completedQuest != null)
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
    );
  }

  Widget _buildNavItem(BuildContext context, {required IconData icon, required int index, required WidgetRef ref}) {
    final isSelected = navigationShell.currentIndex == index;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          customBorder: const CircleBorder(),
          splashColor: colorScheme.primary.withOpacity(0.2),
          highlightColor: colorScheme.primary.withOpacity(0.1),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                ? colorScheme.primary.withOpacity(0.15)
                : Colors.transparent,
              border: isSelected
                ? Border.all(
                    color: colorScheme.primary.withOpacity(0.3),
                    width: 1.5,
                  )
                : null,
            ),
            child: Center(
              child: Icon(
                icon,
                color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant.withOpacity(0.7),
                size: isSelected ? 28 : 26,
              ),
            ),
          ),
        ),
      ),
    ).animate(
      target: isSelected ? 1 : 0,
    ).scale(
      begin: const Offset(0.95, 0.95),
      end: const Offset(1.0, 1.0),
      duration: 200.ms,
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

class _AnimatedBunnyButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isActive;

  const _AnimatedBunnyButton({
    super.key,
    required this.onTap,
    this.isActive = false,
  });

  @override
  State<_AnimatedBunnyButton> createState() => _AnimatedBunnyButtonState();
}

class _AnimatedBunnyButtonState extends State<_AnimatedBunnyButton> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  bool _showShimmer = false;
  bool _wasActive = false; // Önceki aktif durumunu takip et

  @override
  void initState() {
    super.initState();
    _wasActive = widget.isActive;
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _shimmerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showShimmer = false;
        });
      }
    });
  }

  @override
  void didUpdateWidget(_AnimatedBunnyButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Aktif durumu değiştiyse ve şimdi aktif olduysa shimmer göster
    if (!_wasActive && widget.isActive) {
      setState(() {
        _showShimmer = true;
      });
      _shimmerController.forward(from: 0);
    }

    _wasActive = widget.isActive;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _scaleController.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = widget.isActive;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: ClipOval(
              child: _showShimmer
                  ? AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isActive
                              ? [
                                  colorScheme.primary,
                                  colorScheme.primary.withOpacity(0.85),
                                ]
                              : [
                                  colorScheme.primary.withOpacity(0.9),
                                  colorScheme.primary.withOpacity(0.75),
                                ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(isActive ? 0.5 : 0.4),
                            blurRadius: isActive ? 20 : 16,
                            spreadRadius: isActive ? 4 : 2,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 2.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(3.5),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.98),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(7),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/bunnyy.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ).animate().shimmer(
                      duration: 600.ms,
                      color: Colors.white.withOpacity(0.6),
                    )
                  : AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isActive
                              ? [
                                  colorScheme.primary,
                                  colorScheme.primary.withOpacity(0.85),
                                ]
                              : [
                                  colorScheme.primary.withOpacity(0.9),
                                  colorScheme.primary.withOpacity(0.75),
                                ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(isActive ? 0.5 : 0.4),
                            blurRadius: isActive ? 20 : 16,
                            spreadRadius: isActive ? 4 : 2,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 2.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(3.5),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.98),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(7),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/bunnyy.png',
                            fit: BoxFit.cover,
                          ),
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
