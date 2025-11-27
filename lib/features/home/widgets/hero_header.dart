// lib/features/home/widgets/hero_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  List<Map<String, dynamic>> _getExamCountdowns(String? selectedExam, String? selectedExamSection) {
    if (selectedExam == null) return [];

    final now = DateTime.now();
    final countdowns = <Map<String, dynamic>>[];

    switch (selectedExam.toLowerCase()) {
      case 'lgs':
        final examDate = DateTime(2026, 6, 14);
        final diff = examDate.difference(now);
        if (!diff.isNegative) {
          countdowns.add({'days': diff.inDays, 'label': 'LGS'});
        }
        break;

      case 'yks':
        final tytDate = DateTime(2026, 6, 20);
        final tytDiff = tytDate.difference(now);
        if (!tytDiff.isNegative) {
          countdowns.add({'days': tytDiff.inDays, 'label': 'TYT'});
        }

        final aytDate = DateTime(2026, 6, 21);
        final aytDiff = aytDate.difference(now);
        if (!aytDiff.isNegative) {
          countdowns.add({'days': aytDiff.inDays, 'label': 'AYT'});
        }
        break;

      case 'kpss':
        DateTime? examDate;
        String? examLabel;

        if (selectedExamSection != null) {
          final section = selectedExamSection.toLowerCase();
          if (section.contains('lisans') && !section.contains('ön')) {
            examDate = DateTime(2026, 9, 6);
            examLabel = 'Lisans';
          } else if (section.contains('önlisans') || section.contains('ön lisans')) {
            examDate = DateTime(2026, 10, 4);
            examLabel = 'Önlisans';
          } else if (section.contains('ortaöğretim') || section.contains('orta')) {
            examDate = DateTime(2026, 10, 25);
            examLabel = 'Ortaöğretim';
          }
        }

        examDate ??= DateTime(2026, 9, 6);
        examLabel ??= 'Lisans';

        final diff = examDate.difference(now);
        if (!diff.isNegative) {
          countdowns.add({'days': diff.inDays, 'label': examLabel});
        }
        break;
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting & User Name with Exam Countdowns
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${_getGreeting()}, ${user.firstName}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sınav Sayaçları
                  if (examCountdowns.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: examCountdowns.map((countdown) {
                        return Padding(
                          padding: EdgeInsets.only(
                            top: examCountdowns.indexOf(countdown) > 0 ? 3 : 0,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.secondary.withValues(alpha: 0.95),
                                  theme.colorScheme.secondary.withValues(alpha: 0.75),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.secondary.withValues(alpha: 0.25),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  countdown['label'],
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 9.5,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '|',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w400,
                                    fontSize: 9,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 8.5,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${countdown['days']} gün',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 9.5,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Stats Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rank Badge with Quest Button
                  Expanded(
                    flex: 3,
                    child: _StatCard(
                      icon: Icons.military_tech_rounded,
                      label: rankInfo.current.name,
                      value: 'TP ${user.engagementScore}',
                      color: theme.colorScheme.primary,
                      progress: rankInfo.progress,
                      questButton: const _QuestButton(),
                      theme: theme,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: LogoLoader(size: 42)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// Günlük Görevler Butonu
class _QuestButton extends ConsumerStatefulWidget {
  const _QuestButton();

  @override
  ConsumerState<_QuestButton> createState() => _QuestButtonState();
}

class _QuestButtonState extends ConsumerState<_QuestButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Reverse: true yaparak git-gel efekti veriyoruz.
    // Bu, "loop" sırasındaki keskin geçişi yok eder.
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatRemaining(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}dk';
    if (h < 24) return '${h}sa';
    return '${h}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questProg = ref.watch(dailyQuestsProgressProvider);
    final hasClaimable = ref.watch(hasClaimableQuestsProvider);

    final progress = questProg.progress.clamp(0.0, 1.0);
    final completed = questProg.completed;
    final total = questProg.total;
    final remaining = questProg.remaining;

    IconData buttonIcon;
    if (hasClaimable) {
      buttonIcon = Icons.military_tech_rounded;
    } else if (progress >= 1.0) {
      buttonIcon = Icons.emoji_events_rounded;
    } else {
      buttonIcon = Icons.shield_moon_rounded;
    }

    final gradientColor = theme.colorScheme.secondary;

    return GestureDetector(
      onTap: () => context.go('/home/quests'),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Alignment.lerp ile gradyanın yönünü yumuşakça kaydırıyoruz.
          // Bu yöntem stops listesini değiştirmekten çok daha performanslıdır.
          return Container(
            constraints: const BoxConstraints(minWidth: 80),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gradientColor.withValues(alpha: 0.70),
                  gradientColor.withValues(alpha: 0.95),
                  gradientColor.withValues(alpha: 0.70),
                ],
                // stops kullanmak yerine Alignment'ı kaydırıyoruz
                begin: Alignment.lerp(
                    Alignment.topLeft,
                    Alignment.topRight,
                    _controller.value
                )!,
                end: Alignment.lerp(
                    Alignment.bottomRight,
                    Alignment.bottomLeft,
                    _controller.value
                )!,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: gradientColor.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Görevler',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 8.5,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            value: total == 0 ? 0 : progress,
                            strokeWidth: 2,
                            backgroundColor: Colors.white.withValues(alpha: 0.25),
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                        Icon(
                          buttonIcon,
                          size: 10,
                          color: Colors.white,
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      total == 0 ? '0/0' : '$completed/$total',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                if (total > 0 && progress < 1.0) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 8,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _formatRemaining(remaining),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 8,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ] else if (hasClaimable || progress >= 1.0 || total == 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    hasClaimable
                        ? 'Ödül Al!'
                        : (progress >= 1.0
                        ? 'Tamam'
                        : 'Yok'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 8,
                      height: 1,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final double progress;
  final Widget? questButton;
  final ThemeData theme;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.progress,
    required this.theme,
    this.questButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // SOL TARAF: Bilgiler
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.2,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2.5),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
          // SAĞ TARAF: Quest Butonu
          if (questButton != null) ...[
            const SizedBox(width: 8),
            questButton!,
          ],
        ],
      ),
    );
  }
}