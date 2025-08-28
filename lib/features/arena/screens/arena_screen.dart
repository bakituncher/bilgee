// lib/features/arena/screens/arena_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/arena/models/leaderboard_entry_model.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';
import 'package:go_router/go_router.dart'; // YENİ: Navigasyon için import
import 'package:bilge_ai/core/navigation/app_routes.dart'; // YENİ: Rota isimleri için import
import 'package:flutter_svg/flutter_svg.dart'; // YENİ: Avatar için import
import 'package:flutter/services.dart'; // Haptic feedback

class ArenaScreen extends ConsumerWidget {
  const ArenaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(userProfileProvider).value;

    if (currentUser == null || currentUser.selectedExam == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Zafer Panteonu')),
        body: const Center(child: Text("Arenaya girmek için bir sınav seçmelisiniz.")),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Zafer Panteonu'),
          backgroundColor: AppTheme.primaryColor.withValues(alpha: AppTheme.primaryColor.a * 0.5),
          bottom: const TabBar(
            indicatorColor: AppTheme.secondaryColor,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
            tabs: [
              Tab(text: 'Bu Haftanın Onuru'),
              Tab(text: 'Tüm Zamanların Efsaneleri'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LeaderboardView(isAllTime: false),
            _LeaderboardView(isAllTime: true),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardView extends ConsumerWidget {
  final bool isAllTime;
  const _LeaderboardView({required this.isAllTime});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(authControllerProvider).value?.uid;
    final currentUserExam = ref.watch(userProfileProvider).value?.selectedExam;
    if (currentUserExam == null) return const SizedBox.shrink();
    final leaderboardAsync = ref.watch(leaderboardProvider(currentUserExam));

    return RefreshIndicator(
      color: _accent1,
      backgroundColor: AppTheme.cardColor,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        final _ = await ref.refresh(leaderboardProvider(currentUserExam).future); // uyarı giderildi
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _bgGradient,
          ),
        ),
        child: SafeArea(
          top: false,
          child: leaderboardAsync.when(
            data: (entries) {
              if (entries.isEmpty) return _buildEmptyState(context);

              final currentUserIndex = entries.indexWhere((e) => e.userId == currentUserId);
              final currentUserEntry = currentUserIndex != -1 ? entries[currentUserIndex] : null;
              final hasDetachedCurrentUser = currentUserEntry != null && currentUserIndex >= 15;
              final topScore = entries.first.score == 0 ? 1 : entries.first.score;

              // Liste + (current user alt) + featured header (yatay) => featured header ayrı sliver benzeri ilk item
              final itemCount = entries.length + (hasDetachedCurrentUser ? 1 : 0) + 1; // +1 featured scroller

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _FeaturedScroller(entries: entries.take(5).toList(), currentUserId: currentUserId)
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: -0.05, end: 0, duration: 450.ms, curve: Curves.easeOutCubic);
                  }
                  final lastIndexForUser = itemCount - 1;
                  final isCurrentUserDetachedCard = hasDetachedCurrentUser && index == lastIndexForUser;
                  if (isCurrentUserDetachedCard) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: _CurrentUserCard(entry: currentUserEntry, rank: currentUserIndex + 1),
                    );
                  }
                  // Normal entries: shift by 1 (featured)
                  final realIndex = index - 1; // 0-based entries index
                  final entry = entries[realIndex];
                  final rank = realIndex + 1;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push('${AppRoutes.arena}/${entry.userId}');
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _RankCard(
                        entry: entry,
                        rank: rank,
                        isCurrentUser: entry.userId == currentUserId && !hasDetachedCurrentUser,
                        topScore: topScore,
                      )
                          .animate()
                          .fadeIn(duration: 350.ms, delay: (40 * (realIndex % 10)).ms)
                          .slideX(begin: realIndex.isEven ? -0.06 : 0.06, end: 0, duration: 420.ms, curve: Curves.easeOutCubic),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor)),
            error: (err, stack) => Center(child: Text('Liderlik tablosu yüklenemedi: $err')),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_moon_rounded, size: 80, color: AppTheme.secondaryTextColor),
            const SizedBox(height: 16),
            Text('Arena Henüz Boş', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Deneme ekleyerek veya Pomodoro seansları tamamlayarak Bilgelik Puanı kazan ve adını bu panteona yazdır!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8)));
  }
}

// NovaPulse renkleri (lokal)
const _accent1 = Color(0xFF7F5BFF);
const _accent2 = Color(0xFF6BFF7A);
const List<Color> _bgGradient = [Color(0xFF0B0F14), Color(0xFF2A155A), Color(0xFF061F38)];

class _FeaturedScroller extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final String? currentUserId;
  const _FeaturedScroller({required this.entries, required this.currentUserId});
  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScaleFactorOf(context);
    final base = 174.0; // 150 -> 174 overflow fix
    final extra = ((ts - 1) * 44).clamp(0, 52); // biraz daha tolerans
    final containerHeight = base + extra; // dinamik yükseklik
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.trending_up, color: _accent2, size: 20),
              const SizedBox(width: 6),
              Text('Öne Çıkanlar', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        SizedBox(
          height: containerHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final e = entries[i];
              final rank = i + 1;
              final isUser = e.userId == currentUserId;
              return _FeaturedCard(entry: e, rank: rank, isCurrentUser: isUser)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: (70 * i).ms)
                  .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), duration: 450.ms, curve: Curves.easeOutBack);
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  final bool isCurrentUser;
  const _FeaturedCard({super.key, required this.entry, required this.rank, required this.isCurrentUser});
  @override
  Widget build(BuildContext context) {
    final medalColor = switch (rank) {
      1 => _accent2,
      2 => _accent1,
      3 => Colors.orangeAccent,
      _ => Colors.white54,
    };
    return GestureDetector(
      onTap: () => context.push('${AppRoutes.arena}/${entry.userId}'),
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0x1AFFFFFF),
              const Color(0x0FFFFFFF),
              const Color(0x14FFFFFF),
            ],
          ),
          border: Border.all(color: medalColor.o(0.6), width: 1.4),
          boxShadow: [
            if (rank == 1)
              BoxShadow(color: _accent2.o(0.55), blurRadius: 24, spreadRadius: 2),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (rank <= 3)
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [medalColor.o(0.9), medalColor.o(0.25)]),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 1200.ms, curve: Curves.easeInOut),
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white10,
                  child: ClipOval(
                    child: (entry.avatarStyle != null && entry.avatarSeed != null)
                        ? SvgPicture.network('https://api.dicebear.com/9.x/${entry.avatarStyle}/svg?seed=${entry.avatarSeed}', fit: BoxFit.cover)
                        : Text(entry.userName.isNotEmpty ? entry.userName.substring(0,1).toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6), // 8 -> 6
            Text(
              entry.userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2), // 4 -> 2
            Text('${entry.score} BP', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: _accent2, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 2), // 4 -> 2
            _RankCapsule(rank: rank, highlight: isCurrentUser),
            const SizedBox(height: 4), // Spacer kaldırıldı overflow engellendi
          ],
        ),
      ),
    );
  }
}

class _RankCapsule extends StatelessWidget {
  final int rank; final bool highlight;
  const _RankCapsule({super.key, required this.rank, required this.highlight});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: 300.ms,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: highlight ? [_accent2, _accent1] : [Colors.white12, Colors.white10]),
        border: Border.all(color: highlight ? Colors.white : Colors.white24, width: 1),
      ),
      child: Text('#$rank', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}

class _RankCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  final bool isCurrentUser;
  final int? topScore; // progress bar için

  const _RankCard({required this.entry, required this.rank, this.isCurrentUser = false, this.topScore});

  @override
  Widget build(BuildContext context) {
    final base = AppTheme.cardColor.o(isCurrentUser ? 0.9 : 0.55);
    final borderGrad = rank <= 3
        ? [
            if (rank == 1) _accent2 else _accent1,
            if (rank == 1) _accent1 else _accent2,
          ]
        : [_accent1.o(0.35), _accent2.o(0.35)];
    final progress = (topScore != null && topScore! > 0) ? (entry.score / topScore!).clamp(0.0, 1.0) : 0.0;

    return Semantics(
      label: 'Sıra $rank, kullanıcı ${entry.userName}, puan ${entry.score}',
      child: AnimatedContainer(
        duration: 350.ms,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(colors: borderGrad),
        ),
        padding: const EdgeInsets.all(1.4),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: base,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _RankCapsule(rank: rank, highlight: isCurrentUser),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    backgroundColor: Colors.white10,
                    radius: 22,
                    child: ClipOval(
                      child: (entry.avatarStyle != null && entry.avatarSeed != null)
                          ? SvgPicture.network('https://api.dicebear.com/9.x/${entry.avatarStyle}/svg?seed=${entry.avatarSeed}', fit: BoxFit.cover)
                          : Text(entry.userName.isNotEmpty ? entry.userName.substring(0,1).toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.userName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${entry.score} BP', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: _accent2, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ],
              ),
              if (topScore != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white.o(0.06),
                    valueColor: AlwaysStoppedAnimation(rank <= 3 ? _accent2 : _accent1),
                  ),
                ),
              ],
            ],
          ),
        ),
      ));
  }
}

class _CurrentUserCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  const _CurrentUserCard({required this.entry, required this.rank});

  @override
  Widget build(BuildContext context) {
    return Animate(
      effects: [SlideEffect(begin: const Offset(0,1), duration: 500.ms, curve: Curves.easeOutCubic), FadeEffect(duration: 500.ms)],
      child: Animate(
        onPlay: (c) => c.repeat(reverse: true),
        effects: [ScaleEffect(delay: 600.ms, duration: 1800.ms, begin: const Offset(1,1), end: const Offset(1.015,1.015), curve: Curves.easeInOut)],
        child: Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            gradient: LinearGradient(colors: [_accent2, _accent1]),
          ),
          padding: const EdgeInsets.all(2),
          child: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1B2534), Color(0xFF1F2D46)]),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8,10,8,10),
              child: SafeArea(
                top: false,
                child: _RankCard(entry: entry, rank: rank, isCurrentUser: true, topScore: null),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Color extension (withOpacity yerine)
extension _ColorOpacityX on Color {
  Color o(double factor) => withValues(alpha: (a * factor).toDouble());
}
