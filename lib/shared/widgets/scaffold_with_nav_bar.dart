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

final GlobalKey<ScaffoldState> rootScaffoldKey = GlobalKey<ScaffoldState>();

class ScaffoldWithNavBar extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  builder: (ctx) {
                    final completedQuest = ref.watch(questCompletionProvider).completedQuest;
                    if (completedQuest != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
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
              // Tavşan Butonu (AI Hub)
              floatingActionButton: _AnimatedBunnyButton(
                key: aiHubFabKey,
                isActive: navigationShell.currentIndex == 2,
                onTap: () => navigationShell.goBranch(
                  2,
                  initialLocation: 2 == navigationShell.currentIndex,
                ),
              ).animate().scale(delay: 500.ms, curve: Curves.easeOutBack),
              floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
              // Alt Navigasyon Barı
              bottomNavigationBar: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.98),
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor.withOpacity(0.4),
                      width: 0.5,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: BottomAppBar(
                    padding: EdgeInsets.zero,
                    height: 48,
                    elevation: 0,
                    color: Colors.transparent,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(context, icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, index: 0, ref: ref),
                        _buildNavItem(context, icon: Icons.school_outlined, activeIcon: Icons.school_rounded, index: 1, ref: ref),
                        const SizedBox(width: 68), // Tavşan butonu için boşluk
                        _buildNavItem(context, icon: Icons.military_tech_outlined, activeIcon: Icons.military_tech_rounded, index: 3, ref: ref),
                        _buildNavItem(context, icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, index: 4, ref: ref),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (completedQuest != null) QuestCompletionCelebration(completedQuest: completedQuest),
            Consumer(builder: (context, r, _) {
              final showWeeklyPopup = r.watch(weeklyPlanCompletionProvider);
              if (!showWeeklyPopup) return const SizedBox.shrink();
              return _WeeklyPlanVictoryOverlay(onDismiss: () async {
                r.read(_weeklyPlanPopupShownProvider.notifier).state = true;
                final user = r.read(userProfileProvider).value;
                if (user != null) {
                  await r.read(firestoreServiceProvider).usersCollection.doc(user.id).update({'weeklyPlanCompletedAt': Timestamp.now()});
                }
              });
            }),
          ],
        );
      },
    );
  }

  Widget _buildNavItem(BuildContext context, {required IconData icon, required IconData activeIcon, required int index, required WidgetRef ref}) {
    final isSelected = navigationShell.currentIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
      child: SizedBox(
        width: 60,
        height: 48,
        child: Align(
          alignment: const Alignment(0, -0.2),
          child: Icon(
            isSelected ? activeIcon : icon,
            color: isSelected
                ? colorScheme.onSurface
                : colorScheme.onSurface.withOpacity(0.4),
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _AnimatedBunnyButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isActive;
  const _AnimatedBunnyButton({super.key, required this.onTap, this.isActive = false});

  @override
  State<_AnimatedBunnyButton> createState() => _AnimatedBunnyButtonState();
}

class _AnimatedBunnyButtonState extends State<_AnimatedBunnyButton> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  bool _showShimmer = false;
  bool _wasActive = false;

  @override
  void initState() {
    super.initState();
    _wasActive = widget.isActive;
    _scaleController = AnimationController(duration: const Duration(milliseconds: 50), vsync: this);
    _shimmerController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut));
    _shimmerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) setState(() => _showShimmer = false);
    });
  }

  @override
  void didUpdateWidget(_AnimatedBunnyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_wasActive && widget.isActive) {
      setState(() => _showShimmer = true);
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardColor;
    const double buttonSize = 60.0;

    // 1. Gölgeyi buradan ayırdık. Sadece görsel içeriği (Gradient, Border, Resim) burada tanımlıyoruz.
    Widget innerContent = Container(
      width: buttonSize,
      height: buttonSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isActive
              ? [colorScheme.primary, colorScheme.primary.withOpacity(0.85)]
              : [colorScheme.primary.withOpacity(0.9), colorScheme.primary.withOpacity(0.75)],
        ),
        shape: BoxShape.circle,
        // Border burada kalmalı
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: cardColor),
        padding: const EdgeInsets.all(5),
        child: ClipOval(child: Image.asset('assets/images/bunnyy.png', fit: BoxFit.cover)),
      ),
    );

    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        // 2. Gölgeyi taşıyan dış container
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: colorScheme.primary.withOpacity(widget.isActive ? 0.4 : 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 3)
              ),
            ],
          ),
          // 3. İçeriği ClipOval ile sarmalayarak shimmer efektinin yuvarlak olmasını sağladık
          child: ClipOval(
            child: _showShimmer
                ? innerContent.animate().shimmer(duration: 600.ms, color: Colors.white.withOpacity(0.6))
                : innerContent,
          ),
        ),
      ),
    );
  }
}

final _weeklyPlanPopupShownProvider = StateProvider<bool>((_) => false);
final weeklyPlanCompletionProvider = Provider<bool>((ref) {
  final user = ref.watch(userProfileProvider).value;
  final planDoc = ref.watch(planProvider).value;
  final planMap = planDoc?.weeklyPlan;
  if (user == null || planMap == null) return false;
  if (ref.watch(_weeklyPlanPopupShownProvider)) return false;
  try {
    final weekly = WeeklyPlan.fromJson(planMap);
    DateTime startOfWeek(DateTime d) => d.subtract(Duration(days: d.weekday - 1));
    String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final creation = weekly.creationDate;
    final weekStart = startOfWeek(DateTime(creation.year, creation.month, creation.day));
    final dates = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final weekMap = ref.watch(completedTasksForWeekProvider(weekStart)).maybeWhen(data: (m) => m, orElse: () => const <String, List<String>>{});
    int planned = 0; int completed = 0;
    for (int i = 0; i < weekly.plan.length; i++) {
      final dp = weekly.plan[i];
      planned += dp.schedule.length;
      final dayDate = i < dates.length ? dates[i] : weekStart.add(Duration(days: i));
      final completedList = weekMap[dateKey(dayDate)] ?? const <String>[];
      for (final s in dp.schedule) { if (completedList.contains(s.id)) completed++; }
    }
    if (planned > 0 && completed >= planned) {
      if (user.weeklyPlanCompletedAt == null) return true;
      final saved = user.weeklyPlanCompletedAt!.toDate();
      if (startOfWeek(saved).isBefore(weekStart)) return true;
    }
    return false;
  } catch (_) { return false; }
});

class _WeeklyPlanVictoryOverlay extends StatelessWidget {
  final VoidCallback onDismiss;
  const _WeeklyPlanVictoryOverlay({required this.onDismiss});
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                const Text('Tebrikler!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Haftalık planını başarıyla tamamladın.', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: onDismiss, child: const Text('Harika!')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}