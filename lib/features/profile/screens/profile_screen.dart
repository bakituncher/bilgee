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
import 'package:taktik/data/models/test_model.dart'; // EKLENDİ: isBranchTest için gerekli
import 'package:taktik/data/models/focus_session_model.dart';
import 'package:taktik/features/profile/models/badge_model.dart' as app_badge;
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../logic/rank_service.dart';
import 'package:taktik/data/models/performance_summary.dart';
import 'package:taktik/data/models/plan_document.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:taktik/data/providers/firestore_providers.dart' as providers;
import 'dart:ui' as ui;
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'package:taktik/features/stats/utils/stats_calculator.dart';

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

      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [xfile],
        text: 'Savaşçı Künyem',
        sharePositionOrigin: sharePositionOrigin,
      );
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    ref.listen<AsyncValue<UserModel?>>(userProfileProvider, (previous, next) {
      final prevUser = previous?.valueOrNull;
      final nextUser = next.valueOrNull;
      if (prevUser != null && nextUser != null) {
        final prevRank = RankService.getRankInfo(prevUser.engagementScore).current;
        final nextRank = RankService.getRankInfo(nextUser.engagementScore).current;
        if (prevRank.name != nextRank.name) {
          _confettiController.play();
          HapticFeedback.heavyImpact();
        }
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          'Profilim',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.scaffoldBackgroundColor.withOpacity(0.95),
                theme.scaffoldBackgroundColor.withOpacity(0.0),
              ],
            ),
          ),
        ),
        actions: [
          _ModernIconButton(
            tooltip: 'Arkadaş Ara',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () {
              HapticFeedback.selectionClick();
              context.push('/user-search');
            },
          ),
          _ModernIconButton(
            tooltip: _sharing ? 'Hazırlanıyor...' : 'Paylaş',
            icon: Icons.ios_share_rounded,
            onPressed: _sharing ? null : () {
              HapticFeedback.selectionClick();
              _shareProfileImage();
            },
          ),
          _ModernIconButton(
            icon: Icons.settings_rounded,
            onPressed: () {
              HapticFeedback.selectionClick();
              context.push(AppRoutes.settings);
            },
            tooltip: 'Ayarlar',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surface,
              colorScheme.surfaceContainerLowest,
              colorScheme.surface,
            ],
          ),
        ),
        child: userAsync.when(
          data: (user) {
            if (user == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_off_rounded,
                      size: 80,
                      color: colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Komutan bulunamadı',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              );
            }
            return _ProfileView(
              user: user,
              shareKey: _shareKey,
              confettiController: _confettiController,
            );
          },
          loading: () => const LogoLoader(),
          error: (e, s) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 80,
                  color: colorScheme.error.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Karargâh Yüklenemedi',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    e.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Modern Icon Button Widget
class _ModernIconButton extends StatefulWidget {
  final String? tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _ModernIconButton({
    this.tooltip,
    required this.icon,
    this.onPressed,
  });

  @override
  State<_ModernIconButton> createState() => _ModernIconButtonState();
}

class _ModernIconButtonState extends State<_ModernIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: widget.tooltip ?? '',
        child: GestureDetector(
          onTapDown: widget.onPressed != null ? (_) => setState(() => _isPressed = true) : null,
          onTapUp: widget.onPressed != null ? (_) {
            setState(() => _isPressed = false);
            widget.onPressed?.call();
          } : null,
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? 0.85 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isPressed
                    ? colorScheme.primaryContainer.withOpacity(0.8)
                    : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Icon(
                widget.icon,
                size: 22,
                color: widget.onPressed != null
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
          ),
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

  List<app_badge.Badge> _generateBadges(BuildContext context, UserModel user, PerformanceSummary performance, PlanDocument? planDoc, int testCount, double avgNet, List<FocusSessionModel> focusSessions, int streak) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return [
      app_badge.Badge(name: 'İlk Adım', description: 'İlk denemeni başarıyla ekledin ve zafere giden yola çıktın.', icon: Icons.flag, color: colorScheme.secondary, isUnlocked: testCount >= 1, hint: "İlk denemeni ekleyerek başla."),
      app_badge.Badge(name: 'Acemi Savaşçı', description: '5 farklı denemede savaş meydanının tozunu attın.', icon: Icons.shield_outlined, color: colorScheme.secondary, isUnlocked: testCount >= 5, rarity: app_badge.BadgeRarity.common, hint: "Toplam 5 deneme ekle."),
      app_badge.Badge(name: 'Kıdemli Savaşçı', description: '15 deneme! Artık bu işin kurdu olmaya başladın.', icon: Icons.shield, color: colorScheme.secondary, isUnlocked: testCount >= 15, rarity: app_badge.BadgeRarity.rare, hint: "Toplam 15 deneme ekle."),
      app_badge.Badge(name: 'Deneme Fatihi', description: 'Tam 50 denemeyi arşivine ekledin. Önünde kimse duramaz!', icon: Icons.military_tech, color: colorScheme.secondary, isUnlocked: testCount >= 50, rarity: app_badge.BadgeRarity.epic, hint: "Toplam 50 deneme ekle."),
      app_badge.Badge(name: 'Kıvılcım', description: 'Ateşi yaktın! 3 günlük çalışma serisine ulaştın.', icon: Icons.whatshot_outlined, color: colorScheme.primary, isUnlocked: streak >= 3, hint: "3 gün ara vermeden çalış."),
      app_badge.Badge(name: 'Alev Ustası', description: 'Tam 14 gün boyunca disiplini elden bırakmadın. Bu bir irade zaferidir!', icon: Icons.local_fire_department, color: colorScheme.primary, isUnlocked: streak >= 14, rarity: app_badge.BadgeRarity.rare, hint: "14 günlük seriye ulaş."),
      app_badge.Badge(name: 'Durdurulamaz', description: '30 gün! Sen artık bir alışkanlık abidesisin.', icon: Icons.wb_sunny, color: colorScheme.primary, isUnlocked: streak >= 30, rarity: app_badge.BadgeRarity.epic, hint: "Tam 30 gün ara verme."),
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

    if (testsAsync.isLoading || focusSessionsAsync.isLoading || performanceAsync.isLoading || planDocAsync.isLoading || followCountsAsync.isLoading) {
      return const LogoLoader();
    }

    if (testsAsync.hasError || focusSessionsAsync.hasError || performanceAsync.hasError || planDocAsync.hasError || followCountsAsync.hasError) {
      return const Center(child: Text("Veriler yüklenirken bir sorun oluştu."));
    }

    final tests = testsAsync.value!;

    // FİLTRELEME: Branş denemelerini hariç tut
    final mainTests = tests.where((t) => !t.isBranchTest).toList();

    final focusSessions = focusSessionsAsync.value!;
    final performance = performanceAsync.value!;
    final planDoc = planDocAsync.value;
    final followCounts = followCountsAsync.value!;

    final rankInfo = RankService.getRankInfo(user.engagementScore);
    final currentRank = rankInfo.current;
    final nextRank = rankInfo.next;
    final progressToNext = rankInfo.progress;
    final rankIndex = RankService.ranks.indexOf(currentRank);

    // HESAPLAMA: Filtrelenmiş liste üzerinden hesapla
    final testCount = mainTests.length;
    final avgNet = testCount > 0 ? mainTests.fold(0.0, (sum, t) => sum + t.totalNet) / testCount : 0.0;

    // MERKEZİ SİSTEM: Streak Firebase'den alınır, hesaplanmaz
    final streak = StatsCalculator.getStreak(user);

    final allBadges = _generateBadges(context, user, performance, planDoc, testCount, avgNet, focusSessions, streak);
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
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
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
                                colorScheme.surface.withOpacity(0.7),
                                colorScheme.surface.withOpacity(0.4),
                                colorScheme.surface.withOpacity(0.6),
                              ]
                                  : [
                                colorScheme.surface.withOpacity(0.98),
                                colorScheme.surfaceContainerHighest.withOpacity(0.85),
                                colorScheme.surface.withOpacity(0.95),
                              ],
                            ),
                            border: Border.all(
                              color: theme.brightness == Brightness.dark
                                  ? colorScheme.outline.withOpacity(0.15)
                                  : colorScheme.outline.withOpacity(0.2),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.shadow.withOpacity(0.1),
                                blurRadius: 24,
                                spreadRadius: 0,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.05),
                                blurRadius: 40,
                                spreadRadius: -5,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _ProfileAvatarHalo(user: user, color: currentRank.color, rankIndex: rankIndex)
                                  .animate()
                                  .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                                  .scale(begin: const Offset(0.8, 0.8), duration: 500.ms, curve: Curves.easeOutBack),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      user.name ?? 'İsimsiz Savaşçı',
                                      style: theme.textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        fontSize: 20,
                                        height: 1.2,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ).animate()
                                        .fadeIn(duration: 500.ms, delay: 100.ms)
                                        .slideY(begin: 0.3, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
                                  ),
                                  if (isPremium) ...[
                                    const SizedBox(width: 8),
                                    const _PremiumStatusBadge()
                                        .animate()
                                        .fadeIn(duration: 400.ms, delay: 200.ms)
                                        .scale(begin: const Offset(0.5, 0.5), duration: 600.ms, curve: Curves.elasticOut),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              _RankPill(rank: currentRank)
                                  .animate()
                                  .fadeIn(duration: 500.ms, delay: 150.ms)
                                  .slideY(begin: 0.3, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
                              const SizedBox(height: 14),
                              // XP Progress Bar
                              _NeoXpBar(
                                currentXp: user.engagementScore,
                                nextLevelXp: nextRank.requiredScore == currentRank.requiredScore ? currentRank.requiredScore : nextRank.requiredScore,
                                progress: progressToNext,
                              ).animate()
                                  .fadeIn(duration: 500.ms, delay: 200.ms)
                                  .slideX(begin: -0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
                              const SizedBox(height: 14),
                              // Madalyalar, Seviye, Deneme ve Seri - 2x2 Grid
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                  border: Border.all(
                                    color: colorScheme.outline.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    // Üst Satır: Madalyalar ve Seviye
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _StatButton(
                                            onTap: () => context.push('/profile/honor-wall', extra: allBadges),
                                            icon: Icons.military_tech_rounded,
                                            iconColor: Colors.amber.shade600,
                                            value: '$unlockedCount/${allBadges.length}',
                                            label: 'Madalyalar',
                                            delay: 250.ms,
                                          ),
                                        ),
                                        Container(
                                          width: 1.5,
                                          height: 60,
                                          margin: const EdgeInsets.symmetric(vertical: 6),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                colorScheme.outline.withOpacity(0.0),
                                                colorScheme.outline.withOpacity(0.3),
                                                colorScheme.outline.withOpacity(0.0),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: _StatButton(
                                            onTap: () => context.push('/profile/ranks'),
                                            icon: Icons.workspace_premium,
                                            iconColor: currentRank.color,
                                            value: '${rankIndex + 1}',
                                            label: 'Seviye',
                                            delay: 275.ms,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Yatay Ayırıcı Çizgi
                                    Container(
                                      height: 1.5,
                                      margin: const EdgeInsets.symmetric(horizontal: 6),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            colorScheme.outline.withOpacity(0.0),
                                            colorScheme.outline.withOpacity(0.3),
                                            colorScheme.outline.withOpacity(0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Alt Satır: Deneme ve Seri
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _StatButton(
                                            onTap: () {}, // Deneme sayfasına gitmek için
                                            icon: Icons.library_books_rounded,
                                            iconColor: colorScheme.primary,
                                            value: testCount.toString(),
                                            label: 'Deneme',
                                            delay: 300.ms,
                                          ),
                                        ),
                                        Container(
                                          width: 1.5,
                                          height: 60,
                                          margin: const EdgeInsets.symmetric(vertical: 6),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                colorScheme.outline.withOpacity(0.0),
                                                colorScheme.outline.withOpacity(0.3),
                                                colorScheme.outline.withOpacity(0.0),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: _StatButton(
                                            onTap: () {}, // Seri sayfasına gitmek için
                                            icon: Icons.local_fire_department_rounded,
                                            iconColor: Colors.orange.shade700,
                                            value: streak.toString(),
                                            label: 'Seri',
                                            delay: 325.ms,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ).animate()
                                  .fadeIn(duration: 500.ms, delay: 250.ms)
                                  .scale(begin: const Offset(0.95, 0.95), duration: 500.ms, curve: Curves.easeOutBack),
                              const SizedBox(height: 12),
                              // Takipçi / Takip alanı
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: _FollowCount(
                                      label: 'Takipçi',
                                      value: followCounts.$1,
                                      onTap: () => context.push('/profile/follow-list?mode=followers'),
                                    ).animate()
                                        .fadeIn(duration: 500.ms, delay: 450.ms)
                                        .slideX(begin: -0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _FollowCount(
                                      label: 'Takip',
                                      value: followCounts.$2,
                                      onTap: () => context.push('/profile/follow-list?mode=following'),
                                    ).animate()
                                        .fadeIn(duration: 500.ms, delay: 500.ms)
                                        .slideX(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset('assets/images/splash.png', width: 28, height: 28),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Taktik App',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ).animate()
                                  .fadeIn(duration: 500.ms, delay: 550.ms)
                                  .scale(begin: const Offset(0.9, 0.9), duration: 500.ms, curve: Curves.easeOutBack),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (ref.watch(adminClaimProvider).valueOrNull == true)
                        Row(
                          children: [
                            Expanded(child: _ActionNeo(icon: Icons.admin_panel_settings_rounded, label: 'Admin Paneli', onTap: () => context.push('/admin/panel'))),
                          ],
                        ),
                      const SizedBox(height: 30),
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
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        if (onTap != null) {
          HapticFeedback.selectionClick();
          onTap!();
        }
      },
      child: Container(
        constraints: const BoxConstraints(minWidth: 80, minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withOpacity(0.15),
              colorScheme.secondaryContainer.withOpacity(0.1),
            ],
          ),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.05),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              child: Text(
                value.toString(),
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: FittedBox(
                child: Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
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

class _StatButton extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Duration delay;

  const _StatButton({
    required this.onTap,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.delay,
  });

  @override
  State<_StatButton> createState() => _StatButtonState();
}

class _StatButtonState extends State<_StatButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: widget.iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                widget.value,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: widget.iconColor,
                  fontSize: 18,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                widget.label,
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

  void _showAvatarPicker(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AvatarPickerSheet(currentUser: widget.user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentProfile1 = colorScheme.primary;
    final accentProfile2 = colorScheme.secondary;

    const double outerSize = 150;
    const double avatarDiameter = 110;
    final primaryGlow = widget.color.o(0.30);
    final secondaryGlow = _highTier ? accentProfile1.o(0.25) : accentProfile2.o(0.18);

    return GestureDetector(
      onTap: () => _showAvatarPicker(context),
      onLongPress: _triggerGlow,
      child: SizedBox(
        width: outerSize,
        height: outerSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
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
                    accent: accentProfile2,
                    base: accentProfile1,
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

class _RankPill extends StatefulWidget {
  final Rank rank;
  const _RankPill({required this.rank});

  @override
  State<_RankPill> createState() => _RankPillState();
}

class _RankPillState extends State<_RankPill> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.rank.color.withOpacity(0.3),
                widget.rank.color.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: widget.rank.color.withOpacity(0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.rank.color.withOpacity(0.2),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.rank.icon, size: 18, color: widget.rank.color),
              const SizedBox(width: 8),
              Text(
                widget.rank.name,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
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
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: accentProfile2.withOpacity(0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(Icons.flash_on_rounded, size: 16, color: accentProfile2),
            ),
            const SizedBox(width: 6),
            Text(
              'Taktik Puanı',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Text(
                '$currentXp / $nextLevelXp',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [accentProfile1, accentProfile2, accentProfile1],
            ),
            boxShadow: [
              BoxShadow(
                color: accentProfile2.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: colorScheme.surface.withOpacity(0.7),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    width: (w) * capped,
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          accentProfile2,
                          accentProfile1,
                          accentProfile2,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentProfile2.withOpacity(0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  if (capped > 0.05)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      width: (w) * capped,
                      height: 20,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0.0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ).animate(onPlay: (controller) => controller.repeat())
                        .shimmer(duration: 2000.ms, delay: 500.ms),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProfileStatCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Duration delay;
  final VoidCallback? onTap;

  const _ProfileStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.delay,
    this.onTap,
  });

  @override
  State<_ProfileStatCard> createState() => _ProfileStatCardState();
}

class _ProfileStatCardState extends State<_ProfileStatCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final cardContent = GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.onTap != null ? (_) {
        setState(() => _isPressed = false);
        HapticFeedback.selectionClick();
        widget.onTap?.call();
      } : null,
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          constraints: const BoxConstraints(minHeight: 80),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                colorScheme.surfaceContainerHigh.withOpacity(0.4),
                colorScheme.surfaceContainer.withOpacity(0.2),
              ]
                  : [
                colorScheme.surfaceContainerHighest.withOpacity(0.5),
                colorScheme.surfaceContainerHigh.withOpacity(0.3),
              ],
            ),
            border: Border.all(
              color: isDark
                  ? colorScheme.outline.withOpacity(0.15)
                  : colorScheme.outline.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.08),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.icon, size: 20, color: colorScheme.primary),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  child: Text(
                    widget.value,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.label,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label: '${widget.label} istatistiği: ${widget.value}',
      button: widget.onTap != null,
      child: cardContent,
    ).animate().fadeIn(duration: 500.ms, delay: widget.delay).slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic);
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
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionNeo({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _pressed
                  ? [
                colorScheme.primaryContainer.withOpacity(0.6),
                colorScheme.secondaryContainer.withOpacity(0.4),
              ]
                  : isDark
                  ? [
                colorScheme.surfaceContainerHigh.withOpacity(0.5),
                colorScheme.surfaceContainer.withOpacity(0.3),
              ]
                  : [
                colorScheme.surfaceContainerHighest.withOpacity(0.4),
                colorScheme.surfaceContainerHigh.withOpacity(0.25),
              ],
            ),
            border: Border.all(
              color: _pressed
                  ? colorScheme.primary.withOpacity(0.3)
                  : isDark
                  ? colorScheme.outline.withOpacity(0.15)
                  : colorScheme.outline.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: _pressed
                ? []
                : [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.08),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                color: _pressed
                    ? colorScheme.primary
                    : colorScheme.onSurface,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.3,
                  color: _pressed
                      ? colorScheme.primary
                      : colorScheme.onSurface,
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
    final colorScheme = Theme.of(context).colorScheme;
    final gold = Colors.amber.shade600;

    return Tooltip(
      message: 'Premium Üye',
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              gold,
              Colors.amber.shade400,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: gold.withOpacity(0.5),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surface,
          ),
          child: Icon(
            Icons.workspace_premium_rounded,
            color: gold,
            size: 20,
          ),
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
        begin: const Offset(1.0, 1.0),
        end: const Offset(1.15, 1.15),
        duration: const Duration(milliseconds: 2000),
        curve: Curves.easeInOut,
      )
          .then()
          .shimmer(
        duration: const Duration(milliseconds: 1500),
        color: Colors.white.withOpacity(0.3),
      ),
    );
  }
}

// =============================================================================
// AVATAR PICKER SHEET - Modern & User-Friendly Design
// =============================================================================

class _AvatarPickerSheet extends ConsumerStatefulWidget {
  final UserModel currentUser;

  const _AvatarPickerSheet({required this.currentUser});

  @override
  ConsumerState<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends ConsumerState<_AvatarPickerSheet> {
  late String selectedStyle;
  late String selectedSeed;
  bool _isUpdating = false;

  final List<String> avatarStyles = [
    'avataaars',
    'adventurer',
    'lorelei',
    'bottts',
    'pixel-art',
    'fun-emoji',
  ];

  @override
  void initState() {
    super.initState();
    selectedStyle = widget.currentUser.avatarStyle ?? 'avataaars';
    selectedSeed = widget.currentUser.avatarSeed ?? widget.currentUser.name ?? 'User${DateTime.now().millisecondsSinceEpoch}';
  }

  String _buildAvatarUrl(String style, String seed) {
    return 'https://api.dicebear.com/9.x/$style/svg?seed=${Uri.encodeComponent(seed)}&backgroundColor=transparent&margin=0&scale=110&size=256';
  }

  Future<void> _updateAvatar() async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);
    HapticFeedback.mediumImpact();

    try {
      final userId = ref.read(authControllerProvider).value?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'avatarStyle': selectedStyle,
        'avatarSeed': selectedSeed,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Profil fotoğrafın güncellendi!'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  void _randomizeAvatar() {
    HapticFeedback.lightImpact();
    setState(() {
      selectedSeed = 'user${DateTime.now().millisecondsSinceEpoch}';
    });
  }

  void _selectStyle(String style) {
    HapticFeedback.selectionClick();
    setState(() {
      selectedStyle = style;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Avatar Seç',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Stilini bul, kendin ol! 🎨',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primaryContainer,
                            colorScheme.secondaryContainer,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.surface,
                        ),
                        child: ClipOval(
                          child: SvgPicture.network(
                            _buildAvatarUrl(selectedStyle, selectedSeed),
                            fit: BoxFit.cover,
                            placeholderBuilder: (_) => Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ).animate().scale(
                      duration: 300.ms,
                      curve: Curves.easeOutBack,
                    ),

                    const SizedBox(width: 20),

                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _randomizeAvatar,
                        icon: const Icon(Icons.casino_rounded, size: 22),
                        label: const Text('Şans Dene'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Flexible(
            child: Container(
              constraints: const BoxConstraints(
                maxHeight: 320,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0,
                ),
                itemCount: avatarStyles.length,
                itemBuilder: (context, index) {
                  final styleKey = avatarStyles[index];
                  final isSelected = selectedStyle == styleKey;

                  return GestureDetector(
                    onTap: () => _selectStyle(styleKey),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ]
                            : null,
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Stack(
                        children: [
                          Center(
                            child: Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.surface,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: SvgPicture.network(
                                  _buildAvatarUrl(styleKey, selectedSeed),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  placeholderBuilder: (_) => Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ).animate(key: ValueKey('$styleKey-$selectedSeed'))
                                .fadeIn(duration: 250.ms)
                                .scale(
                              begin: const Offset(0.85, 0.85),
                              duration: 250.ms,
                              curve: Curves.easeOutBack,
                            ),
                          ),

                          if (isSelected)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: colorScheme.onPrimary,
                                ),
                              ).animate()
                                  .scale(
                                duration: 300.ms,
                                curve: Curves.elasticOut,
                              )
                                  .fadeIn(duration: 200.ms),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        foregroundColor: colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'İptal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: FilledButton(
                      onPressed: _isUpdating ? null : _updateAvatar,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        disabledBackgroundColor: colorScheme.primary.withOpacity(0.5),
                        elevation: 0,
                      ),
                      child: _isUpdating
                          ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: colorScheme.onPrimary,
                        ),
                      )
                          : const Text(
                        'Kaydet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}