// lib/features/profile/screens/ranks_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/features/profile/logic/rank_service.dart';
import 'package:taktik/data/providers/firestore_providers.dart';

typedef RankInfo = ({Rank current, Rank next, double progress});

class RanksScreen extends ConsumerStatefulWidget {
  const RanksScreen({super.key});

  @override
  ConsumerState<RanksScreen> createState() => _RanksScreenState();
}

class _RanksScreenState extends ConsumerState<RanksScreen> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _headerAnimationController;
  double _scrollProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _onScroll() {
    final currentScroll = _scrollController.position.pixels;
    setState(() {
      _scrollProgress = (currentScroll / 200).clamp(0.0, 1.0);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: colorScheme.surface.withOpacity(_scrollProgress * 0.95),
        elevation: _scrollProgress > 0.5 ? 2 : 0,
        title: Opacity(
          opacity: _scrollProgress,
          child: const Text('Seviye Yolculuğun'),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: _scrollProgress * 10,
              sigmaY: _scrollProgress * 10,
            ),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_outlined, size: 64, color: colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('Kullanıcı bulunamadı', style: textTheme.bodyLarge),
                ],
              ),
            );
          }

          final currentScore = user.engagementScore;
          final rankInfo = RankService.getRankInfo(currentScore);
          final currentRankIndex = RankService.ranks.indexOf(rankInfo.current);

          return Stack(
            children: [
              // Animated gradient background
              _AnimatedGradientBackground(
                color: rankInfo.current.color,
                progress: _scrollProgress,
              ),

              // Main content
              CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Hero Header
                  SliverToBoxAdapter(
                    child: _HeroHeader(
                      rankInfo: rankInfo,
                      currentScore: currentScore,
                      currentRankIndex: currentRankIndex,
                    ),
                  ),

                  // Stats Cards
                  SliverToBoxAdapter(
                    child: _StatsSection(
                      currentScore: currentScore,
                      rankInfo: rankInfo,
                      currentRankIndex: currentRankIndex,
                    ),
                  ),

                  // Section Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [rankInfo.current.color, rankInfo.current.color.withOpacity(0.3)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Tüm Seviyeler',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${RankService.ranks.length} seviye',
                              style: textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 600.ms)
                    .slideX(begin: -0.1, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
                  ),

                  // Rank List with Timeline
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final rank = RankService.ranks[index];
                          final isUnlocked = currentScore >= rank.requiredScore;
                          final isCurrent = index == currentRankIndex;
                          final isNext = index == currentRankIndex + 1;
                          final isLast = index == RankService.ranks.length - 1;

                          return _TimelineRankCard(
                            rank: rank,
                            index: index,
                            isUnlocked: isUnlocked,
                            isCurrent: isCurrent,
                            isNext: isNext,
                            isLast: isLast,
                            currentScore: currentScore,
                            totalRanks: RankService.ranks.length,
                          );
                        },
                        childCount: RankService.ranks.length,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withOpacity(0.1),
                colorScheme.secondary.withOpacity(0.1),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(strokeWidth: 3),
                const SizedBox(height: 16),
                Text('Seviyeler yükleniyor...', style: textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Bir hata oluştu', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('$error', style: textTheme.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// Animated Gradient Background Widget
class _AnimatedGradientBackground extends StatelessWidget {
  final Color color;
  final double progress;

  const _AnimatedGradientBackground({
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15 - (progress * 0.1)),
            color.withOpacity(0.05 - (progress * 0.03)),
            Theme.of(context).scaffoldBackgroundColor,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
    );
  }
}

// Hero Header Widget
class _HeroHeader extends StatelessWidget {
  final RankInfo rankInfo;
  final int currentScore;
  final int currentRankIndex;

  const _HeroHeader({
    required this.rankInfo,
    required this.currentScore,
    required this.currentRankIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isMaxRank = currentRankIndex >= RankService.ranks.length - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 120, 24, 32),
      child: Column(
        children: [
          // Rank Icon with Glow Effect
          Stack(
            alignment: Alignment.center,
            children: [
              // Glow effect
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: rankInfo.current.color.withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(duration: 2000.ms, begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1))
              .then()
              .scale(duration: 2000.ms, begin: const Offset(1.1, 1.1), end: const Offset(0.9, 0.9)),

              // Main icon container
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      rankInfo.current.color.withOpacity(0.2),
                      rankInfo.current.color.withOpacity(0.1),
                    ],
                  ),
                  border: Border.all(
                    color: rankInfo.current.color.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  rankInfo.current.icon,
                  size: 60,
                  color: rankInfo.current.color,
                ),
              )
              .animate()
              .scale(
                duration: 800.ms,
                curve: Curves.elasticOut,
              )
              .shimmer(delay: 400.ms, duration: 1500.ms),
            ],
          ),

          const SizedBox(height: 24),

          // Rank Name
          Text(
            rankInfo.current.name,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          )
          .animate()
          .fadeIn(duration: 600.ms, delay: 200.ms)
          .slideY(begin: 0.3, end: 0, duration: 600.ms, delay: 200.ms),

          const SizedBox(height: 8),

          // Current Score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: rankInfo.current.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: rankInfo.current.color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.stars_rounded,
                  color: rankInfo.current.color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '$currentScore TP',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: rankInfo.current.color,
                  ),
                ),
              ],
            ),
          )
          .animate()
          .fadeIn(duration: 600.ms, delay: 400.ms)
          .scale(duration: 600.ms, delay: 400.ms, curve: Curves.easeOutBack),

          if (isMaxRank) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade700, Colors.amber.shade500],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Maksimum Seviye!',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(duration: 2000.ms)
            .then()
            .shake(hz: 2, duration: 500.ms),
          ],
        ],
      ),
    );
  }
}

// Stats Section Widget
class _StatsSection extends StatelessWidget {
  final int currentScore;
  final RankInfo rankInfo;
  final int currentRankIndex;

  const _StatsSection({
    required this.currentScore,
    required this.rankInfo,
    required this.currentRankIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isMaxRank = currentRankIndex >= RankService.ranks.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          if (!isMaxRank) ...[
            // Next Rank Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: rankInfo.next.color.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: rankInfo.next.color.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: rankInfo.next.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          rankInfo.next.icon,
                          color: rankInfo.next.color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sonraki Hedef',
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              rankInfo.next.name,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: rankInfo.next.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: rankInfo.next.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${(rankInfo.progress * 100).toInt()}%',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: rankInfo.next.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Progress Bar
                  Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: rankInfo.progress,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                rankInfo.next.color,
                                rankInfo.next.color.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: rankInfo.next.color.withOpacity(0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      )
                      .animate()
                      .scaleX(
                        duration: 1200.ms,
                        delay: 600.ms,
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.centerLeft,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 16,
                            color: rankInfo.next.color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${rankInfo.next.requiredScore - currentScore} TP kaldı',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: rankInfo.next.color,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${rankInfo.next.requiredScore} TP',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 600.ms, delay: 300.ms)
            .slideY(begin: 0.2, end: 0, duration: 600.ms, delay: 300.ms, curve: Curves.easeOutCubic),
          ],

          const SizedBox(height: 16),

          // Stats Grid
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.military_tech,
                  label: 'Mevcut Sıra',
                  value: '${currentRankIndex + 1}/${RankService.ranks.length}',
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.lock_open_rounded,
                  label: 'Açılan',
                  value: '${currentRankIndex + 1}',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.lock_outline_rounded,
                  label: 'Kilitli',
                  value: '${RankService.ranks.length - currentRankIndex - 1}',
                  color: colorScheme.outline,
                ),
              ),
            ],
          )
          .animate()
          .fadeIn(duration: 600.ms, delay: 400.ms)
          .slideY(begin: 0.2, end: 0, duration: 600.ms, delay: 400.ms, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }
}

// Stat Card Widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Timeline Rank Card Widget
class _TimelineRankCard extends StatelessWidget {
  final Rank rank;
  final int index;
  final bool isUnlocked;
  final bool isCurrent;
  final bool isNext;
  final bool isLast;
  final int currentScore;
  final int totalRanks;

  const _TimelineRankCard({
    required this.rank,
    required this.index,
    required this.isUnlocked,
    required this.isCurrent,
    required this.isNext,
    required this.isLast,
    required this.currentScore,
    required this.totalRanks,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Node
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnlocked
                        ? rank.color.withOpacity(0.15)
                        : colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: isUnlocked ? rank.color : colorScheme.outline.withOpacity(0.3),
                      width: isCurrent ? 3 : 2,
                    ),
                  ),
                  child: Center(
                    child: isUnlocked
                        ? Icon(
                            isCurrent ? Icons.radio_button_checked : Icons.check_circle,
                            color: rank.color,
                            size: 20,
                          )
                        : Icon(
                            Icons.lock_outline,
                            color: colorScheme.outline.withOpacity(0.5),
                            size: 18,
                          ),
                  ),
                )
                .animate()
                .scale(
                  duration: 600.ms,
                  delay: Duration(milliseconds: 100 * index),
                  curve: Curves.elasticOut,
                ),

                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isUnlocked
                              ? [rank.color, rank.color.withOpacity(0.3)]
                              : [
                                  colorScheme.outline.withOpacity(0.3),
                                  colorScheme.outline.withOpacity(0.1),
                                ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Card
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCurrent
                      ? rank.color
                      : isUnlocked
                          ? rank.color.withOpacity(0.2)
                          : colorScheme.outline.withOpacity(0.2),
                  width: isCurrent ? 2 : 1,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: rank.color.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showRankDetails(context, rank, isUnlocked, isCurrent, isNext);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Rank Icon
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isUnlocked
                                    ? rank.color.withOpacity(0.15)
                                    : colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                rank.icon,
                                size: 24,
                                color: isUnlocked
                                    ? rank.color
                                    : colorScheme.onSurfaceVariant.withOpacity(0.5),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Rank Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          rank.name,
                                          style: textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isUnlocked
                                                ? colorScheme.onSurface
                                                : colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      if (isCurrent)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [rank.color, rank.color.withOpacity(0.7)],
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Mevcut',
                                            style: textTheme.labelSmall?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                        .animate(onPlay: (controller) => controller.repeat())
                                        .shimmer(duration: 2000.ms),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.stars_rounded,
                                        size: 14,
                                        color: isUnlocked
                                            ? rank.color
                                            : colorScheme.onSurfaceVariant.withOpacity(0.5),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${rank.requiredScore} TP',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: isUnlocked
                                              ? colorScheme.onSurface.withOpacity(0.7)
                                              : colorScheme.onSurfaceVariant.withOpacity(0.5),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (isNext && !isUnlocked) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorScheme.secondaryContainer,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${rank.requiredScore - currentScore} TP kaldı',
                                            style: textTheme.labelSmall?.copyWith(
                                              color: colorScheme.onSecondaryContainer,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            Icon(
                              Icons.chevron_right_rounded,
                              color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                              size: 24,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .animate()
            .fadeIn(
              duration: 500.ms,
              delay: Duration(milliseconds: 100 * index),
            )
            .slideX(
              begin: 0.2,
              end: 0,
              duration: 600.ms,
              delay: Duration(milliseconds: 100 * index),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }

  void _showRankDetails(
    BuildContext context,
    Rank rank,
    bool isUnlocked,
    bool isCurrent,
    bool isNext,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                const SizedBox(height: 32),

                // Icon with Glow
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: rank.color.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            rank.color.withOpacity(0.2),
                            rank.color.withOpacity(0.1),
                          ],
                        ),
                        border: Border.all(
                          color: rank.color.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        rank.icon,
                        size: 48,
                        color: rank.color,
                      ),
                    ),
                  ],
                )
                .animate()
                .scale(duration: 600.ms, curve: Curves.elasticOut)
                .shimmer(delay: 300.ms, duration: 1500.ms),

                const SizedBox(height: 24),

                // Rank Name
                Text(
                  rank.name,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: rank.color,
                  ),
                  textAlign: TextAlign.center,
                )
                .animate()
                .fadeIn(duration: 500.ms, delay: 200.ms)
                .slideY(begin: 0.2, end: 0, duration: 500.ms, delay: 200.ms),

                const SizedBox(height: 16),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isCurrent
                        ? LinearGradient(colors: [rank.color, rank.color.withOpacity(0.7)])
                        : null,
                    color: isCurrent
                        ? null
                        : isNext
                            ? colorScheme.secondaryContainer
                            : isUnlocked
                                ? Colors.green
                                : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isCurrent
                        ? 'Mevcut Seviyeniz'
                        : isNext
                            ? 'Sonraki Hedefiniz'
                            : isUnlocked
                                ? 'Kilidi Açıldı ✓'
                                : 'Kilitli Seviye',
                    style: textTheme.labelLarge?.copyWith(
                      color: isCurrent || isUnlocked ? Colors.white : colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // XP Info Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: rank.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: rank.color.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stars_rounded, color: rank.color, size: 24),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gereken TP',
                            style: textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${rank.requiredScore} TP',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: rank.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (!isUnlocked && isNext) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.trending_up_rounded,
                          color: colorScheme.onSecondaryContainer,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hedefe kalan',
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSecondaryContainer.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${rank.requiredScore - currentScore} TP',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Anlaşıldı',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

