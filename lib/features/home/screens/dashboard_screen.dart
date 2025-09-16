// lib/features/home/screens/dashboard_screen.dart
// Gerekli importlar (temizlenmiş)
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import 'package:bilge_ai/data/models/test_model.dart'; // KALDIRILDI
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/features/home/widgets/todays_plan.dart';
import 'package:bilge_ai/features/onboarding/providers/tutorial_provider.dart';
import 'package:bilge_ai/features/home/widgets/hero_header.dart';
// import 'package:bilge_ai/features/home/widgets/performance_momentum_card.dart'; // KALDIRILDI: Ayrı kart istenmiyor
// import 'package:bilge_ai/features/home/widgets/performance_cluster.dart'; // KALDIRILDI
// import 'package:bilge_ai/features/home/widgets/adaptive_action_center.dart'; // KALDIRILDI: tekrar eden üçlü kart
import 'package:bilge_ai/shared/constants/highlight_keys.dart';
import 'package:bilge_ai/features/home/providers/home_providers.dart';
import 'package:bilge_ai/features/home/widgets/focus_hub_card.dart';
import 'package:bilge_ai/shared/widgets/scaffold_with_nav_bar.dart' show rootScaffoldKey;
import 'package:bilge_ai/features/home/widgets/motivation_quotes_card.dart';
import 'package:bilge_ai/features/quests/logic/optimized_quests_provider.dart';
import 'package:bilge_ai/shared/widgets/logo_loader.dart';

// Widget'ları vurgulamak için GlobalKey'ler artik highlight_keys.dart'tan geliyor, burada TANIM YOK.

// KUTLAMA TARİHLERİ: static yerine Riverpod state
final celebratedDatesProvider = StateProvider<Set<String>>((ref) => <String>{});

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

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    // final testsAsync = ref.watch(testsProvider); // KALDIRILDI

    return userAsync.when(
      data: (user) {
        if (user == null) return const Center(child: Text('Kullanıcı verisi yüklenemedi.'));
        // final tests = testsAsync.valueOrNull ?? <TestModel>[]; // KALDIRILDI

        // Hiyerarşik bölümler (YENİ AKIŞ) — ağır widget'ları izole etmek için RepaintBoundary
        final sections = <Widget>[
          const RepaintBoundary(child: HeroHeader()),
          const RepaintBoundary(child: FocusHubCard()),
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
                elevation: _appBarOpacity > 0.95 ? 2 : 0,
                backgroundColor: AppTheme.cardColor.withValues(alpha: _appBarOpacity * 0.92),
                surfaceTintColor: Colors.transparent,
                toolbarHeight: 56,
                leading: Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu_rounded, color: AppTheme.secondaryColor),
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
                          AppTheme.cardColor.withValues(alpha: (_appBarOpacity * 0.95).clamp(0, .95)),
                          AppTheme.cardColor.withValues(alpha: (_appBarOpacity * 0.70).clamp(0, .70)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(_hPad, 8, _hPad, 8),
                sliver: SliverList.separated(
                  itemCount: sections.length,
                  itemBuilder: (c, i) {
                    final w = i == 0 ? sections[i] : Padding(padding: const EdgeInsets.only(top: 4), child: sections[i]);
                    return _animatedSection(w, i);
                  },
                  separatorBuilder: (_, i) {
                    // Sıra: Hero -> Focus -> (PageView kartları) -> Motivasyon
                    if (i == 0) return const SizedBox(height: 12); // Hero sonrası
                    if (i == 1) return const SizedBox(height: 16); // Focus sonrası
                    if (i == 2) return const SizedBox(height: 18); // PageView sonrası
                    return const SizedBox(height: 12);
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 64)),
            ],
          ),
        );
      },
      loading: () => const LogoLoader(),
      error: (e, s) => Center(child: Text('Bir hata oluştu: $e')),
    );
  }
}

// --- GÜNLÜK GÖREVLER KARTI (zenginleştirildi) ---
class _DailyQuestsCard extends ConsumerWidget {
  _DailyQuestsCard();
  String _formatRemaining(Duration d) { final h = d.inHours; final m = d.inMinutes.remainder(60); if (h == 0) return '${m}dk'; return '${h}sa ${m}dk'; }
  Color _progressColor(double p) {
    if (p >= .999) return Colors.greenAccent;
    if (p >= .85) return Colors.greenAccent.withValues(alpha: .9);
    if (p >= .5) return AppTheme.secondaryColor;
    return AppTheme.lightSurfaceColor.withValues(alpha: .9);
  }
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value; if (user == null) return const SizedBox.shrink();
    final questProg = ref.watch(dailyQuestsProgressProvider);
    final hasClaimable = ref.watch(hasClaimableQuestsProvider);
    final total = questProg.total; final completed = questProg.completed; final progress = questProg.progress; final remaining = questProg.remaining;

    // Riverpod üzerinden kutlama tarihlerini al
    final celebratedDates = ref.watch(celebratedDatesProvider);

    if (progress >= 1.0 && !hasClaimable) {
      final todayKey = DateTime.now().toIso8601String().substring(0,10);
      if (!celebratedDates.contains(todayKey)) {
        // Set'i immutably güncelle
        ref.read(celebratedDatesProvider.notifier).update((s) => {...s, todayKey});
        WidgetsBinding.instance.addPostFrameCallback((_){ if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: const [Icon(Icons.celebration_rounded, color: Colors.greenAccent), SizedBox(width: 8), Expanded(child: Text('Tüm günlük fetihler tamamlandı! 🔥')),],),)); }});
      }
    }

    final card = Card(
      clipBehavior: Clip.antiAlias,
      elevation: progress >= 1.0 ? 10 : 6,
      shadowColor: hasClaimable ? AppTheme.goldColor.withOpacity(0.7) : (progress >= 1.0 ? AppTheme.successColor.withValues(alpha: .6) : AppTheme.lightSurfaceColor.withValues(alpha: .35)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: hasClaimable ? AppTheme.goldColor : _progressColor(progress), width: 2)),
      child: InkWell(
        onTap: () => context.go('/home/quests'),
        child: Container(
          padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ (hasClaimable ? AppTheme.goldColor : _progressColor(progress)).withValues(alpha: 0.18), AppTheme.cardColor.withValues(alpha: 0.55), ],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          child: Row(children: [
            Stack(alignment: Alignment.center, children: [
              SizedBox(height: 56, width: 56, child: CircularProgressIndicator(value: progress == 0 ? null : progress, strokeWidth: 6, backgroundColor: AppTheme.lightSurfaceColor.withValues(alpha: .25), valueColor: AlwaysStoppedAnimation(hasClaimable ? AppTheme.goldColor : _progressColor(progress)),)),
              Icon(hasClaimable ? Icons.military_tech_rounded : (progress >=1 ? Icons.emoji_events_rounded : Icons.shield_moon_rounded), size: 28, color: hasClaimable ? AppTheme.goldColor : _progressColor(progress)),
            ]),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(hasClaimable ? "Ödül Zamanı!" : (progress >=1 ? "Zafer!" : "Günlük Fetihler"), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text(total == 0 ? 'Bugün görev yok' : '$completed / $total tamamlandı • Kalan ${_formatRemaining(remaining)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor)),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: progress.clamp(0,1), minHeight: 6, backgroundColor: AppTheme.lightSurfaceColor.withValues(alpha: .25), valueColor: AlwaysStoppedAnimation(hasClaimable ? AppTheme.goldColor : _progressColor(progress)),)),
            ])),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.secondaryTextColor, size: 18),
          ]),
        ),
      ),
    );
    if (!hasClaimable) return card;
    return Animate(onPlay: (c)=> c.repeat(reverse: true), effects: [ShimmerEffect(duration: 1500.ms, color: AppTheme.goldColor.withOpacity(0.5))], child: card);
  }
}
// ------------------------------------------

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
