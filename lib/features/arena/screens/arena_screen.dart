// lib/features/arena/screens/arena_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/arena/models/leaderboard_entry_model.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';
import 'package:taktik/shared/widgets/ad_banner_widget.dart';
import 'package:lottie/lottie.dart';

class ArenaScreen extends ConsumerStatefulWidget {
  const ArenaScreen({super.key});

  @override
  ConsumerState<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends ConsumerState<ArenaScreen> {
  @override
  void initState() {
    super.initState();
    // Quest entegrasyonu: Arena ziyareti
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        try {
          await ref.read(questNotifierProvider.notifier).userParticipatedInArena();
        } catch (e) {
          // Quest hatası uygulamayı etkilemesin
          debugPrint('Arena quest error: $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(userProfileProvider).value;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    if (currentUser == null || currentUser.selectedExam == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Zafer Panteonu')),
        body: const Center(
            child: Text("Arenaya girmek için bir sınav seçmelisiniz.")),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Zafer Panteonu',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.5,
              fontSize: 20,
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
          bottom: TabBar(
            indicatorColor: Theme.of(context).colorScheme.secondary,
            indicatorWeight: 3,
            labelStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            unselectedLabelStyle: textTheme.bodyLarge,
            tabs: const [
              Tab(text: 'Günlük Efsaneler'),
              Tab(text: 'Haftalık Efsaneler'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LeaderboardView(period: 'daily'),
            _LeaderboardView(period: 'weekly'),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardView extends ConsumerWidget {
  final String period; // 'daily' | 'weekly'
  const _LeaderboardView({required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(authControllerProvider).value?.uid;
    final currentUser = ref.watch(userProfileProvider).value;
    final currentUserExam = currentUser?.selectedExam;

    if (currentUserExam == null) return const SizedBox.shrink();
    final leaderboardAsync = period == 'weekly'
        ? ref.watch(leaderboardWeeklyProvider(currentUserExam))
        : ref.watch(leaderboardDailyProvider(currentUserExam));
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      color: colorScheme.secondary,
      backgroundColor: colorScheme.surface,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        if (period == 'weekly') {
          ref.invalidate(leaderboardWeeklyProvider(currentUserExam));
        } else {
          ref.invalidate(leaderboardDailyProvider(currentUserExam));
        }
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surface,
            ],
            stops: const [0.0, 0.7],
          ),
        ),
        child: SafeArea(
          top: false,
          child: leaderboardAsync.when(
            data: (entries) {
              if (entries.isEmpty) return _buildEmptyState(context);

              final fullList = entries;
              final currentUserIndex =
              fullList.indexWhere((e) => e.userId == currentUserId);
              final currentUserEntry =
              currentUserIndex != -1 ? fullList[currentUserIndex] : null;
              final showCurrentUserAtBottom =
                  currentUserEntry != null && currentUserIndex >= 20;
              final topScore = fullList.isNotEmpty
                  ? (fullList.first.score == 0 ? 1 : fullList.first.score)
                  : 1;

              final displayList = fullList.take(20).toList();
              final itemCount = displayList.length + (showCurrentUserAtBottom ? 1 : 0) + 1; // +1 for banner

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 36),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  // Banner at the top (hidden for premium users)
                  if (index == 0) {
                    final isPremium = currentUser?.isPremium ?? false;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: AdBannerWidget(
                        isPremium: isPremium,
                        dateOfBirth: currentUser?.dateOfBirth,
                      ),
                    );
                  }

                  if (showCurrentUserAtBottom && index == displayList.length + 1) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: _CurrentUserCard(entry: currentUserEntry),
                    );
                  }

                  // Banner'dan sonraki indeksleri ayarla
                  final listIndex = index - 1;
                  if (listIndex < 0 || listIndex >= displayList.length) {
                    return const SizedBox.shrink();
                  }

                  final entry = displayList[listIndex];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push('${AppRoutes.arena}/${entry.userId}');
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _RankCard(
                        entry: entry,
                        rank: entry.rank,
                        isCurrentUser: entry.userId == currentUserId,
                        topScore: topScore,
                      )
                          .animate()
                          .fadeIn(
                          duration: 350.ms,
                          delay: (40 * (listIndex % 10)).ms)
                          .slideX(
                          begin: listIndex.isEven ? -0.06 : 0.06,
                          end: 0,
                          duration: 420.ms,
                          curve: Curves.easeOutCubic),
                    ),
                  );
                },
              );
            },
            loading: () => const LogoLoader(),
            error: (err, stack) =>
                Center(child: Text('Liderlik tablosu yüklenemedi: $err')),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lottie Animasyonu
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.15),
                      colorScheme.surface,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
                child: Lottie.asset(
                  'assets/lotties/Kart Flag Animation.json',
                  fit: BoxFit.contain,
                  repeat: true,
                  animate: true,
                ),
              )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 100.ms)
                  .scale(
                    begin: const Offset(0.7, 0.7),
                    end: const Offset(1.0, 1.0),
                    duration: 700.ms,
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 32),

              // Başlık
              Text(
                'Arena Henüz Boş',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 300.ms)
                  .slideY(begin: 0.3, end: 0, duration: 500.ms, curve: Curves.easeOut),

              const SizedBox(height: 16),

              // Açıklama Metni
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'İlk efsanelerden ol!',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 400.ms)
                  .slideY(begin: 0.3, end: 0, duration: 500.ms, curve: Curves.easeOut),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Deneme ekleyerek veya Pomodoro seansları tamamlayarak Taktik Puanı kazan ve adını bu panteona yazdır!',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 500.ms)
                  .slideY(begin: 0.3, end: 0, duration: 500.ms, curve: Curves.easeOut),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentUserCard extends StatelessWidget {
  final LeaderboardEntry entry;

  const _CurrentUserCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // Kullanıcı adını snapshot verisinden çek (tutarlılık için)
    String getUsernameDisplay() {
      if (entry.username != null && entry.username!.trim().isNotEmpty) {
        return '@${entry.username!.trim()}';
      }
      return '@user${entry.userId.substring(entry.userId.length - 6)}';
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        color: colorScheme.primary.withValues(alpha: 0.12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          children: [
            Text(
              "Sizin Sıralamanız",
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _RankCapsule(rank: entry.rank),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.18),
                  radius: 20,
                  child: ClipOval(
                    child: (entry.avatarStyle != null && entry.avatarSeed != null)
                        ? SvgPicture.network(
                            'https://api.dicebear.com/9.x/${entry.avatarStyle}/svg?seed=${entry.avatarSeed}',
                            fit: BoxFit.cover,
                          )
                        : Center(
                            child: Text(
                              entry.username != null && entry.username!.isNotEmpty
                                  ? entry.username!.substring(0, 1).toUpperCase()
                                  : '?',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    getUsernameDisplay(),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${entry.score} TP',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RankCapsule extends StatelessWidget {
  final int rank;
  const _RankCapsule({required this.rank});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.primary.withValues(alpha: 0.16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
      ),
      child: Text(
        '#$rank',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

class _RankCard extends ConsumerWidget {
  final LeaderboardEntry entry;
  final int rank;
  final bool isCurrentUser;
  final int topScore;

  const _RankCard({
    required this.entry,
    required this.rank,
    required this.isCurrentUser,
    required this.topScore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = topScore > 0 ? (entry.score / topScore).clamp(0.0, 1.0) : 0.0;
    final currentUserId = ref.watch(authControllerProvider).value?.uid;
    final isFollowingAsync = !isCurrentUser && currentUserId != null
        ? ref.watch(isFollowingProvider(entry.userId))
        : null;
    final cs = Theme.of(context).colorScheme;

    String getUsernameDisplay() {
      if (entry.username != null && entry.username!.trim().isNotEmpty) {
        return '@${entry.username!.trim()}';
      }
      return '@user${entry.userId.substring(entry.userId.length - 6)}';
    }

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: cs.primary.withValues(alpha: 0.12),
          border: Border.all(color: cs.primary.withValues(alpha: 0.35), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Rank kapsülü tek tip
              _RankCapsule(rank: rank),
              const SizedBox(width: 12),
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: cs.primary.withValues(alpha: 0.18),
                child: ClipOval(
                  child: (entry.avatarStyle != null && entry.avatarSeed != null)
                      ? SvgPicture.network(
                          'https://api.dicebear.com/9.x/${entry.avatarStyle}/svg?seed=${entry.avatarSeed}',
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: Text(
                            entry.username != null && entry.username!.isNotEmpty
                                ? entry.username!.substring(0, 1).toUpperCase()
                                : '?',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Bilgiler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      getUsernameDisplay(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                            fontSize: 13,
                          ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: cs.primary.withValues(alpha: 0.18),
                          ),
                          child: Text(
                            '${entry.score} TP',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                  letterSpacing: 0.4,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: cs.onSurface.withValues(alpha: 0.12),
                                ),
                              ),
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progress,
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    color: cs.primary, // doldurma
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isCurrentUser)
                isFollowingAsync?.when(
                      data: (isFollowing) => OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: BorderSide(
                            color: cs.primary.withValues(alpha: isFollowing ? 0.8 : 0.35),
                          ),
                          foregroundColor: cs.onSurface,
                          textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        onPressed: () async {
                          if (currentUserId == null) return;
                          HapticFeedback.lightImpact();
                          try {
                            final firestore = ref.read(firestoreServiceProvider);
                            if (isFollowing) {
                              await firestore.unfollowUser(
                                currentUserId: currentUserId,
                                targetUserId: entry.userId,
                              );
                            } else {
                              await firestore.followUser(
                                currentUserId: currentUserId,
                                targetUserId: entry.userId,
                              );
                              // Başarılı takip bildirimi eklendi
                              if (context.mounted) {
                                final username = entry.username?.trim() ?? '';
                                // 1. Önce varsa ekrandaki eski bildirimleri temizle (Seri basma sorunu çözümü)
                                ScaffoldMessenger.of(context).clearSnackBars();

                                // 2. Yeni ve şık bildirimi göster
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    // İçerik: İkon + Metin yan yana
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.white),
                                        const SizedBox(width: 12), // İkon ile yazı arası boşluk
                                        Expanded(
                                          child: Text(
                                            '${username.isNotEmpty ? "@$username" : "Kullanıcı"} takip edildi!',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600, // Yazıyı biraz kalınlaştır
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Görünüm Ayarları
                                    behavior: SnackBarBehavior.floating, // Alt tarafta havada asılı durur
                                    backgroundColor: const Color(0xFF323232), // Koyu gri modern arka plan
                                    elevation: 4, // Hafif gölge
                                    margin: const EdgeInsets.all(16), // Kenarlardan boşluk bırakır
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12), // Kenarları yumuşat
                                    ),
                                    duration: const Duration(milliseconds: 1500), // 1.5 saniye (daha seri hissettirir)
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Hata: $e'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Text(isFollowing ? 'Takipte' : 'Takip Et'),
                      ),
                      loading: () => const SizedBox(
                        width: 60,
                        height: 26,
                        child: Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      error: (error, stack) => OutlinedButton(
                        onPressed: () {},
                        child: const Text('Takip'),
                      ),
                    ) ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}


