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
import 'package:in_app_review/in_app_review.dart';

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
                  child: const Text('Ana Panel'),
                ),
                centerTitle: true,
                actions: [
                  _RatingStarButton(),
                  const SizedBox(width: 4),
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

class _RatingStarButton extends StatelessWidget {
  Future<void> _requestReview(BuildContext context) async {
    final inAppReview = InAppReview.instance;

    try {
      // Modern bottom sheet ile destek isteme ekranı
      final shouldContinue = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final isDark = theme.brightness == Brightness.dark;

          return Container(
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surface
                  : colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Animated star icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.amber.shade400,
                            Colors.amber.shade700,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ).animate(onPlay: (controller) => controller.repeat()).shimmer(
                          duration: const Duration(seconds: 2),
                          color: Colors.white.withOpacity(0.3),
                        ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Desteğiniz Bizim İçin Çok Değerli! 💫',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Subtitle
                    Text(
                      'Hedeflerinize ulaşma yolculuğunuzda size yardımcı olabildiysek, bizi değerlendirerek destekleyebilir misiniz?',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Features
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colorScheme.surfaceContainerHighest
                            : colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorScheme.primary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          _RatingFeature(
                            icon: Icons.favorite_rounded,
                            text: 'Bizi motive eder',
                            color: Colors.pink,
                          ),
                          const SizedBox(height: 12),
                          _RatingFeature(
                            icon: Icons.trending_up_rounded,
                            text: 'Daha fazla kişiye ulaşmamızı sağlar',
                            color: Colors.green,
                          ),
                          const SizedBox(height: 12),
                          _RatingFeature(
                            icon: Icons.auto_awesome_rounded,
                            text: 'Uygulamayı geliştirmemize yardımcı olur',
                            color: Colors.amber,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Action buttons
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              elevation: 4,
                              shadowColor: colorScheme.primary.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 24,
                                  color: Colors.amber.shade300,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Değerlendir',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.star_rounded,
                                  size: 24,
                                  color: Colors.amber.shade300,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            'Sonra Hatırlat',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (shouldContinue == true) {
        // Play Store rating'e yönlendir
        if (await inAppReview.isAvailable()) {
          await inAppReview.requestReview();
        } else {
          // Eğer in-app review mevcut değilse, direkt Play Store'a yönlendir
          await inAppReview.openStoreListing(
            appStoreId: 'com.codenzi.taktik',
          );
        }
      }
    } catch (e) {
      // Hata durumunda sessizce geç
      debugPrint('Rating request error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Bizi Değerlendirin',
      onPressed: () => _requestReview(context),
      icon: Icon(
        Icons.star_rounded,
        color: Colors.amber.shade600,
        size: 28,
      ),
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
          duration: const Duration(milliseconds: 1000),
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.12, 1.12),
          curve: Curves.easeInOut,
        )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: const Duration(milliseconds: 2500),
          delay: const Duration(milliseconds: 1000),
          color: Colors.white,
          size: 0.8,
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .then(delay: const Duration(milliseconds: 800))
        .fadeIn(
          duration: const Duration(milliseconds: 400),
          begin: 0.6,
        )
        .fadeOut(
          duration: const Duration(milliseconds: 400),
          begin: 1.0,
        );
  }
}


class _RatingFeature extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _RatingFeature({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? color.withOpacity(0.25) : color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
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
