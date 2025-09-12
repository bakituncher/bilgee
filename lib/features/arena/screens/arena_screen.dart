// lib/features/arena/screens/arena_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/arena/models/leaderboard_entry_model.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/core/navigation/app_routes.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class ArenaScreen extends ConsumerWidget {
  const ArenaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          backgroundColor: AppTheme.primaryColor.withOpacity(0.5),
          bottom: TabBar(
            indicatorColor: AppTheme.secondaryColor,
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

    return RefreshIndicator(
      color: AppTheme.secondaryColor,
      backgroundColor: AppTheme.cardColor,
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor,
              AppTheme.scaffoldBackgroundColor,
            ],
            stops: [0.0, 0.7],
          ),
        ),
        child: SafeArea(
          top: false,
          child: leaderboardAsync.when(
            data: (entries) {
              if (entries.isEmpty) return _buildEmptyState(context);

              final fullList = entries;
              final topThree = fullList.take(3).toList();
              final restOfTheList =
              fullList.length > 3 ? fullList.sublist(3) : <LeaderboardEntry>[];

              final currentUserIndex =
              fullList.indexWhere((e) => e.userId == currentUserId);
              final currentUserEntry =
              currentUserIndex != -1 ? fullList[currentUserIndex] : null;
              final showCurrentUserAtBottom =
                  currentUserEntry != null && currentUserIndex >= 20;
              final topScore = fullList.isNotEmpty
                  ? (fullList.first.score == 0 ? 1 : fullList.first.score)
                  : 1;

              final itemCount =
                  restOfTheList.length + (showCurrentUserAtBottom ? 1 : 0) + 1;

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _PodiumDisplay(
                        topThree: topThree, currentUserId: currentUserId);
                  }

                  if (showCurrentUserAtBottom && index == itemCount - 1) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: _CurrentUserCard(entry: currentUserEntry),
                    );
                  }

                  final realIndex = index - 1;
                  final entry = restOfTheList[realIndex];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push('${AppRoutes.arena}/${entry.userId}');
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _RankCard(
                        entry: entry,
                        rank: entry.rank,
                        isCurrentUser: entry.userId == currentUserId,
                        topScore: topScore,
                      )
                          .animate()
                          .fadeIn(
                          duration: 350.ms,
                          delay: (40 * (realIndex % 10)).ms)
                          .slideX(
                          begin: realIndex.isEven ? -0.06 : 0.06,
                          end: 0,
                          duration: 420.ms,
                          curve: Curves.easeOutCubic),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(
                child:
                CircularProgressIndicator(color: AppTheme.secondaryColor)),
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
            const Icon(Icons.shield_moon_rounded,
                size: 80, color: AppTheme.secondaryTextColor),
            const SizedBox(height: 16),
            Text('Arena Henüz Boş', style: textTheme.headlineSmall),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Deneme ekleyerek veya Pomodoro seansları tamamlayarak Bilgelik Puanı kazan ve adını bu panteona yazdır!',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge
                    ?.copyWith(color: AppTheme.secondaryTextColor),
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
    return Animate(
        effects: [
          SlideEffect(
              begin: const Offset(0, 1),
              duration: 500.ms,
              curve: Curves.easeOutCubic),
          FadeEffect(duration: 500.ms)
        ],
        child: Animate(
          onPlay: (c) => c.repeat(reverse: true),
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
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(30)),
                gradient: LinearGradient(colors: [
                  AppTheme.goldColor.withOpacity(0.8),
                  AppTheme.secondaryColor.withOpacity(0.8)
                ]),
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.goldColor.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 4),
                ]),
            padding: const EdgeInsets.all(2),
            child: Container(
              decoration: BoxDecoration(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.lightSurfaceColor,
                      AppTheme.cardColor,
                    ]),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Text("Sizin Sıralamanız",
                          style: textTheme.labelLarge
                              ?.copyWith(color: AppTheme.secondaryTextColor)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _RankCapsule(rank: entry.rank, highlight: true),
                          const SizedBox(width: 12),
                          CircleAvatar(
                            backgroundColor: Colors.white10,
                            radius: 22,
                            child: ClipOval(
                              child: (entry.avatarStyle != null &&
                                  entry.avatarSeed != null)
                                  ? SvgPicture.network(
                                  'https://api.dicebear.com/9.x/${entry.avatarStyle}/svg?seed=${entry.avatarSeed}',
                                  fit: BoxFit.cover)
                                  : Text(
                                  entry.userName.isNotEmpty
                                      ? entry.userName
                                      .substring(0, 1)
                                      .toUpperCase()
                                      : '?',
                                  style: textTheme.titleMedium),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.userName,
                              style: textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('${entry.score} BP',
                              style: textTheme.titleSmall?.copyWith(
                                  color: AppTheme.goldColor,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5)),
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

class _PodiumDisplay extends StatelessWidget {
  final List<LeaderboardEntry> topThree;
  final String? currentUserId;
  const _PodiumDisplay({required this.topThree, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final entries = topThree.length > 1
        ? [
      topThree[1],
      topThree[0],
      if (topThree.length > 2) topThree[2],
    ]
        : topThree;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(entries.length, (index) {
          final entry = entries[index];
          final isFirstPlace = entries.length > 1 && index == 1;
          return _PodiumPlaceCard(
            entry: entry,
            isCurrentUser: entry.userId == currentUserId,
            isFirstPlace: isFirstPlace,
          )
              .animate()
              .slideY(
              begin: 1,
              duration: 600.ms,
              delay: (200 * index).ms,
              curve: Curves.easeOutCubic)
              .fadeIn();
        }),
      ),
    );
  }
}

class _PodiumPlaceCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isCurrentUser;
  final bool isFirstPlace;

  const _PodiumPlaceCard({
    required this.entry,
    this.isCurrentUser = false,
    this.isFirstPlace = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final medalColor = switch (entry.rank) {
      1 => AppTheme.goldColor,
      2 => AppTheme.secondaryColor,
      3 => AppTheme.successColor,
      _ => Colors.white54,
    };
    final height = isFirstPlace ? 180.0 : 150.0;
    final avatarRadius = isFirstPlace ? 32.0 : 26.0;

    return GestureDetector(
      onTap: () => context.push('${AppRoutes.arena}/${entry.userId}'),
      child: Container(
        width: 110,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              medalColor.withOpacity(0.5),
              medalColor.withOpacity(0.1)
            ],
          ),
          border: Border.all(color: medalColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: medalColor.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: Colors.white10,
                  child: ClipOval(
                    child: (entry.avatarStyle != null &&
                        entry.avatarSeed != null)
                        ? SvgPicture.network(
                        'https://api.dicebear.com/9.x/${entry.avatarStyle}/svg?seed=${entry.avatarSeed}',
                        fit: BoxFit.cover)
                        : Text(
                        entry.userName.isNotEmpty
                            ? entry.userName.substring(0, 1).toUpperCase()
                            : '?',
                        style: textTheme.titleMedium),
                  ),
                ),
                Positioned(
                  bottom: -10,
                  child:
                  _RankCapsule(rank: entry.rank, highlight: isCurrentUser),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              entry.userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text('${entry.score} BP',
                style: textTheme.labelSmall?.copyWith(
                    color: AppTheme.goldColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _RankCapsule extends StatelessWidget {
  final int rank;
  final bool highlight;
  const _RankCapsule({super.key, required this.rank, required this.highlight});
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: 300.ms,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
            colors: highlight
                ? [AppTheme.secondaryColor, AppTheme.successColor]
                : [Colors.white12, Colors.white10]),
        border: Border.all(
            color: highlight ? Colors.white : Colors.white24, width: 1),
      ),
      child: Text('#$rank',
          style: textTheme.labelSmall
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}

class _RankCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  final bool isCurrentUser;
  final int? topScore;

  const _RankCard(
      {required this.entry,
        required this.rank,
        this.isCurrentUser = false,
        this.topScore});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final progress = (topScore != null && topScore! > 0)
        ? (entry.score / topScore!).clamp(0.0, 1.0)
        : 0.0;

    final cardColor = isCurrentUser
        ? AppTheme.secondaryColor.withOpacity(0.2)
        : AppTheme.cardColor.withOpacity(0.15);
    final borderColor =
    isCurrentUser ? AppTheme.secondaryColor : Colors.white24;

    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isCurrentUser
                  ? AppTheme.secondaryColor.withOpacity(0.25)
                  : Colors.black.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: -2,
              offset: const Offset(0, 6),
            )
          ]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(1.4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: 1.5),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cardColor, cardColor.withOpacity(0.5)],
                stops: const [0.0, 1.0],
              ),
            ),
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          child: (entry.avatarStyle != null &&
                              entry.avatarSeed != null)
                              ? SvgPicture.network(
                              'https://api.dicebear.com/9.x/${entry.avatarStyle}/svg?seed=${entry.avatarSeed}',
                              fit: BoxFit.cover)
                              : Text(
                              entry.userName.isNotEmpty
                                  ? entry.userName
                                  .substring(0, 1)
                                  .toUpperCase()
                                  : '?',
                              style: textTheme.titleMedium),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.userName,
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('${entry.score} BP',
                          style: textTheme.titleSmall?.copyWith(
                              color: AppTheme.secondaryColor,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                    ],
                  ),
                  if (topScore != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation(isCurrentUser
                            ? AppTheme.successColor
                            : AppTheme.secondaryColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}