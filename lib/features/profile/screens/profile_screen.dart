// lib/features/profile/screens/profile_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/providers/admin_providers.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/focus_session_model.dart';
import 'package:taktik/features/profile/models/badge_model.dart' as app_badge;
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Avatar için eklendi
import 'package:flutter/services.dart'; // HapticFeedback
import 'dart:math' as math; // trig için
import '../logic/rank_service.dart';
import 'package:taktik/data/models/performance_summary.dart';
import 'package:taktik/data/models/plan_document.dart'; // EKLENDİ
import 'package:share_plus/share_plus.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:taktik/data/providers/firestore_providers.dart' as providers;
import 'dart:ui' as ui;
import 'package:taktik/shared/widgets/logo_loader.dart';

// ===== NovaPulse / Arena ile tutarlı premium accent renkleri =====
// Bu sabitler artık tema renklerine bağlanacak.
// const _accentProfile1 = AppTheme.secondaryColor; // camgöbeği
// const _accentProfile2 = AppTheme.successColor;   // zümrüt

// ARKA PLAN GRADYANI ARTIK TEMADAN DİNAMİK OLARAK ALINACAK
// const List<Color> _profileBgGradient = [
//   AppTheme.scaffoldBackgroundColor,
//   AppTheme.cardColor,
//   AppTheme.scaffoldBackgroundColor,
// ];

final focusSessionsProvider = StreamProvider.autoDispose<List<FocusSessionModel>>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user != null) {
    return FirebaseFirestore.instance
        .collection('focusSessions')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => FocusSessionModel.fromSnapshot(doc)).toList());
  }
  return Stream.value([]);
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late ConfettiController _confettiController;
  final GlobalKey _shareKey = GlobalKey();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Çıkış Yap"),
          content: const Text("Oturumu sonlandırmak istediğinizden emin misiniz?"),
          actions: <Widget>[
            TextButton(
              child: Text("İptal", style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text("Çıkış Yap", style: TextStyle(color: theme.colorScheme.error)),
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(authControllerProvider.notifier).signOut();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareProfileImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      final boundary = _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final uiImage = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final xfile = XFile.fromData(bytes, name: 'warrior_card.png', mimeType: 'image/png');
      await Share.shareXFiles([xfile], text: 'Savaşçı Künyem');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paylaşım hatası: $e')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);

    ref.listen<AsyncValue<UserModel?>>(userProfileProvider, (previous, next) {
      final prevUser = previous?.valueOrNull;
      final nextUser = next.valueOrNull;
      if (prevUser != null && nextUser != null) {
        final prevRank = RankService.getRankInfo(prevUser.engagementScore).current;
        final nextRank = RankService.getRankInfo(nextUser.engagementScore).current;
        if (prevRank.name != nextRank.name) {
          _confettiController.play();
        }
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Arkadaş Ara',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () {
              HapticFeedback.selectionClick();
              context.push('/user-search');
            },
          ),
          IconButton(
            tooltip: _sharing ? 'Hazırlanıyor...' : 'Paylaş',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: _sharing ? null : () { HapticFeedback.selectionClick(); _shareProfileImage(); },
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.push(AppRoutes.settings),
            tooltip: 'Ayarlar',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).cardColor,
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: userAsync.when(
          data: (user) {
            if (user == null) return const Center(child: Text('Komutan bulunamadı.'));
            return _ProfileView(user: user, shareKey: _shareKey, confettiController: _confettiController);
          },
          loading: () => const LogoLoader(),
          error: (e, s) => Center(child: Text('Karargâh Yüklenemedi: $e')),
        ),
      ),
    );
  }
}

class _ProfileView extends ConsumerWidget {
  final UserModel user;
  final GlobalKey shareKey;
  final ConfettiController confettiController;

  const _ProfileView({
    required this.user,
    required this.shareKey,
    required this.confettiController,
  });

  List<app_badge.Badge> _generateBadges(BuildContext context, UserModel user, PerformanceSummary performance, PlanDocument? planDoc, int testCount, double avgNet, List<FocusSessionModel> focusSessions) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return [
      app_badge.Badge(name: 'İlk Adım', description: 'İlk denemeni başarıyla ekledin ve zafere giden yola çıktın.', icon: Icons.flag, color: colorScheme.secondary, isUnlocked: testCount >= 1, hint: "İlk denemeni ekleyerek başla."),
      app_badge.Badge(name: 'Acemi Savaşçı', description: '5 farklı denemede savaş meydanının tozunu attın.', icon: Icons.shield_outlined, color: colorScheme.secondary, isUnlocked: testCount >= 5, rarity: app_badge.BadgeRarity.common, hint: "Toplam 5 deneme ekle."),
      app_badge.Badge(name: 'Kıdemli Savaşçı', description: '15 deneme! Artık bu işin kurdu olmaya başladın.', icon: Icons.shield, color: colorScheme.secondary, isUnlocked: testCount >= 15, rarity: app_badge.BadgeRarity.rare, hint: "Toplam 15 deneme ekle."),
      app_badge.Badge(name: 'Deneme Fatihi', description: 'Tam 50 denemeyi arşivine ekledin. Önünde kimse duramaz!', icon: Icons.military_tech, color: colorScheme.secondary, isUnlocked: testCount >= 50, rarity: app_badge.BadgeRarity.epic, hint: "Toplam 50 deneme ekle."),
      app_badge.Badge(name: 'Kıvılcım', description: 'Ateşi yaktın! 3 günlük çalışma serisine ulaştın.', icon: Icons.whatshot_outlined, color: colorScheme.primary, isUnlocked: user.streak >= 3, hint: "3 gün ara vermeden çalış."),
      app_badge.Badge(name: 'Alev Ustası', description: 'Tam 14 gün boyunca disiplini elden bırakmadın. Bu bir irade zaferidir!', icon: Icons.local_fire_department, color: colorScheme.primary, isUnlocked: user.streak >= 14, rarity: app_badge.BadgeRarity.rare, hint: "14 günlük seriye ulaş."),
      app_badge.Badge(name: 'Durdurulamaz', description: '30 gün! Sen artık bir alışkanlık abidesisin.', icon: Icons.wb_sunny, color: colorScheme.primary, isUnlocked: user.streak >= 30, rarity: app_badge.BadgeRarity.epic, hint: "Tam 30 gün ara verme."),
      app_badge.Badge(name: 'Yükseliş', description: 'Ortalama 50 net barajını aştın. Bu daha başlangıç!', icon: Icons.trending_up, color: colorScheme.primary, isUnlocked: avgNet > 50, hint: "Net ortalamanı 50'nin üzerine çıkar."),
      app_badge.Badge(name: 'Usta Nişancı', description: 'Ortalama 90 net! Elitler arasına hoş geldin.', icon: Icons.gps_not_fixed, color: colorScheme.primary, isUnlocked: avgNet > 90, rarity: app_badge.BadgeRarity.rare, hint: "Net ortalamanı 90'ın üzerine çıkar."),
      app_badge.Badge(name: 'Taktik Nişancı', description: 'Ortalama 100 net barajını yıktın. Sen bir efsanesin!', icon: Icons.workspace_premium, color: colorScheme.primary, isUnlocked: avgNet > 100, rarity: app_badge.BadgeRarity.epic, hint: "Net ortalamanı 100'ün üzerine çıkar."),
      app_badge.Badge(name: 'Günlük Görev Ustası', description: 'Günlük görevlerini düzenli olarak tamamladın.', icon: Icons.checklist, color: colorScheme.tertiary, isUnlocked: (user.completedDailyTasks.values.expand((e) => e).length) >= 15, rarity: app_badge.BadgeRarity.rare, hint: "Günlük görevlerini düzenli olarak tamamla."),
      app_badge.Badge(name: 'Odaklanma Ninjası', description: 'Toplam 10 saat Pomodoro tekniği ile odaklandın.', icon: Icons.timer, color: colorScheme.tertiary, isUnlocked: focusSessions.fold(0, (p, c) => p + c.durationInSeconds) >= 36000, rarity: app_badge.BadgeRarity.rare, hint: "Toplam 10 saat odaklan."),
      app_badge.Badge(name: 'Cevher Avcısı', description: 'Cevher Atölyesi\'nde ilk zayıf konunu işledin.', icon: Icons.construction, color: colorScheme.primary, isUnlocked: performance.topicPerformances.isNotEmpty, hint: "Cevher Atöylyesi'ni kullan."),
      app_badge.Badge(name: 'Arena Gladyatörü', description: 'Liderlik tablosuna girerek adını duyurdun.', icon: Icons.leaderboard, color: colorScheme.primary, isUnlocked: user.engagementScore > 0, rarity: app_badge.BadgeRarity.common, hint: "Etkileşim puanı kazan."),
      app_badge.Badge(name: 'Efsane', description: 'Tüm madalyaları toplayarak ölümsüzleştin!', icon: Icons.auto_stories, color: colorScheme.primaryContainer, isUnlocked: false, rarity: app_badge.BadgeRarity.legendary, hint: "Tüm diğer madalyaları kazan."),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(premiumStatusProvider);
    final testsAsync = ref.watch(testsProvider);
    final focusSessionsAsync = ref.watch(focusSessionsProvider);
    final performanceAsync = ref.watch(performanceProvider);
    final planDocAsync = ref.watch(planProvider);
    final statsStream = ref.watch(providers.userStatsStreamProvider);
    final followCountsAsync = ref.watch(providers.followCountsProvider(user.id));

    // Check for loading state first
    if (testsAsync.isLoading || focusSessionsAsync.isLoading || performanceAsync.isLoading || planDocAsync.isLoading || followCountsAsync.isLoading) {
      return const LogoLoader();
    }

    // Handle errors gracefully
    if (testsAsync.hasError || focusSessionsAsync.hasError || performanceAsync.hasError || planDocAsync.hasError || followCountsAsync.hasError) {
      return const Center(child: Text("Veriler yüklenirken bir sorun oluştu."));
    }

    // If we reach here, all data is available.
    final tests = testsAsync.value!;
    final focusSessions = focusSessionsAsync.value!;
    final performance = performanceAsync.value!;
    final planDoc = planDocAsync.value;
    final followCounts = followCountsAsync.value!;
    final statsUpdatedAt = statsStream.valueOrNull?.updatedAt;

    final rankInfo = RankService.getRankInfo(user.engagementScore);
    final currentRank = rankInfo.current;
    final nextRank = rankInfo.next;
    final progressToNext = rankInfo.progress;
    final rankIndex = RankService.ranks.indexOf(currentRank);

    final testCount = tests.length;
    final avgNet = testCount > 0 ? user.totalNetSum / testCount : 0.0;
    final allBadges = _generateBadges(context, user, performance, planDoc, testCount, avgNet, focusSessions);
    final unlockedCount = allBadges.where((b) => b.isUnlocked).length;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      RepaintBoundary(
                        key: shareKey,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: theme.brightness == Brightness.dark
                                    ? [
                                        colorScheme.surface.withOpacity(0.5),
                                        colorScheme.surface.withOpacity(0.2)
                                      ]
                                    : [
                                        colorScheme.surface.withOpacity(0.98),
                                        colorScheme.surface.withOpacity(0.92)
                                      ]),
                            border: Border.all(
                              color: theme.brightness == Brightness.dark
                                  ? colorScheme.onSurface.withOpacity(0.12)
                                  : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              _ProfileAvatarHalo(user: user, color: currentRank.color, rankIndex: rankIndex),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      user.name ?? 'İsimsiz Savaşçı',
                                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.3, fontSize: 20),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isPremium) ...[
                                    const SizedBox(width: 6),
                                    const _PremiumStatusBadge(),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              _RankPill(rank: currentRank),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: _ProfileStatCard(label: 'Deneme', value: testCount.toString(), icon: Icons.library_books_rounded, delay: 0.ms)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _ProfileStatCard(label: 'Ort. Net', value: avgNet.toStringAsFixed(1), icon: Icons.track_changes_rounded, delay: 0.ms)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _ProfileStatCard(label: 'Seri', value: user.streak.toString(), icon: Icons.local_fire_department_rounded, delay: 0.ms)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset('assets/images/logo.png', width: 24, height: 24),
                                  const SizedBox(width: 6),
                                  Text('Taktik App', style: theme.textTheme.titleSmall?.copyWith(color: colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Takipçi / Takip alanı: Row -> Wrap (overflow engelleme)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 18,
                        runSpacing: 8,
                        children: [
                          _FollowCount(label: 'Takipçi', value: followCounts.$1, onTap: () => context.push('/profile/follow-list?mode=followers')),
                          _FollowCount(label: 'Takip', value: followCounts.$2, onTap: () => context.push('/profile/follow-list?mode=following')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (statsUpdatedAt != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Son güncelleme: ${DateFormat('dd MMM yyyy HH:mm', 'tr_TR').format(statsUpdatedAt)}',
                            style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                          ),
                        ),
                      const SizedBox(height: 12),
                      _NeoXpBar(
                        currentXp: user.engagementScore,
                        nextLevelXp: nextRank.requiredScore == currentRank.requiredScore ? currentRank.requiredScore : nextRank.requiredScore,
                        progress: progressToNext,
                      ).animate().fadeIn(duration: 450.ms, delay: 200.ms),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _ProfileStatCard(label: 'Madalyalar', value: '$unlockedCount/${allBadges.length}', icon: Icons.military_tech_rounded, delay: 260.ms)),
                          const SizedBox(width: 10),
                          Expanded(child: _ProfileStatCard(label: 'Seviye', value: (rankIndex + 1).toString(), icon: Icons.workspace_premium, delay: 320.ms)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _ActionNeo(icon: Icons.emoji_events_outlined, label: 'Başarılar', onTap: () => context.push('/profile/honor-wall', extra: allBadges))),
                          const SizedBox(width: 10),
                          Expanded(child: _ActionNeo(icon: Icons.timeline_rounded, label: 'İlerleme', onTap: () => context.push('/home/stats'))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _ActionNeo(icon: Icons.person_rounded, label: 'Avatar', onTap: () => context.push('/profile/avatar-selection'))),
                          const SizedBox(width: 10),
                          Expanded(child: _ActionNeo(icon: Icons.map_rounded, label: 'Strateji', onTap: () {
                            if (planDoc?.weeklyPlan != null) {
                              context.push('/home/weekly-plan');
                            } else {
                              context.push('${AppRoutes.aiHub}/${AppRoutes.strategicPlanning}');
                            }
                          })),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (ref.watch(adminClaimProvider).valueOrNull == true)
                        Row(
                          children: [
                            Expanded(child: _ActionNeo(icon: Icons.admin_panel_settings_rounded, label: 'Admin Paneli', onTap: () => context.push('/admin/panel'))),
                          ],
                        ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ConfettiWidget(
          confettiController: confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          numberOfParticles: 30,
          gravity: 0.2,
          colors: [colorScheme.primary, colorScheme.secondary, colorScheme.onSurface, Colors.amber],
        ),
      ],
    );
  }
}

class _FollowCount extends StatelessWidget {
  final String label; final int value; final VoidCallback? onTap;
  const _FollowCount({required this.label, required this.value, this.onTap});
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 86, minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                child: Text(
                  value.toString(),
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: FittedBox(
                  child: Text(
                    label,
                    style: textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
        ),
      ),
    );
  }
}

// === Diğer widget'lar değişmediği için kısaltıldı ===
class _ProfileAvatarHalo extends StatefulWidget {
  final UserModel user; final Color color; final int rankIndex;
  const _ProfileAvatarHalo({required this.user, required this.color, required this.rankIndex});

  @override
  State<_ProfileAvatarHalo> createState() => _ProfileAvatarHaloState();
}

class _ProfileAvatarHaloState extends State<_ProfileAvatarHalo> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  bool _isGlowing = false;

  String _avatarUrl(String style, String seed) => 'https://api.dicebear.com/9.x/'
      '$style/svg?seed=$seed&backgroundColor=transparent&margin=0&scale=110&size=256';

  bool get _midTier => widget.rankIndex >= 3;
  bool get _highTier => widget.rankIndex >= 6;
  bool get _legendTier => widget.rankIndex >= 8;
  bool get _apexTier => widget.rankIndex >= 9;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _triggerGlow() {
    if (!_isGlowing) {
      setState(() => _isGlowing = true);
      HapticFeedback.lightImpact();
      _glowController.forward(from: 0).then((_) {
        if (mounted) {
          setState(() => _isGlowing = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentProfile1 = colorScheme.primary;
    final accentProfile2 = colorScheme.secondary;

    const double outerSize = 170;
    const double avatarDiameter = 126;
    final primaryGlow = widget.color.o(0.30);
    final secondaryGlow = _highTier ? accentProfile1.o(0.25) : accentProfile2.o(0.18);

    return GestureDetector(
      onTap: _triggerGlow,
      child: SizedBox(
        width: outerSize,
        height: outerSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Statik halo efekti - animasyon yok
            if (_isGlowing) ...[
              _HaloRing(controller: _glowController, color: accentProfile1.o(0.20), size: 150, begin: 0.90, end: 1.05, delay: 0.ms),
              if (_midTier)
                _HaloRing(controller: _glowController, color: accentProfile2.o(0.16), size: 132, begin: 0.92, end: 1.07, delay: 250.ms),
              if (_highTier)
                _HaloRing(controller: _glowController, color: primaryGlow, size: 164, begin: 0.95, end: 1.03, delay: 600.ms),
              if (_legendTier)
                _PulsingCore(controller: _glowController, size: 60, color: accentProfile2.o(0.20)),
              if (_highTier)
                _RotatingRing(
                  controller: _glowController,
                  size: 158,
                  stroke: 3,
                  gradient: SweepGradient(colors: [
                    accentProfile2.o(0.0),
                    accentProfile2.o(0.7),
                    accentProfile1.o(0.8),
                    accentProfile2.o(0.0),
                  ]),
                  duration: _apexTier ? const Duration(seconds: 10) : const Duration(seconds: 18),
                ),
              if (_legendTier)
                ...List.generate(10 + (widget.rankIndex * 2).clamp(0, 12), (i) => _SparkParticle(controller: _glowController, index: i, radius: 78, apex: _apexTier)),
            ],

            // Rütbe ikonu - sadece glow sırasında animasyon
            if (widget.rankIndex >= 4)
              Positioned(
                top: 4.0 + (10 - widget.rankIndex).clamp(0,6).toDouble(),
                child: Opacity(
                  opacity: (0.35 + (widget.rankIndex * 0.07)).clamp(0.4, 1.0),
                  child: AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, child) {
                      final scale = _isGlowing
                        ? 1.0 + (_glowController.value * 0.1)
                        : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      color: widget.rankIndex >= 8 ? accentProfile2 : accentProfile1.o(0.9),
                      size: 26 + (widget.rankIndex * 1.8),
                    ),
                  ),
                ),
              ),

            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: CustomPaint(
                  painter: _RankFramePainter(
                    rankIndex: widget.rankIndex,
                    color: widget.color,
                    intensity: 0.35 + (widget.rankIndex * 0.04).clamp(0, 0.4),
                    accent: accentProfile2, // Pass theme-aware color
                    base: accentProfile1,   // Pass theme-aware color
                  ),
                ),
              ),
            ),

            Container(
              width: avatarDiameter + 12,
              height: avatarDiameter + 12,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _apexTier ? accentProfile2 : accentProfile2.o(0.9),
                  _apexTier ? accentProfile1 : accentProfile1.o(0.9),
                ]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: secondaryGlow, blurRadius: 28, spreadRadius: 2),
                  if (_highTier) BoxShadow(color: accentProfile2.o(0.25), blurRadius: 40, spreadRadius: 6),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).scaffoldBackgroundColor),
                child: ClipOval(
                  child: widget.user.avatarStyle != null && widget.user.avatarSeed != null
                      ? SvgPicture.network(
                    _avatarUrl(widget.user.avatarStyle!, widget.user.avatarSeed!),
                    fit: BoxFit.cover,
                    width: avatarDiameter,
                    height: avatarDiameter,
                    placeholderBuilder: (_) => Center(
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          valueColor: AlwaysStoppedAnimation(accentProfile2),
                        ),
                      ),
                    ),
                    semanticsLabel: 'Kullanıcı avatarı',
                  )
                      : Center(
                    child: Text(
                      widget.user.name?.substring(0, 1).toUpperCase() ?? 'T',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: accentProfile2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 480.ms).scale(curve: Curves.easeOutBack),
          ],
        ),
      ),
    );
  }
}

class _RankFramePainter extends CustomPainter {
  final int rankIndex; final Color color; final double intensity; final Color accent; final Color base;
  _RankFramePainter({required this.rankIndex, required this.color, required this.intensity, required this.accent, required this.base});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width/2, size.height/2);
    final radius = size.width/2 - 12;
    final tier = rankIndex;
    final gradient = SweepGradient(
      colors: [
        base.o(intensity * 0.2),
        accent.o(intensity),
        base.o(intensity * 0.6),
        accent.o(intensity),
        base.o(intensity * 0.2),
      ],
      stops: const [0, .25, .5, .75, 1],
      transform: const GradientRotation(-math.pi/2),
    );
    final stroke = 3.0 + (tier * 0.45);
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, (tier >= 7 ? 4 : 2));
    if (tier >= 5) {
      final glowPaint = Paint()
        ..color = accent.o(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(center, radius, glowPaint);
    }
    canvas.drawCircle(center, radius, paint);
  }
  @override
  bool shouldRepaint(covariant _RankFramePainter old) => old.rankIndex != rankIndex || old.color != color || old.intensity != intensity;
}

class _RotatingRing extends StatelessWidget {
  final AnimationController controller;
  final double size; final double stroke; final Gradient gradient; final Duration duration;
  const _RotatingRing({required this.controller, required this.size, required this.stroke, required this.gradient, required this.duration});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: controller.value * 6.28318,
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _RingPainter(gradient: gradient, stroke: stroke),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final Gradient gradient; final double stroke;
  _RingPainter({required this.gradient, required this.stroke});
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final r = size.width / 2;
    canvas.drawArc(Rect.fromCircle(center: Offset(r, r), radius: r - stroke/2), 0, 6.28318, false, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PulsingCore extends StatelessWidget {
  final AnimationController controller;
  final double size; final Color color;
  const _PulsingCore({required this.controller, required this.size, required this.color});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 0.85 + (controller.value * 0.25);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
            ),
          ),
        );
      },
    );
  }
}

class _SparkParticle extends StatelessWidget {
  final AnimationController controller;
  final int index; final double radius; final bool apex;
  const _SparkParticle({required this.controller, required this.index, required this.radius, required this.apex});
  @override
  Widget build(BuildContext context) {
    final angle = (index / 12) * 2 * math.pi;
    final dist = radius + (index % 3) * 4;
    final dx = dist * math.cos(angle);
    final dy = dist * math.sin(angle);
    final baseColor = apex ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final opacity = 0.1 + (controller.value * 0.9);
        final scale = 0.6 + (controller.value * 0.7);
        return Positioned(
          left: (radius + 10) + dx,
          top: (radius + 10) + dy,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: baseColor.o(0.9),
                  boxShadow: [BoxShadow(color: baseColor.o(0.6), blurRadius: 8, spreadRadius: 1)],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HaloRing extends StatelessWidget {
  final AnimationController controller;
  final Color color; final double size; final double begin; final double end; final Duration delay;
  const _HaloRing({required this.controller, required this.color, required this.size, required this.begin, required this.end, required this.delay});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = begin + (controller.value * (end - begin));
        return Opacity(
          opacity: controller.value,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RankPill extends StatelessWidget {
  final Rank rank; const _RankPill({required this.rank});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: 400.ms,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(colors: [rank.color.o(0.25), rank.color.o(0.06)]),
        border: Border.all(color: rank.color.o(0.55), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(rank.icon, size: 18, color: rank.color),
          const SizedBox(width: 8),
          Text(rank.name, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _NeoXpBar extends StatelessWidget {
  final int currentXp; final int nextLevelXp; final double progress;
  const _NeoXpBar({required this.currentXp, required this.nextLevelXp, required this.progress});
  @override
  Widget build(BuildContext context) {
    final capped = progress.clamp(0.0, 1.0);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentProfile1 = colorScheme.primary;
    final accentProfile2 = colorScheme.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flash_on_rounded, size: 16, color: accentProfile2),
            const SizedBox(width: 4),
            Text(
              'Rütbe Puanı',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Text(
              '$currentXp / $nextLevelXp',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(colors: [accentProfile1, accentProfile2]),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 18,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: colorScheme.surface.withOpacity(0.55),
                    ),
                  ),
                  AnimatedContainer(
                    duration: 700.ms,
                    curve: Curves.easeOutCubic,
                    width: (w) * capped,
                    height: 18,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [accentProfile2, accentProfile1]),
                      boxShadow: [
                        BoxShadow(color: accentProfile2.o(0.4), blurRadius: 14, spreadRadius: 1),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  final String label; final String value; final IconData icon; final Duration delay;
  const _ProfileStatCard({required this.label, required this.value, required this.icon, required this.delay});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      label: '$label istatistiği: $value',
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      colorScheme.onSurface.withOpacity(0.1),
                      colorScheme.onSurface.withOpacity(0.05)
                    ]
                  : [
                      colorScheme.surfaceContainerHighest.withOpacity(0.35),
                      colorScheme.surfaceContainerHighest.withOpacity(0.20)
                    ]),
          border: Border.all(
            color: isDark
                ? colorScheme.onSurface.withOpacity(0.12)
                : colorScheme.surfaceContainerHighest.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: colorScheme.secondary),
              const SizedBox(height: 6),
              FittedBox(
                child: Text(
                  value,
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 16),
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.7), fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 400.ms, delay: delay).slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
    );
  }
}

class _ProfileQuickActions extends StatelessWidget {
  final VoidCallback onHonorWall; final VoidCallback onStrategy; final VoidCallback onAvatar;
  const _ProfileQuickActions({required this.onHonorWall, required this.onStrategy, required this.onAvatar});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hızlı Eylemler', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _ActionNeo(icon: Icons.military_tech_rounded, label: 'Şeref', onTap: onHonorWall)),
            const SizedBox(width: 14),
            Expanded(child: _ActionNeo(icon: Icons.map_rounded, label: 'Strateji', onTap: onStrategy)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _ActionNeo(icon: Icons.person_rounded, label: 'Avatar', onTap: onAvatar)),
            const SizedBox(width: 14),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }
}

class _ActionNeo extends StatefulWidget {
  final IconData icon; final String label; final VoidCallback onTap; const _ActionNeo({required this.icon, required this.label, required this.onTap});
  @override
  State<_ActionNeo> createState() => _ActionNeoState();
}

class _ActionNeoState extends State<_ActionNeo> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: 120.ms,
        curve: Curves.easeOut,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        colorScheme.surface.withOpacity(0.5),
                        colorScheme.surface.withOpacity(0.2)
                      ]
                    : [
                        colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        colorScheme.surfaceContainerHighest.withOpacity(0.15)
                      ]),
            border: Border.all(
              color: isDark
                  ? colorScheme.onSurface.withOpacity(0.12)
                  : colorScheme.surfaceContainerHighest.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: colorScheme.primary, size: 20),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _ColorOpacityXProfile on Color { Color o(double factor) => withValues(alpha: (a * factor).toDouble()); }

class _PremiumStatusBadge extends StatelessWidget {
  const _PremiumStatusBadge();

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primaryContainer;
    return Tooltip(
      message: 'Premium Üye',
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: gold.withOpacity(0.7),
              blurRadius: 14,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          Icons.workspace_premium_rounded,
          color: gold,
          size: 26,
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
            begin: const Offset(0.95, 0.95),
            end: const Offset(1.1, 1.1),
            duration: 1800.ms,
            curve: Curves.easeInOut,
          ),
    );
  }
}
