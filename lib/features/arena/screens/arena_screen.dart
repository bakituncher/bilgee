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
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';
import 'package:lottie/lottie.dart';
import 'package:taktik/shared/widgets/pro_badge.dart';

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

class _LeaderboardView extends ConsumerStatefulWidget {
  final String period; // 'daily' | 'weekly'
  const _LeaderboardView({required this.period});

  @override
  ConsumerState<_LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends ConsumerState<_LeaderboardView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUserId = ref.watch(authControllerProvider).value?.uid;
    final currentUser = ref.watch(userProfileProvider).value;
    final currentUserExam = currentUser?.selectedExam;

    if (currentUserExam == null) return const SizedBox.shrink();

    final leaderboardAsync = widget.period == 'weekly'
        ? ref.watch(leaderboardWeeklyProvider(currentUserExam))
        : ref.watch(leaderboardDailyProvider(currentUserExam));

    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      color: colorScheme.secondary,
      backgroundColor: colorScheme.surface,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        if (widget.period == 'weekly') {
          ref.invalidate(leaderboardWeeklyProvider(currentUserExam));
        } else {
          ref.invalidate(leaderboardDailyProvider(currentUserExam));
        }
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: Container(
        color: colorScheme.surface,
        child: leaderboardAsync.when(
          data: (entries) {
            if (entries.isEmpty) return _buildEmptyState(context);

            final fullList = entries;
            final currentUserIndex = fullList.indexWhere((e) => e.userId == currentUserId);
            final currentUserEntry = currentUserIndex != -1 ? fullList[currentUserIndex] : null;

            // Eğer kullanıcı ilk 20'de DEĞİLSE, aşağıda sticky card göster
            final showStickyCard = currentUserEntry != null && currentUserIndex >= 20;

            final displayList = fullList.take(20).toList();
            final itemCount = displayList.length;

            return Stack(
              children: [
                ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    12,
                    16,
                    12,
                    showStickyCard ? 100 : 24,
                  ),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    final entry = displayList[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.push('${AppRoutes.arena}/${entry.userId}');
                        },
                        child: _RankCard(
                          entry: entry,
                          rank: entry.rank,
                          isCurrentUser: entry.userId == currentUserId,
                        )
                            .animate()
                            .fadeIn(duration: 350.ms, delay: (40 * (index % 10)).ms)
                            .slideX(begin: 0.05, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
                      ),
                    );
                  },
                ),
                if (showStickyCard)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _StickyUserCard(entry: currentUserEntry),
                  ),
              ],
            );
          },
          loading: () => const LogoLoader(),
          error: (err, stack) => Center(child: Text('Hata oluştu: $err')),
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
              Lottie.asset(
                'assets/lotties/Kart Flag Animation.json',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              Text(
                'Arena Henüz Boş',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Taktik Puanı kazan ve adını bu panteona yazdır!',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Listenin altında sabit duran kullanıcı kartı
class _StickyUserCard extends StatelessWidget {
  final LeaderboardEntry entry;

  const _StickyUserCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, -4),
          )
        ],
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: _RankCard(
          entry: entry,
          rank: entry.rank,
          isCurrentUser: true,
          forceHighlight: true,
        ),
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  final bool isCurrentUser;
  final bool forceHighlight;

  const _RankCard({
    required this.entry,
    required this.rank,
    required this.isCurrentUser,
    this.forceHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Kart Renkleri
    final Color cardColor = (isCurrentUser || forceHighlight)
        ? cs.primary.withValues(alpha: 0.08)
        : cs.surfaceContainerLow;

    final Color borderColor = (isCurrentUser || forceHighlight)
        ? cs.primary.withValues(alpha: 0.4)
        : Colors.transparent;

    // Kullanıcı adı işleme
    String username = entry.username?.trim() ?? '';
    if (username.isEmpty) username = 'User ${entry.userId.substring(0, 4)}';
    if (!username.startsWith('@')) username = '@$username';

    return Container(
      // Padding horizontal 10 -> 8 olarak düşürüldü (Daha sıkı görünüm)
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Sıralama Badge (Genişlik 32 -> 24'e düşürüldü)
          SizedBox(
            width: 24,
            child: _RankBadge(rank: rank),
          ),

          // Boşluk 10 -> 8'e düşürüldü
          const SizedBox(width: 8),

          // 2. Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: (entry.avatarStyle != null && entry.avatarSeed != null)
                  ? SvgPicture.network(
                'https://api.dicebear.com/9.x/${entry.avatarStyle}/svg?seed=${entry.avatarSeed}',
                fit: BoxFit.cover,
              )
                  : Center(
                child: Text(
                  username.length > 1 ? username.substring(1, 2).toUpperCase() : '?',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 3. İsim ve Badge Bölümü
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        username,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: isCurrentUser ? FontWeight.w800 : FontWeight.w600,
                          color: cs.onSurface,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.isPremium) ...[
                      const SizedBox(width: 6),
                      const ProBadge(
                        fontSize: 8.5,
                        horizontalPadding: 5,
                        verticalPadding: 2.5,
                        borderRadius: 4,
                      ),
                    ],
                  ],
                ),
                if (isCurrentUser)
                  Padding(
                    padding: const EdgeInsets.only(top: 3.0),
                    child: Text(
                      "Siz",
                      style: textTheme.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 4. Puan Bölümü - OKUNURLUK DÜZELTİLDİ
          Container(
            constraints: const BoxConstraints(minWidth: 72),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              // Eski: cs.primaryContainer.withValues(alpha: 0.3) -> Okunması zordu.
              // Yeni: Tam solid primaryContainer veya SurfaceVariant
              color: cs.primaryContainer, // Alpha kaldırıldı, net zemin.
              borderRadius: BorderRadius.circular(12),
              // Border kaldırıldı, solid renkte gerek yok.
            ),
            child: Text(
              '${entry.score}',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                // Eski: cs.primary -> Mavi üstüne mavi okunmuyordu.
                // Yeni: onPrimaryContainer -> Mavi zemin üstüne en uygun kontrast (genelde koyu lacivert veya beyaz).
                color: cs.onPrimaryContainer,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    // İkon boyutları biraz küçültüldü (28/26) ki dar alana sığsın
    if (rank == 1) {
      return const Icon(
        Icons.emoji_events_rounded,
        color: Color(0xFFFFD700),
        size: 28,
      );
    } else if (rank == 2) {
      return const Icon(
        Icons.emoji_events_rounded,
        color: Color(0xFFC0C0C0),
        size: 26,
      );
    } else if (rank == 3) {
      return const Icon(
        Icons.emoji_events_rounded,
        color: Color(0xFFCD7F32),
        size: 26,
      );
    }

    // Diğerleri için sayı - Ortalanmış
    return Center(
      child: Text(
        '$rank',
        style: textTheme.titleMedium?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          fontSize: 15, // Font biraz küçültüldü
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}