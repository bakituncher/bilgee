// lib/features/home/widgets/hero_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/profile/logic/rank_service.dart';
import 'package:taktik/features/home/providers/home_providers.dart';
import 'package:taktik/features/quests/logic/optimized_quests_provider.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';

class HeroHeader extends ConsumerWidget {
  const HeroHeader({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'İyi Geceler';
    if (hour < 11) return 'Günaydın';
    if (hour < 17) return 'Kolay Gelsin';
    if (hour < 22) return 'İyi Akşamlar';
    return 'İyi Geceler';
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 6) return Icons.nightlight_round;
    if (hour < 11) return Icons.wb_sunny_rounded;
    if (hour < 17) return Icons.wb_sunny_rounded;
    if (hour < 22) return Icons.nights_stay_rounded;
    return Icons.nightlight_round;
  }

  List<Map<String, dynamic>> _getExamCountdowns(String? selectedExam, String? selectedExamSection) {
    if (selectedExam == null) return [];

    final now = DateTime.now();
    final countdowns = <Map<String, dynamic>>[];

    Map<String, int> _daysHoursRemaining(DateTime target) {
      final diff = target.difference(now);
      if (diff.isNegative) return {'days': 0, 'hours': 0};
      final secondsInDay = const Duration(days: 1).inSeconds;
      final daysFloor = (diff.inSeconds / secondsInDay).floor();
      final remaining = diff - Duration(days: daysFloor);
      final hours = remaining.inHours; // tam saat
      return {'days': daysFloor, 'hours': hours};
    }

    // selectedExam Firestore'da ExamType.name olarak kaydediliyor (örn: "yks", "lgs", "kpssLisans")
    final exam = selectedExam.toLowerCase();

    if (exam == 'lgs') {
      // LGS: 14 Haziran 2026, 09:30
      final examDate = DateTime(2026, 6, 14, 9, 30);
      final rem = _daysHoursRemaining(examDate);
      if (rem['days']! > 0 || rem['hours']! > 0) {
        countdowns.add({'days': rem['days'], 'hours': rem['hours'], 'label': 'LGS', 'icon': Icons.school_rounded});
      }
    } else if (exam == 'yks') {
      // TYT: 20 Haziran 2026, 10:15
      final tytDate = DateTime(2026, 6, 20, 10, 15);
      final tytRem = _daysHoursRemaining(tytDate);
      if (tytRem['days']! > 0 || tytRem['hours']! > 0) {
        countdowns.add({'days': tytRem['days'], 'hours': tytRem['hours'], 'label': 'TYT', 'icon': Icons.menu_book_rounded});
      }

      // AYT: 21 Haziran 2026, 10:15
      final aytDate = DateTime(2026, 6, 21, 10, 15);
      final aytRem = _daysHoursRemaining(aytDate);
      if (aytRem['days']! > 0 || aytRem['hours']! > 0) {
        countdowns.add({'days': aytRem['days'], 'hours': aytRem['hours'], 'label': 'AYT', 'icon': Icons.auto_stories_rounded});
      }
    } else if (exam == 'kpsslisans') {
      // KPSS Lisans: 06 Eylül 2026, 10:15
      final examDate = DateTime(2026, 9, 6, 10, 15);
      final rem = _daysHoursRemaining(examDate);
      if (rem['days']! > 0 || rem['hours']! > 0) {
        countdowns.add({'days': rem['days'], 'hours': rem['hours'], 'label': 'Lisans', 'icon': Icons.workspace_premium_rounded});
      }
    } else if (exam == 'kpssonlisans') {
      // KPSS Önlisans: 04 Ekim 2026, 10:15
      final examDate = DateTime(2026, 10, 4, 10, 15);
      final rem = _daysHoursRemaining(examDate);
      if (rem['days']! > 0 || rem['hours']! > 0) {
        countdowns.add({'days': rem['days'], 'hours': rem['hours'], 'label': 'Önlisans', 'icon': Icons.workspace_premium_rounded});
      }
    } else if (exam == 'kpssortaogretim') {
      // KPSS Ortaöğretim: 25 Ekim 2026, 10:15
      final examDate = DateTime(2026, 10, 25, 10, 15);
      final rem = _daysHoursRemaining(examDate);
      if (rem['days']! > 0 || rem['hours']! > 0) {
        countdowns.add({'days': rem['days'], 'hours': rem['hours'], 'label': 'Ortaöğretim', 'icon': Icons.workspace_premium_rounded});
      }
    }

    return countdowns;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        final rankInfo = RankService.getRankInfo(user.engagementScore);
        final examCountdowns = _getExamCountdowns(user.selectedExam, user.selectedExamSection);
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : theme.colorScheme.primary.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side: Avatar on top, greeting+name below
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  theme.colorScheme.primary.withValues(alpha: 0.15),
                                  theme.colorScheme.primary.withValues(alpha: 0.08),
                                ],
                              ),
                            ),
                            padding: const EdgeInsets.all(1.5),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: theme.cardColor,
                              child: ClipOval(
                                child: (user.avatarStyle != null && user.avatarSeed != null)
                                    ? SvgPicture.network(
                                        'https://api.dicebear.com/9.x/${user.avatarStyle}/svg?seed=${user.avatarSeed}',
                                        fit: BoxFit.cover,
                                        width: 40,
                                        height: 40,
                                        placeholderBuilder: (_) => const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 1.5),
                                        ),
                                      )
                                    : Icon(
                                        Icons.person_rounded,
                                        size: 20,
                                        color: theme.colorScheme.primary,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Greeting + Name below avatar
                          Row(
                            children: [
                              Icon(
                                _getGreetingIcon(),
                                size: 13,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${_getGreeting()}, ${user.firstName}',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      letterSpacing: -0.2,
                                      height: 1.2,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Right side: Exam Countdown Badges (multiple if available)
                    if (examCountdowns.isNotEmpty)
                      Flexible(
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: examCountdowns.take(3).map((countdown) {
                              return ConstrainedBox(
                                constraints: const BoxConstraints(
                                  // minWidth kaldırıldı, içerik kadar genişleyecek
                                  maxWidth: 180,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        theme.colorScheme.secondary,
                                        theme.colorScheme.secondary.withValues(alpha: 0.85),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(9),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.colorScheme.secondary.withValues(alpha: 0.22),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        countdown['icon'],
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      // Expanded kaldırıldı; içerik kadar yer kaplasın
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              countdown['label'],
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              softWrap: false,
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11,
                                                height: 1.2,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            '|',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.7),
                                              fontSize: 10,
                                              height: 1.2,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          // Gün metni de Flexible ama sıkı; fazla boşluk bırakmaz
                                          Flexible(
                                            child: Text(
                                              // Sadece gün formatı (saat bilgisi gösterilmez)
                                              '${countdown['days']} gün',
                                              maxLines: 1,
                                              overflow: TextOverflow.visible,
                                              softWrap: false,
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 11,
                                                height: 1.2,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Divider
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // Stats Section - Ultra Compact
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Rank Card
                    Expanded(
                      child: _UltraCompactRankCard(
                        rankInfo: rankInfo,
                        score: user.engagementScore,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Quest Card
                    Expanded(
                      child: _UltraCompactQuestCard(
                        theme: theme,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 100,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: LogoLoader(size: 36)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// Ultra Compact Rank Card Widget
class _UltraCompactRankCard extends StatelessWidget {
  final dynamic rankInfo;
  final int score;
  final ThemeData theme;

  const _UltraCompactRankCard({
    required this.rankInfo,
    required this.score,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => context.push('/profile/ranks'),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: isDark ? 0.10 : 0.05),
              theme.colorScheme.primary.withValues(alpha: isDark ? 0.05 : 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon & Label
            Row(
              children: [
                Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(
                  Icons.military_tech_rounded,
                  size: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Rütbe',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Rank Name
          Text(
            rankInfo.current.name,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: -0.2,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: rankInfo.progress.clamp(0.0, 1.0),
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Score & Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TP $score',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
              Text(
                '%${(rankInfo.progress * 100).toInt()}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  fontWeight: FontWeight.w600,
                  fontSize: 9,
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

// Ultra Compact Quest Card Widget
class _UltraCompactQuestCard extends ConsumerStatefulWidget {
  final ThemeData theme;

  const _UltraCompactQuestCard({
    required this.theme,
  });

  @override
  ConsumerState<_UltraCompactQuestCard> createState() => _UltraCompactQuestCardState();
}

class _UltraCompactQuestCardState extends ConsumerState<_UltraCompactQuestCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatRemaining(Duration d) {
    final days = d.inDays;
    final m = d.inMinutes.remainder(60);

    if (days >= 1) return '${days} gün';
    if (d.inHours >= 1) return '${d.inHours} sa';
    return '${m} dk';
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final isDark = theme.brightness == Brightness.dark;
    final questProg = ref.watch(dailyQuestsProgressProvider);
    final hasClaimable = ref.watch(hasClaimableQuestsProvider);

    final progress = questProg.progress.clamp(0.0, 1.0);
    final completed = questProg.completed;
    final total = questProg.total;
    final remaining = questProg.remaining;

    IconData buttonIcon;
    if (hasClaimable) {
      buttonIcon = Icons.card_giftcard_rounded;
    } else if (progress >= 1.0) {
      buttonIcon = Icons.check_circle_rounded;
    } else {
      buttonIcon = Icons.shield_rounded;
    }

    return GestureDetector(
      onTap: () => context.go('/home/quests'),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: hasClaimable ? _pulseAnimation.value : 1.0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: hasClaimable
                      ? [
                          theme.colorScheme.secondary,
                          theme.colorScheme.secondary.withValues(alpha: 0.85),
                        ]
                      : [
                          theme.colorScheme.secondary.withValues(alpha: isDark ? 0.10 : 0.05),
                          theme.colorScheme.secondary.withValues(alpha: isDark ? 0.05 : 0.02),
                        ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasClaimable
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.secondary.withValues(alpha: 0.12),
                  width: 1,
                ),
                boxShadow: hasClaimable
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon & Label
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: hasClaimable
                              ? Colors.white.withValues(alpha: 0.2)
                              : theme.colorScheme.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Icon(
                          buttonIcon,
                          size: 12,
                          color: hasClaimable
                              ? Colors.white
                              : theme.colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Görevler',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: hasClaimable
                              ? Colors.white.withValues(alpha: 0.95)
                              : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Progress Count
                  Text(
                    total == 0 ? '0/0' : '$completed/$total',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: hasClaimable
                          ? Colors.white
                          : theme.colorScheme.secondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: -0.2,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Stack(
                      children: [
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: hasClaimable
                                ? Colors.white.withValues(alpha: 0.25)
                                : theme.colorScheme.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: total == 0 ? 0 : progress,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: hasClaimable
                                  ? Colors.white
                                  : theme.colorScheme.secondary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Status text
                  if (hasClaimable)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '🎁 Ödül Al!',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                        ),
                      ),
                    )
                  else if (total > 0 && progress < 1.0)
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 10,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatRemaining(remaining),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                            fontWeight: FontWeight.w600,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      progress >= 1.0 ? '✓ Tamam' : 'Yok',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                        fontWeight: FontWeight.w600,
                        fontSize: 9,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
