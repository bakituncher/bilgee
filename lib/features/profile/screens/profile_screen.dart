// lib/features/profile/screens/profile_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/data/models/focus_session_model.dart';
import 'package:bilge_ai/features/profile/models/badge_model.dart' as app_badge;
import 'package:bilge_ai/core/navigation/app_routes.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Avatar için eklendi
import 'package:flutter/services.dart'; // HapticFeedback
import 'dart:math' as math; // trig için
import '../logic/rank_service.dart';
import 'package:bilge_ai/data/models/performance_summary.dart';
import 'package:bilge_ai/data/models/plan_document.dart'; // EKLENDİ

// ===== NovaPulse / Arena ile tutarlı premium accent renkleri =====
const _accentProfile1 = Color(0xFF7F5BFF); // elektrik moru
const _accentProfile2 = Color(0xFF6BFF7A); // neon lime
const List<Color> _profileBgGradient = [Color(0xFF0B0F14), Color(0xFF2A155A), Color(0xFF061F38)];

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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Çıkış Yap"),
          content: const Text("Oturumu sonlandırmak istediğinizden emin misiniz?"),
          actions: <Widget>[
            TextButton(
              child: const Text("İptal", style: TextStyle(color: AppTheme.secondaryTextColor)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Çıkış Yap", style: TextStyle(color: AppTheme.accentColor)),
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

  List<app_badge.Badge> _generateBadges(UserModel user, PerformanceSummary performance, PlanDocument? planDoc, int testCount, double avgNet, List<FocusSessionModel> focusSessions) {
    return [
      app_badge.Badge(name: 'İlk Adım', description: 'İlk denemeni başarıyla ekledin ve zafere giden yola çıktın.', icon: Icons.flag, color: AppTheme.successColor, isUnlocked: testCount >= 1, hint: "İlk denemeni ekleyerek başla."),
      app_badge.Badge(name: 'Acemi Savaşçı', description: '5 farklı denemede savaş meydanının tozunu attın.', icon: Icons.shield_outlined, color: AppTheme.successColor, isUnlocked: testCount >= 5, rarity: app_badge.BadgeRarity.common, hint: "Toplam 5 deneme ekle."),
      app_badge.Badge(name: 'Kıdemli Savaşçı', description: '15 deneme! Artık bu işin kurdu olmaya başladın.', icon: Icons.shield, color: AppTheme.successColor, isUnlocked: testCount >= 15, rarity: app_badge.BadgeRarity.rare, hint: "Toplam 15 deneme ekle."),
      app_badge.Badge(name: 'Deneme Fatihi', description: 'Tam 50 denemeyi arşivine ekledin. Önünde kimse duramaz!', icon: Icons.military_tech, color: AppTheme.successColor, isUnlocked: testCount >= 50, rarity: app_badge.BadgeRarity.epic, hint: "Toplam 50 deneme ekle."),
      app_badge.Badge(name: 'Kıvılcım', description: 'Ateşi yaktın! 3 günlük çalışma serisine ulaştın.', icon: Icons.whatshot_outlined, color: Colors.orange, isUnlocked: user.streak >= 3, hint: "3 gün ara vermeden çalış."),
      app_badge.Badge(name: 'Alev Ustası', description: 'Tam 14 gün boyunca disiplini elden bırakmadın. Bu bir irade zaferidir!', icon: Icons.local_fire_department, color: Colors.orange, isUnlocked: user.streak >= 14, rarity: app_badge.BadgeRarity.rare, hint: "14 günlük seriye ulaş."),
      app_badge.Badge(name: 'Durdurulamaz', description: '30 gün! Sen artık bir alışkanlık abidesisin.', icon: Icons.wb_sunny, color: Colors.orange, isUnlocked: user.streak >= 30, rarity: app_badge.BadgeRarity.epic, hint: "Tam 30 gün ara verme."),
      app_badge.Badge(name: 'Yükseliş', description: 'Ortalama 50 net barajını aştın. Bu daha başlangıç!', icon: Icons.trending_up, color: Colors.blueAccent, isUnlocked: avgNet > 50, hint: "Net ortalamanı 50'nin üzerine çıkar."),
      app_badge.Badge(name: 'Usta Nişancı', description: 'Ortalama 90 net! Elitler arasına hoş geldin.', icon: Icons.gps_not_fixed, color: Colors.blueAccent, isUnlocked: avgNet > 90, rarity: app_badge.BadgeRarity.rare, hint: "Net ortalamanı 90'ın üzerine çıkar."),
      app_badge.Badge(name: 'Bilge Nişancı', description: 'Ortalama 100 net barajını yıktın. Sen bir efsanesin!', icon: Icons.workspace_premium, color: Colors.blueAccent, isUnlocked: avgNet > 100, rarity: app_badge.BadgeRarity.epic, hint: "Net ortalamanı 100'ün üzerine çıkar."),
      app_badge.Badge(name: 'Stratejist', description: 'BilgeAI ile ilk uzun vadeli stratejini oluşturdun.', icon: Icons.insights, color: Colors.purpleAccent, isUnlocked: planDoc?.longTermStrategy != null, hint: "AI Hub'da stratejini oluştur."),
      app_badge.Badge(name: 'Haftanın Hakimi', description: 'Bir haftalık plandaki tüm görevleri tamamladın.', icon: Icons.checklist, color: Colors.purpleAccent, isUnlocked: (user.completedDailyTasks.values.expand((e) => e).length) >= 15, rarity: app_badge.BadgeRarity.rare, hint: "Bir haftalık plandaki tüm görevleri bitir."),
      app_badge.Badge(name: 'Odaklanma Ninjası', description: 'Toplam 10 saat Pomodoro tekniği ile odaklandın.', icon: Icons.timer, color: Colors.purpleAccent, isUnlocked: focusSessions.fold(0, (p, c) => p + c.durationInSeconds) >= 36000, rarity: app_badge.BadgeRarity.rare, hint: "Toplam 10 saat odaklan."),
      app_badge.Badge(name: 'Cevher Avcısı', description: 'Cevher Atölyesi\'nde ilk zayıf konunu işledin.', icon: Icons.construction, color: AppTheme.secondaryColor, isUnlocked: performance.topicPerformances.isNotEmpty, hint: "Cevher Atölyesi'ni kullan."),
      app_badge.Badge(name: 'Arena Gladyatörü', description: 'Liderlik tablosuna girerek adını duyurdun.', icon: Icons.leaderboard, color: AppTheme.secondaryColor, isUnlocked: user.engagementScore > 0, rarity: app_badge.BadgeRarity.common, hint: "Etkileşim puanı kazan."),
      app_badge.Badge(name: 'Efsane', description: 'Tüm madalyaları toplayarak ölümsüzleştin!', icon: Icons.auto_stories, color: Colors.amber, isUnlocked: false, rarity: app_badge.BadgeRarity.legendary, hint: "Tüm diğer madalyaları kazan."),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final testsAsync = ref.watch(testsProvider);
    final focusSessionsAsync = ref.watch(focusSessionsProvider);
    final performanceAsync = ref.watch(performanceProvider);
    final planDocAsync = ref.watch(planProvider);

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
        title: const Text('Komuta Merkezi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.push(AppRoutes.settings),
            tooltip: 'Ayarlar',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context, ref),
            tooltip: 'Güvenli Çıkış',
          )
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Komutan bulunamadı.'));

          return focusSessionsAsync.when(
            data: (focusSessions) {
              final tests = testsAsync.valueOrNull ?? [];
              final performance = performanceAsync.value;
              final planDoc = planDocAsync.value;

              if (performance == null) return const Center(child: CircularProgressIndicator());

              final testCount = tests.length;
              final avgNet = testCount > 0 ? user.totalNetSum / testCount : 0.0;
              final allBadges = _generateBadges(user, performance, planDoc, testCount, avgNet, focusSessions);
              final unlockedCount = allBadges.where((b) => b.isUnlocked).length;

              final rankInfo = RankService.getRankInfo(user.engagementScore);
              final currentRank = rankInfo.current;
              final nextRank = rankInfo.next;
              final progressToNext = rankInfo.progress;
              final rankIndex = RankService.ranks.indexOf(currentRank);

              return Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _profileBgGradient),
                    ),
                  ),
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
                                _ProfileAvatarHalo(user: user, color: currentRank.color, rankIndex: rankIndex),
                                const SizedBox(height: 14),
                                Text(
                                  user.name ?? 'İsimsiz Savaşçı',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5),
                                  textAlign: TextAlign.center,
                                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),
                                const SizedBox(height: 8),
                                _RankPill(rank: currentRank).animate().fadeIn(duration: 400.ms, delay: 120.ms).slideY(begin: 0.15),
                                const SizedBox(height: 20),
                                _NeoXpBar(
                                  currentXp: user.engagementScore,
                                  nextLevelXp: nextRank.requiredScore == currentRank.requiredScore ? currentRank.requiredScore : nextRank.requiredScore,
                                  progress: progressToNext,
                                ).animate().fadeIn(duration: 450.ms, delay: 200.ms),
                                const SizedBox(height: 28),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ProfileStatCard(
                                        label: 'Deneme',
                                        value: testCount.toString(),
                                        icon: Icons.library_books_rounded,
                                        delay: 260.ms,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: _ProfileStatCard(
                                        label: 'Ort. Net',
                                        value: avgNet.toStringAsFixed(1),
                                        icon: Icons.track_changes_rounded,
                                        delay: 320.ms,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ProfileStatCard(
                                        label: 'Günlük Seri',
                                        value: user.streak.toString(),
                                        icon: Icons.local_fire_department_rounded,
                                        delay: 380.ms,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: _ProfileStatCard(
                                        label: 'Madalyalar',
                                        value: '$unlockedCount/${allBadges.length}',
                                        icon: Icons.military_tech_rounded,
                                        delay: 440.ms,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
                                _ProfileQuickActions(
                                  onHonorWall: () => context.push('/profile/honor-wall', extra: allBadges),
                                  onStrategy: () => context.push('${AppRoutes.aiHub}/${AppRoutes.commandCenter}', extra: user),
                                  onAvatar: () => context.push('/profile/avatar-selection'),
                                ).animate().fadeIn(delay: 520.ms).slideY(begin: 0.12),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    numberOfParticles: 30,
                    gravity: 0.2,
                    colors: const [AppTheme.secondaryColor, AppTheme.successColor, Colors.white, Colors.amber],
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor)),
            error: (e, s) => Center(child: Text('Odaklanma verileri yüklenemedi: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor)),
        error: (e, s) => Center(child: Text('Karargâh Yüklenemedi: $e')),
      ),
    );
  }
}

// === Diğer widget'lar değişmediği için kısaltıldı ===
class _ProfileAvatarHalo extends StatelessWidget {
  final UserModel user; final Color color; final int rankIndex;
  const _ProfileAvatarHalo({required this.user, required this.color, required this.rankIndex});
  String _avatarUrl(String style, String seed) => 'https://api.dicebear.com/9.x/'
      '$style/svg?seed=$seed&backgroundColor=transparent&margin=0&scale=110&size=256';

  bool get _midTier => rankIndex >= 3;
  bool get _highTier => rankIndex >= 6;
  bool get _legendTier => rankIndex >= 8;
  bool get _apexTier => rankIndex >= 9;

  @override
  Widget build(BuildContext context) {
    const double outerSize = 170;
    const double avatarDiameter = 126;
    final primaryGlow = color.o(0.30);
    final secondaryGlow = _highTier ? _accentProfile1.o(0.25) : _accentProfile2.o(0.18);

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _HaloRing(color: _accentProfile1.o(0.20), size: 150, begin: 0.90, end: 1.05, delay: 0.ms),
          if (_midTier)
            _HaloRing(color: _accentProfile2.o(0.16), size: 132, begin: 0.92, end: 1.07, delay: 250.ms),
          if (_highTier)
            _HaloRing(color: primaryGlow, size: 164, begin: 0.95, end: 1.03, delay: 600.ms),
          if (_legendTier)
            _PulsingCore(size: 60, color: _accentProfile2.o(0.20)),

          if (_highTier)
            _RotatingRing(
              size: 158,
              stroke: 3,
              gradient: SweepGradient(colors: [
                _accentProfile2.o(0.0),
                _accentProfile2.o(0.7),
                _accentProfile1.o(0.8),
                _accentProfile2.o(0.0),
              ]),
              duration: _apexTier ? const Duration(seconds: 10) : const Duration(seconds: 18),
            ),

          if (_legendTier)
            ...List.generate(10 + (rankIndex * 2).clamp(0, 12), (i) => _SparkParticle(index: i, radius: 78, apex: _apexTier)),

          if (rankIndex >= 4)
            Positioned(
              top: 4.0 + (10 - rankIndex).clamp(0,6).toDouble(),
              child: Opacity(
                opacity: (0.35 + (rankIndex * 0.07)).clamp(0.4, 1.0),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: rankIndex >= 8 ? _accentProfile2 : _accentProfile1.o(0.9),
                  size: 26 + (rankIndex * 1.8),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1.05, 1.05),
                  duration: (1600 - (rankIndex * 40)).clamp(900, 1600).ms,
                  curve: Curves.easeInOut,
                ),
              ),
            ),

          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: CustomPaint(
                painter: _RankFramePainter(
                  rankIndex: rankIndex,
                  color: color,
                  intensity: 0.35 + (rankIndex * 0.04).clamp(0, 0.4),
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
                _apexTier ? _accentProfile2 : _accentProfile2.o(0.9),
                _apexTier ? _accentProfile1 : _accentProfile1.o(0.9),
              ]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: secondaryGlow, blurRadius: 28, spreadRadius: 2),
                if (_highTier) BoxShadow(color: _accentProfile2.o(0.25), blurRadius: 40, spreadRadius: 6),
              ],
            ),
            child: Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
              child: ClipOval(
                child: user.avatarStyle != null && user.avatarSeed != null
                    ? SvgPicture.network(
                  _avatarUrl(user.avatarStyle!, user.avatarSeed!),
                  fit: BoxFit.cover,
                  width: avatarDiameter,
                  height: avatarDiameter,
                  placeholderBuilder: (_) => Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        valueColor: AlwaysStoppedAnimation(_accentProfile2),
                      ),
                    ),
                  ),
                  semanticsLabel: 'Kullanıcı avatarı',
                )
                    : Center(
                  child: Text(
                    user.name?.substring(0, 1).toUpperCase() ?? 'B',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: _accentProfile2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 480.ms).scale(curve: Curves.easeOutBack),
        ],
      ),
    );
  }
}

class _RankFramePainter extends CustomPainter {
  final int rankIndex; final Color color; final double intensity;
  _RankFramePainter({required this.rankIndex, required this.color, required this.intensity});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width/2, size.height/2);
    final radius = size.width/2 - 12;
    final tier = rankIndex;
    final base = color;
    final accent = rankIndex >= 6 ? _accentProfile2 : _accentProfile1;
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
  final double size; final double stroke; final Gradient gradient; final Duration duration;
  const _RotatingRing({required this.size, required this.stroke, required this.gradient, required this.duration});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: duration,
          onEnd: () {},
          curve: Curves.linear,
          builder: (context, value, child) {
            return Transform.rotate(
              angle: value * 6.28318,
              child: CustomPaint(
                painter: _RingPainter(gradient: gradient, stroke: stroke),
              ),
            );
          },
        ).animate(onPlay: (c) => c.repeat()));
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
  final double size; final Color color;
  const _PulsingCore({required this.size, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    ).animate(onPlay: (c)=> c.repeat(reverse: true))
        .scale(begin: const Offset(0.85,0.85), end: const Offset(1.1,1.1), duration: 2400.ms, curve: Curves.easeInOut)
        .fadeIn(duration: 800.ms);
  }
}

class _SparkParticle extends StatelessWidget {
  final int index; final double radius; final bool apex;
  const _SparkParticle({required this.index, required this.radius, required this.apex});
  @override
  Widget build(BuildContext context) {
    final angle = (index / 12) * 2 * math.pi;
    final dist = radius + (index % 3) * 4;
    final dx = dist * math.cos(angle);
    final dy = dist * math.sin(angle);
    final baseColor = apex ? _accentProfile2 : _accentProfile1;
    return Positioned(
        left: (radius + 10) + dx,
        top: (radius + 10) + dy,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: baseColor.o(0.9),
            boxShadow: [BoxShadow(color: baseColor.o(0.6), blurRadius: 8, spreadRadius: 1)],
          ),
        ).animate(onPlay: (c)=> c.repeat())
            .fade(begin: 0.1, end: 1, duration: (1500 + (index*120)).ms)
            .scale(begin: const Offset(0.6,0.6), end: const Offset(1.3,1.3), duration: (1600 + (index*90)).ms, curve: Curves.easeInOut));
  }
}

class _HaloRing extends StatelessWidget {
  final Color color; final double size; final double begin; final double end; final Duration delay;
  const _HaloRing({required this.color, required this.size, required this.begin, required this.end, required this.delay});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(begin: Offset(begin, begin), end: Offset(end, end), duration: 3000.ms, curve: Curves.easeInOut, delay: delay)
        .fadeIn(duration: 1100.ms, delay: delay);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.flash_on_rounded, size: 18, color: _accentProfile2),
            const SizedBox(width: 6),
            Text('Rütbe Puanı', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('$currentXp / $nextLevelXp', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(colors: [_accentProfile1, _accentProfile2]),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black.o(0.55),
                    ),
                  ),
                  AnimatedContainer(
                    duration: 700.ms,
                    curve: Curves.easeOutCubic,
                    width: (w) * capped,
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [_accentProfile2, _accentProfile1]),
                      boxShadow: [
                        BoxShadow(color: _accentProfile2.o(0.4), blurRadius: 18, spreadRadius: 1),
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
    return Semantics(
      label: '$label istatistiği: $value',
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x1FFFFFFF), Color(0x0DFFFFFF)]),
          border: Border.all(color: Colors.white.o(0.12), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: _accentProfile2),
              const Spacer(),
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white70)),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 400.ms, delay: delay).slideY(begin: 0.22, end: 0, curve: Curves.easeOutCubic),
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
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: 140.ms,
        curve: Curves.easeOut,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x221F1F1F), Color(0x111F1F1F)]),
            border: Border.all(color: Colors.white.o(0.12), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: _accentProfile1, size: 22),
              const SizedBox(width: 8),
              Text(widget.label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

extension _ColorOpacityXProfile on Color { Color o(double factor) => withValues(alpha: (a * factor).toDouble()); }