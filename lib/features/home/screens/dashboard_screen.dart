// lib/features/home/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/home/widgets/todays_plan.dart';
import 'package:taktik/features/onboarding/providers/tutorial_provider.dart';
import 'package:taktik/features/home/widgets/hero_header.dart';
import 'package:taktik/shared/constants/highlight_keys.dart';
import 'package:taktik/features/home/widgets/test_management_card.dart';
import 'package:taktik/features/home/widgets/dashboard_stats_overview.dart';
import 'package:taktik/shared/widgets/scaffold_with_nav_bar.dart' show rootScaffoldKey;
import 'package:taktik/features/home/widgets/motivation_quotes_card.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'package:taktik/data/models/plan_model.dart';
import 'package:taktik/data/providers/shared_prefs_provider.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:lottie/lottie.dart';

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

  // GÜNCELLEME: Plan kontrolünün sadece bir kez yapılmasını sağlayan bayrak
  bool _hasCheckedExpiredPlan = false;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userProfileProvider).value;
      if (user != null && !user.tutorialCompleted) {
        ref.read(tutorialProvider.notifier).start();
      }
      // İlk çizimden sonra liste animasyonlarını kapat (kaydırma akıcılığı)
      if (mounted) setState(() => _animateSectionsOnce = false);

      // GÜNCELLEME: Kontrolleri initState içinde ve bir kez yapıyoruz.
      // build metodu içinde yapıldığında sürekli tetiklenip üst üste bindiriyordu.
      _checkAndShowExpiredPlanNudge();
      _checkAndShowPremiumForAdults();
    });
  }

  // GÜNCELLEME: İsim değişikliği ve mantık düzeltmesi.
  // Artık local flag kontrolü ile çalışıyor ve bir kez çalıştıktan sonra kilitleniyor.
  Future<void> _checkAndShowExpiredPlanNudge() async {
    // Eğer daha önce kontrol edildiyse veya widget mount edilmediyse dur.
    if (_hasCheckedExpiredPlan || !mounted) return;

    // Burada watch değil read kullanıyoruz, çünkü sadece tek seferlik kontrol istiyoruz.
    // Watch kullanırsak her plan güncellemesinde tekrar çalışır.
    final planDoc = ref.read(planProvider).value;

    if (planDoc?.weeklyPlan == null) return;
    final weeklyPlan = WeeklyPlan.fromJson(planDoc!.weeklyPlan!);

    if (!weeklyPlan.isExpired) return;

    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final lastMs = prefs.getInt('weekly_plan_nudge_last') ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final diffH = (nowMs - lastMs) / (1000 * 60 * 60);

      if (diffH >= _weeklyPlanNudgeIntervalHours) {
        // Flag'i hemen true yapıyoruz ki asenkron işlem bitene kadar tekrar girmesin.
        _hasCheckedExpiredPlan = true;

        if (mounted) {
          // Bottom sheet'i göster
          await _showExpiredPlanNudgeView(context);
          // Gösterim zamanını güncelle
          await prefs.setInt('weekly_plan_nudge_last', DateTime.now().millisecondsSinceEpoch);
        }
      }
    } catch (_) {
      // Hata durumunda sessiz kal
    }
  }

  // 18+ kullanıcılar için premium kontrolü ve yönlendirme
  void _checkAndShowPremiumForAdults() async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    // Premium kullanıcılar için gösterilmez
    if (user.isPremium) return;

    // Kullanıcının yaşını hesapla
    if (user.dateOfBirth == null) return;

    final now = DateTime.now();
    final age = now.year - user.dateOfBirth!.year;
    final hasHadBirthdayThisYear = now.month > user.dateOfBirth!.month ||
        (now.month == user.dateOfBirth!.month && now.day >= user.dateOfBirth!.day);
    final actualAge = hasHadBirthdayThisYear ? age : age - 1;

    // 18 yaşından küçükse kontrol etmeye gerek yok
    if (actualAge < 18) return;

    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final today = DateTime.now().toString().split(' ')[0]; // YYYY-MM-DD formatı

      // Premium olmayan kullanıcılar için satış ekranı
      final lastShownDate = prefs.getString('premium_screen_last_shown') ?? '';

      // Bugün zaten gösterildiyse tekrar gösterme
      if (lastShownDate == today) return;

      // Premium satış ekranını göster ve tarihi kaydet
      Future.microtask(() async {
        if (!mounted) return;
        await prefs.setString('premium_screen_last_shown', today);
        if (mounted) {
          context.go(AppRoutes.premium);
        }
      });
    } catch (_) {
      // prefs alınamazsa sessiz geç
    }
  }

  Future<void> _showExpiredPlanNudgeView(BuildContext context) async {
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

  // _showExpiredPlanDialog metodunu tamamen kaldırdık çünkü artık _checkAndShowExpiredPlanNudgeView kullanıyoruz.

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);

    // GÜNCELLEME: Buradaki sürekli çağrılan fonksiyonları kaldırdık.
    // _checkAndShowExpiredPlanDialog();  <-- SİLİNDİ (Build loop yaratıyordu)
    // _checkAndShowPremiumForAdults(); <-- SİLİNDİ (InitState'e taşındı)

    return userAsync.when(
      data: (user) {
        if (user == null) return const Center(child: Text('Kullanıcı verisi yüklenemedi.'));

        // Hiyerarşik bölümler (YENİ AKIŞ) — ağır widget'ları izole etmek için RepaintBoundary
        final sections = <Widget>[
          const RepaintBoundary(child: HeroHeader()),
          const RepaintBoundary(child: DashboardStatsOverview()),
          const RepaintBoundary(child: TestManagementCard()),
          RepaintBoundary(child: Container(key: todaysPlanKey, child: const TodaysPlan())), // Kaydırılan kartlar burada
          const RepaintBoundary(child: MotivationQuotesCard()),
        ];

        return CustomScrollView(
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
              actions: [
                _RatingStarButton(),
                _NotificationBell(),
                const SizedBox(width: 8),
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
                  // Sıra: Hero -> TestManagement -> TodaysPlan -> Motivation
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

// Rating visibility state provider
final _ratingVisibilityProvider = StateProvider<bool>((ref) => true);

class _RatingStarButton extends ConsumerWidget {
  // Test için 3 dakika, production'da 3 gün olmalı
  static const _reminderDelayMinutes = 4320; // Production: 3 * 24 * 60 = 4320
  static const _prefs_key_last_dismissed = 'rating_last_dismissed_timestamp';

  Future<bool> _shouldShowRating(WidgetRef ref) async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final lastDismissed = prefs.getInt(_prefs_key_last_dismissed);

      if (lastDismissed == null) return true;

      final now = DateTime.now().millisecondsSinceEpoch;
      final diffMinutes = (now - lastDismissed) / (1000 * 60);

      return diffMinutes >= _reminderDelayMinutes;
    } catch (e) {
      return true; // Hata durumunda göster
    }
  }

  Future<void> _saveDismissTime(WidgetRef ref) async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await prefs.setInt(_prefs_key_last_dismissed, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Could not save dismiss time: $e');
    }
  }

  Future<void> _requestReview(BuildContext context, WidgetRef ref) async {
    // Gösterilme zamanı kontrolü
    if (!await _shouldShowRating(ref)) {
      return; // Henüz gösterme zamanı gelmedi
    }

    final inAppReview = InAppReview.instance;

    try {
      // Modern bottom sheet ile destek isteme ekranı
      final shouldContinue = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: true,
        enableDrag: true,
        builder: (BuildContext context) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final isDark = theme.brightness == Brightness.dark;

          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 0,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.3)
                              : Colors.black.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Premium badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFFD700).withOpacity(0.2),
                              const Color(0xFFFFA500).withOpacity(0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFFD700).withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: const Color(0xFFFFD700),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'GÜVENILIR PLATFORM',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ).animate()
                          .fadeIn(duration: 400.ms)
                          .scale(begin: const Offset(0.8, 0.8)),
                      const SizedBox(height: 20),

                      // Lottie Animation
                      SizedBox(
                        height: 160,
                        child: Lottie.asset(
                          'assets/lotties/review.json',
                          fit: BoxFit.contain,
                          repeat: true,
                          animate: true,
                        ),
                      ).animate()
                          .fadeIn(duration: 400.ms)
                          .scale(begin: const Offset(0.9, 0.9), duration: 400.ms),
                      const SizedBox(height: 20),

                      // Title
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFF6366F1),
                            Color(0xFF8B5CF6),
                            Color(0xFFEC4899),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'Sizi değerlendirmeye\ndavet ediyoruz',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ).animate()
                          .fadeIn(delay: 200.ms, duration: 400.ms)
                          .slideY(begin: -0.1, end: 0),
                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        'Görüşleriniz bizim için çok önemli\nve diğer öğrencilere yol gösteriyor',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ).animate()
                          .fadeIn(delay: 300.ms, duration: 400.ms),
                      const SizedBox(height: 28),

                      // Benefits Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _BenefitItem(
                            icon: Icons.workspace_premium_rounded,
                            label: 'Kaliteli\nİçerik',
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                            ),
                          ).animate()
                              .fadeIn(delay: 400.ms, duration: 300.ms)
                              .slideX(begin: -0.2, end: 0),
                          Container(
                            width: 1,
                            height: 50,
                            color: colorScheme.outlineVariant.withOpacity(0.3),
                          ),
                          _BenefitItem(
                            icon: Icons.auto_awesome_rounded,
                            label: 'Sürekli\nGelişim',
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                          ).animate()
                              .fadeIn(delay: 450.ms, duration: 300.ms)
                              .scale(begin: const Offset(0.8, 0.8)),
                          Container(
                            width: 1,
                            height: 50,
                            color: colorScheme.outlineVariant.withOpacity(0.3),
                          ),
                          _BenefitItem(
                            icon: Icons.verified_rounded,
                            label: 'Güvenilir\nPlatform',
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            ),
                          ).animate()
                              .fadeIn(delay: 500.ms, duration: 300.ms)
                              .slideX(begin: 0.2, end: 0),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Primary CTA
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF6366F1),
                              Color(0xFF8B5CF6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 0,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(true),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    color: const Color(0xFFFFD700),
                                    size: 24,
                                  ).animate(onPlay: (controller) => controller.repeat())
                                      .shimmer(
                                    duration: 2.seconds,
                                    color: Colors.white.withOpacity(0.6),
                                  )
                                      .shake(duration: 2.seconds, hz: 2, curve: Curves.easeInOut),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: const Text(
                                        'Mağaza\'da Değerlendir',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(
                                    Icons.star_rounded,
                                    color: const Color(0xFFFFD700),
                                    size: 24,
                                  ).animate(onPlay: (controller) => controller.repeat())
                                      .shimmer(
                                    duration: 2.seconds,
                                    delay: 1.seconds,
                                    color: Colors.white.withOpacity(0.6),
                                  )
                                      .shake(duration: 2.seconds, hz: 2, curve: Curves.easeInOut),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ).animate()
                          .fadeIn(delay: 550.ms, duration: 400.ms)
                          .slideY(begin: 0.2, end: 0)
                          .then()
                          .shimmer(
                        delay: 1000.ms,
                        duration: 2.seconds,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),

                      // Secondary action
                      TextButton(
                        onPressed: () async {
                          await _saveDismissTime(ref);
                          ref.read(_ratingVisibilityProvider.notifier).state = false;
                          if (context.mounted) {
                            Navigator.of(context).pop(false);
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        ),
                        child: Text(
                          'Şimdi değil',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ).animate()
                          .fadeIn(delay: 600.ms, duration: 400.ms),
                    ],
                  ),
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
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(_ratingVisibilityProvider);

    // State provider false ise direkt gizle
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<bool>(
      future: _shouldShowRating(ref),
      builder: (context, snapshot) {
        // Yükleniyor veya gösterilmemeli
        if (!snapshot.hasData || snapshot.data == false) {
          return const SizedBox.shrink(); // İkonu tamamen gizle
        }

        // Gösterilmeli
        return IconButton(
          tooltip: 'Bizi Değerlendirin',
          onPressed: () => _requestReview(context, ref),
          icon: Icon(
            Icons.star_rounded,
            color: Colors.amber.shade600,
            size: 28,
          ),
        )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(
          duration: const Duration(milliseconds: 4000),
          delay: const Duration(milliseconds: 50),
          color: Colors.white.withOpacity(0.4),
          size: 0.5,
        );
      },
    );
  }
}


class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;

  const _BenefitItem({
    required this.icon,
    required this.label,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: gradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.3),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 26,
            color: Colors.white,
          ),
        ).animate(onPlay: (controller) => controller.repeat())
            .shimmer(duration: 3.seconds, color: Colors.white.withOpacity(0.5))
            .then()
            .shake(duration: 3.seconds, hz: 1, curve: Curves.easeInOut),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
            letterSpacing: 0.2,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}


class _NudgeBullet extends StatelessWidget {
  final IconData icon;
  final String text;
  const _NudgeBullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(children: [
      Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.primary.withOpacity(.18)),
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: colorScheme.primary),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(color: colorScheme.onSurface)))
    ]);
  }
}