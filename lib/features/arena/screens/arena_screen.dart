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
          title: const Text('Zafer Panteonu'),
          backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
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
    final currentUserExam = ref.watch(userProfileProvider).value?.selectedExam;

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
              final itemCount = displayList.length + (showCurrentUserAtBottom ? 1 : 0);

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 36),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (showCurrentUserAtBottom && index == itemCount - 1) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: _CurrentUserCard(entry: currentUserEntry),
                    );
                  }

                  final entry = displayList[index];
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
                          delay: (40 * (index % 10)).ms)
                          .slideX(
                          begin: index.isEven ? -0.06 : 0.06,
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
    return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_moon_rounded, size: 80, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Arena Henüz Boş', style: textTheme.headlineSmall),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Deneme ekleyerek veya Pomodoro seansları tamamlayarak Taktik Puanı kazan ve adını bu panteona yazdır!',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8)));
  }
}

class _CurrentUserCard extends StatelessWidget {
  final LeaderboardEntry entry;

  const _CurrentUserCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Kullanıcı adını snapshot verisinden çek (tutarlılık için)
    String getUsernameDisplay() {
      if (entry.username != null && entry.username!.trim().isNotEmpty) {
        return '@${entry.username!.trim()}';
      }
      return '@user${entry.userId.substring(entry.userId.length - 6)}';
    }

    return Animate(
        effects: [
          SlideEffect(
              begin: const Offset(0, 1),
              duration: 500.ms,
              curve: Curves.easeOutCubic),
          FadeEffect(duration: 500.ms)
        ],
        child: Animate(
          // Pil tasarrufu için: repeat() kaldırıldı, sadece bir kez scale yapılıyor
          effects: [
            ScaleEffect(
                delay: 600.ms,
                duration: 1800.ms,
                begin: const Offset(1, 1),
                end: const Offset(1.015, 1.015),
                curve: Curves.easeInOut)
          ],
          child: Container(
            decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                gradient: LinearGradient(colors: [
                  Theme.of(context).colorScheme.tertiary.withOpacity(0.8),
                  Theme.of(context).colorScheme.secondary.withOpacity(0.8)
                ]),
                boxShadow: [
                  BoxShadow(
                      color: Theme.of(context).colorScheme.tertiary.withOpacity(0.3),
                      blurRadius: 18,
                      spreadRadius: 3),
                ]),
            padding: const EdgeInsets.all(2),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                      Theme.of(context).colorScheme.surface,
                    ]),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Text("Sizin Sıralamanız",
                          style: textTheme.labelLarge
                              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _RankCapsule(rank: entry.rank, highlight: true),
                          const SizedBox(width: 10),
                          CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                            radius: 20,
                            child: ClipOval(
                              child: (entry.avatarStyle != null &&
                                  entry.avatarSeed != null)
                                  ? SvgPicture.network(
                                  'https://api.dicebear.com/9.x/${entry.avatarStyle}/svg?seed=${entry.avatarSeed}',
                                  fit: BoxFit.cover)
                                  : Text(
                                  entry.username != null && entry.username!.isNotEmpty
                                      ? entry.username!.substring(0, 1).toUpperCase()
                                      : '?',
                                  style: textTheme.titleMedium),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // GÜVENLİK: Sadece kullanıcı adı gösteriliyor (13-17 yaş koruması)
                                Text(
                                  getUsernameDisplay(),
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    height: 1.2,
                                    letterSpacing: 0.1,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                // İkinci satır: Sıralama bilgisi
                                Text(
                                  '${entry.testCount} Test',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                    height: 1.1,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('${entry.score} BP',
                              style: textTheme.titleSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.tertiary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 0.3)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ));
  }
}

class _RankCapsule extends StatelessWidget {
  final int rank;
  final bool highlight;
  const _RankCapsule({required this.rank, required this.highlight});
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: 300.ms,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
            colors: highlight
                ? [colorScheme.secondary, colorScheme.primary]
                : [colorScheme.onSurface.withOpacity(0.12), colorScheme.onSurface.withOpacity(0.1)]),
        border: Border.all(
            color: highlight ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.24),
            width: 1),
      ),
      child: Text('#$rank',
          style: textTheme.labelSmall
              ?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w600)),
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
    final textTheme = Theme.of(context).textTheme;
    final progress = topScore > 0 ? (entry.score / topScore).clamp(0.0, 1.0) : 0.0;
    final currentUserId = ref.watch(authControllerProvider).value?.uid;

    // Takip durumunu kontrol et
    final isFollowingAsync = !isCurrentUser && currentUserId != null
        ? ref.watch(isFollowingProvider(entry.userId))
        : null;

    final colorScheme = Theme.of(context).colorScheme;
    // İlk 3 için özel renkler
    Color getSpecialColor() {
      switch (rank) {
        case 1:
          return colorScheme.tertiary; // Altın - 1. sıra
        case 2:
          return colorScheme.secondary; // Gümüş - 2. sıra
        case 3:
          return colorScheme.primary; // Bronz - 3. sıra
        default:
          return colorScheme.onSurface.withOpacity(0.1);
      }
    }

    // Kullanıcı adını snapshot verisinden çek (tutarlılık için)
    String getUsernameDisplay() {
      if (entry.username != null && entry.username!.trim().isNotEmpty) {
        return '@${entry.username!.trim()}';
      }
      return '@user${entry.userId.substring(entry.userId.length - 6)}';
    }

    bool isTopThree = rank <= 3;

    // Modern kart renkleri - İlk 3'e özel
    final cardColor = isCurrentUser
        ? colorScheme.surface.withOpacity(0.15)
        : isTopThree
        ? getSpecialColor().withOpacity(0.15)
        : colorScheme.surface.withOpacity(0.8);

    final borderColor = isCurrentUser
        ? colorScheme.secondary.withOpacity(0.6)
        : isTopThree
        ? getSpecialColor().withOpacity(0.8)
        : colorScheme.onSurface.withOpacity(0.1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardColor,
            cardColor.withOpacity(0.6),
          ],
        ),
        border: Border.all(color: borderColor, width: isTopThree ? 1.8 : 1.0),
        boxShadow: [
          BoxShadow(
            color: isCurrentUser
                ? colorScheme.secondary.withOpacity(0.2)
                : isTopThree
                ? getSpecialColor().withOpacity(0.25)
                : Colors.black.withOpacity(0.08),
            blurRadius: isTopThree ? 14 : 10,
            spreadRadius: isTopThree ? 1 : 0,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Sıralama rozeti - Sol taraf (Rakamlar ve renkler)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _getRankColors(context, rank, isCurrentUser),
                    ),
                    border: Border.all(
                        color: _getRankBorderColor(context, rank, isCurrentUser),
                        width: rank <= 3 ? 2.0 : 1.0
                    ),
                    boxShadow: rank <= 3 ? [
                      BoxShadow(
                        color: _getRankColors(context, rank, isCurrentUser)[0].withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ] : null,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: rank <= 3 ? 14 : 12,
                        shadows: rank <= 3
                            ? [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                          )
                        ]
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Avatar - İlk 3'e özel çerçeve - Küçültüldü
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCurrentUser
                          ? colorScheme.secondary.withOpacity(0.6)
                          : isTopThree
                          ? getSpecialColor().withOpacity(0.8)
                          : colorScheme.onSurface.withOpacity(0.3),
                      width: isTopThree ? 2.5 : 1.5,
                    ),
                    boxShadow: isTopThree
                        ? [
                      BoxShadow(
                        color: getSpecialColor().withOpacity(0.3),
                        blurRadius: 6,
                        spreadRadius: 0.5,
                      )
                    ]
                        : null,
                  ),
                  child: CircleAvatar(
                    backgroundColor: colorScheme.onSurface.withOpacity(0.1),
                    radius: 22,
                    child: ClipOval(
                      child: (entry.avatarStyle != null && entry.avatarSeed != null)
                          ? SvgPicture.network(
                        'https://api.dicebear.com/9.x/${entry.avatarStyle}/svg?seed=${entry.avatarSeed}',
                        fit: BoxFit.cover,
                      )
                          : Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isTopThree
                                ? [
                              getSpecialColor().withOpacity(0.8),
                              getSpecialColor().withOpacity(0.6),
                            ]
                                : [
                              colorScheme.primary.withOpacity(0.8),
                              colorScheme.secondary.withOpacity(0.8),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            entry.username != null && entry.username!.isNotEmpty
                                ? entry.username!.substring(0, 1).toUpperCase()
                                : '?',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Kullanıcı bilgileri (Twitter benzeri) - Pixel perfect
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // GÜVENLİK: Sadece kullanıcı adı (13-17 yaş koruması)
                      Text(
                        getUsernameDisplay(),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          fontSize: 13,
                          height: 1.2,
                          letterSpacing: 0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),

                      // Test sayısı bilgisi
                      Text(
                        '${entry.testCount} Test',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          height: 1.1,
                          letterSpacing: 0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),

                      // Puan ve progress bar - Daha kompakt
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: LinearGradient(
                                colors: isTopThree
                                    ? [
                                  getSpecialColor().withOpacity(0.9),
                                  getSpecialColor().withOpacity(0.7),
                                ]
                                    : [
                                  colorScheme.tertiary.withOpacity(0.8),
                                  colorScheme.tertiary.withOpacity(0.6),
                                ],
                              ),
                            ),
                            child: Text(
                              '${entry.score} BP',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onTertiary,
                                fontWeight: FontWeight.w600,
                                fontSize: 9,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(1),
                                color: colorScheme.onSurface.withOpacity(0.12),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(1),
                                    gradient: LinearGradient(
                                      colors: isCurrentUser
                                          ? [colorScheme.primary, colorScheme.secondary]
                                          : isTopThree
                                          ? [getSpecialColor(), getSpecialColor().withOpacity(0.7)]
                                          : [colorScheme.tertiary, colorScheme.secondary],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Takip et butonu - EN SAĞDA ve çalışır halde
                if (!isCurrentUser)
                  isFollowingAsync?.when(
                    data: (isFollowing) => Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: isFollowing
                              ? [
                            colorScheme.primary.withOpacity(0.9),
                            colorScheme.primary.withOpacity(0.7),
                          ]
                              : [
                            colorScheme.secondary.withOpacity(0.9),
                            colorScheme.surface.withOpacity(0.9),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isFollowing ? colorScheme.primary : colorScheme.secondary)
                                .withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            if (currentUserId == null) return;

                            HapticFeedback.lightImpact();

                            try {
                              final firestore = ref.read(firestoreServiceProvider);

                              if (isFollowing) {
                                // Takipten çıkar
                                await firestore.unfollowUser(
                                  currentUserId: currentUserId,
                                  targetUserId: entry.userId,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${entry.userName} takipten çıkarıldı!'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: colorScheme.error,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              } else {
                                // Takip et
                                await firestore.followUser(
                                  currentUserId: currentUserId,
                                  targetUserId: entry.userId,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${entry.userName} takip edildi!'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: colorScheme.primary,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Bir hata oluştu: $e'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: colorScheme.error,
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isFollowing ? Icons.check : Icons.person_add_rounded,
                                  size: 14,
                                  color: colorScheme.onSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isFollowing ? 'Takipte' : 'Takip Et',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    loading: () => Container(
                      width: 80,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: colorScheme.onSurface.withOpacity(0.1),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(colorScheme.onSurface),
                          ),
                        ),
                      ),
                    ),
                    error: (error, stack) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: colorScheme.onSurface.withOpacity(0.1),
                      ),
                      child: Text(
                        'Takip Et',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ) ??
                      const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _getRankColors(BuildContext context, int rank, bool isCurrentUser) {
    final colorScheme = Theme.of(context).colorScheme;
    if (isCurrentUser) {
      return [
        colorScheme.secondary,
        colorScheme.primary,
      ];
    } else {
      switch (rank) {
        case 1:
          return [
            colorScheme.tertiary,
            colorScheme.tertiary.withOpacity(0.7),
          ];
        case 2:
          return [
            colorScheme.secondary,
            colorScheme.secondary.withOpacity(0.7),
          ];
        case 3:
          return [
            colorScheme.primary,
            colorScheme.primary.withOpacity(0.7),
          ];
        default:
          return [colorScheme.onSurface.withOpacity(0.2), colorScheme.onSurface.withOpacity(0.1)];
      }
    }
  }

  Color _getRankBorderColor(BuildContext context, int rank, bool isCurrentUser) {
    final colorScheme = Theme.of(context).colorScheme;
    if (isCurrentUser) {
      return colorScheme.primary.withOpacity(0.8);
    } else {
      switch (rank) {
        case 1:
          return colorScheme.tertiary;
        case 2:
          return colorScheme.secondary;
        case 3:
          return colorScheme.primary;
        default:
          return colorScheme.onSurface.withOpacity(0.3);
      }
    }
  }
}
