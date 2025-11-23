// lib/features/home/widgets/hero_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/profile/logic/rank_service.dart';
import 'package:taktik/features/home/providers/home_providers.dart';
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
        final planProgress = ref.watch(planProgressProvider);
        final examCountdowns = _getExamCountdowns(user.selectedExam, user.selectedExamSection);
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          // Daha kompakt padding
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16), // biraz küçültüldü
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 14, // daha düşük blur
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting & User Name
              Text(
                '${_getGreeting()}, ${user.firstName}',
                style: theme.textTheme.titleMedium?.copyWith( // daha küçük tipografi
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8), // azaltıldı

              // Stats Row
              Row(
                children: [
                  // Rank Badge with Exam Countdown
                  Expanded(
                    child: _StatCard(
                      icon: Icons.military_tech_rounded,
                      label: rankInfo.current.name,
                      value: 'TP ${user.engagementScore}',
                      color: theme.colorScheme.primary,
                      progress: rankInfo.progress,
                      examCountdowns: examCountdowns,
                    ),
                  ),

                  if (planProgress.total > 0) ...[
                    const SizedBox(width: 8), // azaltıldı
                    Expanded(
                      child: _StatCard(
                        icon: Icons.track_changes_rounded,
                        label: 'Plan',
                        value: '%${(planProgress.ratio * 100).toInt()}',
                        color: theme.colorScheme.tertiary,
                        progress: planProgress.ratio,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 120, // biraz daha az yükseklik
        child: Center(child: LogoLoader(size: 42)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final double progress;
  final List<Map<String, dynamic>>? examCountdowns;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.progress,
    this.examCountdowns,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // azaltıldı
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12), // küçültüldü
        border: Border.all(
          color: color.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 14, color: color), // daha küçük
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                    fontSize: 9, // küçültüldü
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (examCountdowns != null && examCountdowns!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    examCountdowns!
                        .map((countdown) => '${countdown['label']} | ${countdown['days']} gün')
                        .join(' • '),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6), // azaltıldı
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith( // daha küçük
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6), // azaltıldı
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3, // azaltıldı
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
