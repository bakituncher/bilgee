// lib/features/profile/screens/ranks_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/features/profile/logic/rank_service.dart';
import 'package:taktik/data/providers/firestore_providers.dart';

class RanksScreen extends ConsumerWidget {
  const RanksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seviye Yolculuğun'),
        elevation: 0,
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: userAsync.when(
          data: (user) {
            if (user == null) {
              return const Center(child: Text('Kullanıcı bulunamadı'));
            }

            final currentScore = user.engagementScore;
            final rankInfo = RankService.getRankInfo(currentScore);
            final currentRankIndex = RankService.ranks.indexOf(rankInfo.current);

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Mevcut Seviye Kartı - Modern ve Sade
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: rankInfo.current.color.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: rankInfo.current.color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      rankInfo.current.icon,
                                      size: 32,
                                      color: rankInfo.current.color,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          rankInfo.current.name,
                                          style: textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: rankInfo.current.color,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$currentScore XP',
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: colorScheme.onSurface.withOpacity(0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (currentRankIndex < RankService.ranks.length - 1) ...[
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Sonraki: ${rankInfo.next.name}',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                    Text(
                                      '${(rankInfo.progress * 100).toInt()}%',
                                      style: textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: rankInfo.next.color,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: rankInfo.progress,
                                    minHeight: 6,
                                    backgroundColor: colorScheme.surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation<Color>(rankInfo.next.color),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${rankInfo.next.requiredScore - currentScore} XP kaldı!',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Maksimum Seviye',
                                        style: textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  // Seviye Listesi
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final rank = RankService.ranks[index];
                          final isUnlocked = currentScore >= rank.requiredScore;
                          final isCurrent = index == currentRankIndex;
                          final isNext = index == currentRankIndex + 1;

                          return _RankCard(
                            rank: rank,
                            index: index,
                            isUnlocked: isUnlocked,
                            isCurrent: isCurrent,
                            isNext: isNext,
                            currentScore: currentScore,
                          );
                        },
                        childCount: RankService.ranks.length,
                      ),
                    ),
                  ),
                ],
              );
            },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Hata: $error'),
          ),
        ),
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  final Rank rank;
  final int index;
  final bool isUnlocked;
  final bool isCurrent;
  final bool isNext;
  final int currentScore;

  const _RankCard({
    required this.rank,
    required this.index,
    required this.isUnlocked,
    required this.isCurrent,
    required this.isNext,
    required this.currentScore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? rank.color
              : isUnlocked
                  ? rank.color.withOpacity(0.3)
                  : colorScheme.outline.withOpacity(0.2),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            _showRankDetails(context, rank, isUnlocked, isCurrent, isNext);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isUnlocked
                      ? rank.color.withOpacity(0.1)
                      : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    rank.icon,
                    size: 24,
                    color: isUnlocked ? rank.color : colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                ),
                const SizedBox(width: 12),
                // Bilgiler
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${index + 1}.',
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isUnlocked ? rank.color : colorScheme.onSurfaceVariant.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              rank.name,
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isUnlocked ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: rank.color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Mevcut',
                                style: textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            )
                          else if (isNext)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colorScheme.secondary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Sonraki',
                                style: textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isUnlocked ? Icons.check_circle : Icons.lock_outline,
                            size: 12,
                            color: isUnlocked ? rank.color : colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${rank.requiredScore} XP',
                            style: textTheme.bodySmall?.copyWith(
                              color: isUnlocked
                                  ? colorScheme.onSurface.withOpacity(0.7)
                                  : colorScheme.onSurfaceVariant.withOpacity(0.5),
                            ),
                          ),
                          if (isNext && !isUnlocked) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• ${rank.requiredScore - currentScore} XP kaldı!',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRankDetails(BuildContext context, Rank rank, bool isUnlocked, bool isCurrent, bool isNext) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 24),
              // Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: rank.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  rank.icon,
                  size: 48,
                  color: rank.color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                rank.name,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: rank.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Status Badge
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: rank.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Mevcut Seviyeniz',
                    style: textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (isNext)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Sonraki Hedefiniz',
                    style: textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (isUnlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Kilidi Açıldı',
                    style: textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Kilitli Seviye',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              // XP Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stars, color: rank.color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Gereken XP: ${rank.requiredScore}',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isUnlocked && isNext) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.trending_up, color: colorScheme.secondary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${rank.requiredScore - currentScore} XP daha',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Anlaşıldı'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

