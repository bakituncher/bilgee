// lib/features/home/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/home/widgets/todays_plan.dart';
import 'package:taktik/features/onboarding/providers/tutorial_provider.dart';
import 'package:taktik/features/home/widgets/hero_header.dart';
import 'package:taktik/shared/constants/highlight_keys.dart';
import 'package:taktik/features/home/widgets/test_management_card.dart';
import 'package:taktik/shared/widgets/scaffold_with_nav_bar.dart' show rootScaffoldKey;
import 'package:taktik/features/home/widgets/motivation_quotes_card.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'package:taktik/data/models/plan_model.dart';
import 'package:taktik/data/providers/shared_prefs_provider.dart';
import 'package:taktik/shared/widgets/ad_banner_widget.dart';

final celebratedDatesProvider = StateProvider<Set<String>>((ref) => <String>{});
final expiredPlanDialogShownProvider = StateProvider<bool>((ref) => false);
const _weeklyPlanNudgeIntervalHours = 18;

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // Tutarlı yatay boşluk
  static const double _hPad = 16;
  // Scroll controller + appbar opaklığı
  late final ScrollController _scrollController;
  double _appBarOpacity = 0.0; // 0 -> transparan, 1 -> opak
  static const double _opacityTrigger = 36; // kaç px sonra tam opak

  // Liste animasyonlarını sadece ilk yüklemede çalıştırmak için bayrak
  bool _animateSectionsOnce = true;

  void _onScroll() {
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    double target = (offset / _opacityTrigger).clamp(0, 1);
    // Gürültülü sürekli setState engelle (0.04 farktan küçükse güncelleme yapma)
    if ((target - _appBarOpacity).abs() > 0.04) {
      if (mounted) setState(() => _appBarOpacity = target);
    }
  }

  Widget _animatedSection(Widget child, int index) {
    if (!_animateSectionsOnce) return child; // İlk frame sonrasında animasyon yok
    return Animate(
      delay: (70 * index).ms,
      effects: const [
        FadeEffect(duration: Duration(milliseconds: 240), curve: Curves.easeOut),
        SlideEffect(begin: Offset(0, .06), duration: Duration(milliseconds: 260), curve: Curves.easeOut),
      ],
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    // Öğretici tetikleme (orijinal mantık)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userProfileProvider).value;
      if (user != null && !user.tutorialCompleted) {
        ref.read(tutorialProvider.notifier).start();
      }
      // İlk çizimden sonra liste animasyonlarını kapat (kaydırma akıcılığı)
      if (mounted) setState(() => _animateSectionsOnce = false);
    });
  }

  void _checkAndShowExpiredPlanDialog() {
    final planAsync = ref.watch(planProvider);

    planAsync.whenData((planDoc) async {
      if (planDoc?.weeklyPlan == null) return;
      final weeklyPlan = WeeklyPlan.fromJson(planDoc!.weeklyPlan!);
      if (!weeklyPlan.isExpired) return;

      // SharedPreferences üzerinden en son ne zaman gösterildiğine bak
      try {
        final prefs = await ref.read(sharedPreferencesProvider.future);
        final lastMs = prefs.getInt('weekly_plan_nudge_last') ?? 0;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final diffH = (nowMs - lastMs) / (1000 * 60 * 60);
        if (diffH >= _weeklyPlanNudgeIntervalHours) {
          // Göster ve zaman damgasını güncelle
          Future.microtask(() async {
            if (!mounted) return;
            await _showExpiredPlanNudge(context);
            await prefs.setInt('weekly_plan_nudge_last', DateTime.now().millisecondsSinceEpoch);
          });
        }
      } catch (_) {
        // prefs alınamazsa sessiz geç
      }
    });
  }

  Future<void> _showExpiredPlanNudge(BuildContext context) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    await showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor.withOpacity(.98),
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Icon(Icons.auto_awesome_rounded, color: colorScheme.primary, size: 28),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Yeni Haftayı Mühürleyelim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))
                ]),
                const SizedBox(height: 8),
                Text(
                  'Haftalık planının süresi doldu. Güncel hedeflerin, müfredat sırası ve son performansına göre taptaze bir harekât planı çıkaralım.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(colors: [
                      colorScheme.primary.withOpacity(.12),
                      colorScheme.surfaceContainerHighest.withOpacity(.10)
                    ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    border: Border.all(color: colorScheme.surfaceContainerHighest.withOpacity(.35)),
                  ),
                  child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _NudgeBullet(icon: Icons.route_rounded, text: 'Müfredat sırasına sadık, tekrar etmeyen konu akışı'),
                    SizedBox(height: 8),
                    _NudgeBullet(icon: Icons.speed_rounded, text: 'Seçtiğin yoğunluğa göre akıllı görev ve soru adetleri'),
                    SizedBox(height: 8),
                    _NudgeBullet(icon: Icons.event_available_rounded, text: 'Sınava kalan güne göre vurucu strateji'),
                  ]),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    if (mounted) context.go('/ai-hub/strategic-planning');
                  },
                  icon: const Icon(Icons.auto_fix_high_rounded),
                  label: const Text('Yeni Haftalık Plan Oluştur'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Daha Sonra'),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _showExpiredPlanDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Haftalık Planın Sona Erdi'),
          content: const Text('Yeni bir haftalık plan oluşturarak hedeflerine odaklanmaya ne dersin?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Daha Sonra'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Plan Oluştur'),
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/home/weekly-plan');
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    _checkAndShowExpiredPlanDialog();

    return userAsync.when(
      data: (user) {
        if (user == null) return const Center(child: Text('Kullanıcı verisi yüklenemedi.'));

        // Hiyerarşik bölümler (YENİ AKIŞ) — ağır widget'ları izole etmek için RepaintBoundary
        final sections = <Widget>[
          const RepaintBoundary(child: HeroHeader()),
          const RepaintBoundary(child: TestManagementCard()),
          // AdMob Banner
          RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: AdBannerWidget(
                isPremium: user.isPremium,
                dateOfBirth: user.dateOfBirth,
              ),
            ),
          ),
          RepaintBoundary(child: Container(key: todaysPlanKey, child: const TodaysPlan())), // Kaydırılan kartlar burada
          const RepaintBoundary(child: MotivationQuotesCard()),
        ];

        return SafeArea(
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverAppBar(
                pinned: true,
                floating: false,
                snap: false,
                elevation: _appBarOpacity > 0.95 ? 3 : 0,
                backgroundColor: Theme.of(context).cardColor.withOpacity(_appBarOpacity * 0.95),
                surfaceTintColor: Colors.transparent,
                toolbarHeight: 56,
                shadowColor: Colors.black.withOpacity(0.2),
                leading: Builder(
                  builder: (ctx) => IconButton(
                    icon: Icon(Icons.menu_rounded, color: Theme.of(context).colorScheme.primary),
                    onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
                    tooltip: 'Menü',
                  ),
                ),
                title: AnimatedOpacity(
                  duration: 200.ms,
                  opacity: _appBarOpacity.clamp(0, 1),
                  child: const Text('Komuta Merkezi'),
                ),
                centerTitle: true,
                actions: [
                  _NotificationBell(),
                  const SizedBox(width: 4),
                ],
                flexibleSpace: IgnorePointer(
                  child: AnimatedContainer(
                    duration: 220.ms,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).cardColor.withOpacity((_appBarOpacity * 0.98).clamp(0, .98)),
                          Theme.of(context).cardColor.withOpacity((_appBarOpacity * 0.85).clamp(0, .85)),
                        ],
                      ),
                      border: _appBarOpacity > 0.7
                          ? Border(
                              bottom: BorderSide(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2),
                                width: 1,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(_hPad, 0, _hPad, 4),
                sliver: SliverList.separated(
                  itemCount: sections.length,
                  itemBuilder: (c, i) {
                    return _animatedSection(sections[i], i);
                  },
                  separatorBuilder: (_, i) {
                    // Sıra: Hero -> TestManagement -> AdBanner -> TodaysPlan -> Motivation
                    return const SizedBox(height: 6);
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 60,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const LogoLoader(),
      error: (e, s) => Center(child: Text('Bir hata oluştu: $e')),
    );
  }
}


class _NotificationBell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(unreadInAppCountProvider);
    final count = countAsync.value ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Bildirimler',
          onPressed: () => context.go('/notifications'),
          icon: Icon(Icons.notifications_none_rounded, color: Theme.of(context).colorScheme.primary),
        ),
        if (count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: TextStyle(color: Theme.of(context).colorScheme.onError, fontSize: 11, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _NudgeBullet extends StatelessWidget {
  final IconData icon; final String text;
  const _NudgeBullet({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(children: [
      Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.primary.withOpacity(.18)),
        padding: const EdgeInsets.all(6), child: Icon(icon, size: 16, color: colorScheme.primary),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(color: colorScheme.onSurface)))
    ]);
  }
}
