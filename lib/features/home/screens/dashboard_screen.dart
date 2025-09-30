// lib/features/home/screens/dashboard_screen.dart
import 'dart:ui';

// Gerekli importlar (temizlenmiş)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/features/home/widgets/todays_plan.dart';
import 'package:taktik/features/onboarding/providers/tutorial_provider.dart';
import 'package:taktik/features/home/widgets/hero_header.dart';
import 'package:taktik/shared/constants/highlight_keys.dart';
import 'package:taktik/features/home/providers/home_providers.dart';
import 'package:taktik/features/home/widgets/focus_hub_card.dart';
import 'package:taktik/features/home/widgets/motivation_quotes_card.dart';
import 'package:taktik/features/home/widgets/daily_progress_card.dart';
import 'package:taktik/features/home/widgets/security_health_card.dart';
import 'package:taktik/shared/widgets/command_center_background.dart';
import 'package:taktik/shared/widgets/scaffold_with_nav_bar.dart' show rootScaffoldKey;
import 'package:taktik/shared/widgets/section_header.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'package:taktik/data/models/plan_model.dart';

// Widget'ları vurgulamak için GlobalKey'ler artik highlight_keys.dart'tan geliyor, burada TANIM YOK.

final expiredPlanDialogShownProvider = StateProvider<bool>((ref) => false);

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
  void _onScroll() {
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    double target = (offset / _opacityTrigger).clamp(0, 1);
    // Gürültülü sürekli setState engelle (0.04 farktan küçükse güncelleme yapma)
    if ((target - _appBarOpacity).abs() > 0.04) {
      if (mounted) setState(() => _appBarOpacity = target);
    }
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
    });
  }

  void _checkAndShowExpiredPlanDialog() {
    final planAsync = ref.watch(planProvider);
    final dialogShown = ref.watch(expiredPlanDialogShownProvider);

    planAsync.whenData((planDoc) {
      if (planDoc?.weeklyPlan != null && !dialogShown) {
        final weeklyPlan = WeeklyPlan.fromJson(planDoc!.weeklyPlan!);
        if (weeklyPlan.isExpired) {
          // Prevent scheduling the dialog build during a build phase
          Future.microtask(() {
            if (mounted) {
              _showExpiredPlanDialog(context);
              ref.read(expiredPlanDialogShownProvider.notifier).state = true;
            }
          });
        }
      }
    });
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
        final content = <Widget>[
          const RepaintBoundary(child: HeroHeader()),
          const SizedBox(height: 20),
          const RepaintBoundary(child: SecurityHealthCard()),
          const SizedBox(height: 16),
          const RepaintBoundary(child: DailyProgressCard()),
          const SizedBox(height: 16),
          const RepaintBoundary(child: FocusHubCard()),
          const SizedBox(height: 18),
          const SectionHeader(
            icon: Icons.auto_awesome_rounded,
            title: 'Komuta Paneli',
            subtitle: 'Günün planını ve stratejik önerileri tek bir ekranda yönet.',
          ),
          const SizedBox(height: 12),
          RepaintBoundary(
            child: Container(
              key: todaysPlanKey,
              child: const TodaysPlan(),
            ),
          ),
          const SizedBox(height: 18),
          const RepaintBoundary(child: MotivationQuotesCard()),
          const SizedBox(height: 52),
        ];

        return SafeArea(
          child: Stack(
            children: [
              const CommandCenterBackground(),
              CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    floating: false,
                    snap: false,
                    toolbarHeight: 64,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    leading: Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu_rounded, color: AppTheme.secondaryColor),
                        onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
                        tooltip: 'Menü',
                      ),
                    ),
                    title: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _appBarOpacity.clamp(0, 1),
                      child: const Text('Komuta Merkezi'),
                    ),
                    centerTitle: true,
                    actions: [
                      const _NotificationBell(),
                      const SizedBox(width: 6),
                    ],
                    flexibleSpace: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: _appBarOpacity * 14,
                          sigmaY: _appBarOpacity * 14,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppTheme.primaryColor.withValues(alpha: (_appBarOpacity * 0.85).clamp(0, .85)),
                                AppTheme.primaryColor.withValues(alpha: (_appBarOpacity * 0.65).clamp(0, .65)),
                              ],
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: AppTheme.lightSurfaceColor.withValues(alpha: _appBarOpacity * 0.3),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(_hPad, 14, _hPad, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(content),
                    ),
                  ),
                ],
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
          icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.secondaryColor),
        ),
        if (count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
