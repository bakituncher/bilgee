// lib/features/home/widgets/hero_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/profile/logic/rank_service.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/features/home/providers/home_providers.dart';
import 'package:bilge_ai/data/models/test_model.dart';
import 'dart:math' as math;

class HeroHeader extends ConsumerWidget {
  const HeroHeader({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'Gece Vardiyası';
    if (hour < 11) return 'Günaydın';
    if (hour < 17) return 'Odak Zamanı';
    if (hour < 22) return 'Akşam Gücü';
    return 'Gece Derinliği';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        final info = RankService.getRankInfo(user.engagementScore);
        final current = info.current;
        final progress = info.progress; // 0..1
        final plan = ref.watch(planProgressProvider);
        final tests = ref.watch(testsProvider).valueOrNull ?? <TestModel>[];
        DateTime? lastDate;
        double? lastNet;
        double? prevNet;
        if (tests.isNotEmpty) {
          final sorted = [...tests]..sort((a,b)=> b.date.compareTo(a.date));
            lastDate = sorted.first.date;
            lastNet = sorted.first.totalNet;
            if (sorted.length > 1) prevNet = sorted[1].totalNet;
        }
        String lastInfo = 'Henüz deneme yok';
        if (lastDate != null) {
          final diff = DateTime.now().difference(lastDate);
          final days = diff.inDays;
          final hours = diff.inHours;
          String when;
          if (days > 0) {
            when = days == 1 ? '1 gün önce' : '$days gün önce';
          } else if (hours > 0) {
            when = '$hours sa önce';
          } else {
            final mins = diff.inMinutes;
            when = mins <= 1 ? 'az önce' : '$mins dk önce';
          }
          String delta = '';
          if (lastNet != null && prevNet != null) {
            final d = lastNet - prevNet;
            if (d.abs() >= 0.05) {
              delta = (d>0? '+':'') + d.toStringAsFixed(1);
            }
          }
          lastInfo = 'Son deneme: $when';
          if (delta.isNotEmpty) lastInfo += ' • Net farkı: $delta';
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [AppTheme.cardColor, AppTheme.lightSurfaceColor.withValues(alpha: .25)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AppTheme.lightSurfaceColor.withValues(alpha: .35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_greeting()}, ${user.name ?? 'Bilge'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        // Row -> Wrap (overflow fix)
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryColor.withValues(alpha: .15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.secondaryColor.withValues(alpha: .6), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.workspace_premium_rounded, size: 14, color: AppTheme.secondaryColor),
                                  const SizedBox(width: 4),
                                  Text(current.name, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondaryColor, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            if (plan.total>0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.lightSurfaceColor.withValues(alpha: .25),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.lightSurfaceColor.withValues(alpha: .4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.checklist_rounded, size: 14, color: AppTheme.secondaryTextColor),
                                    const SizedBox(width: 4),
                                    Text('%${(plan.ratio*100).toStringAsFixed(0)} Plan', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondaryTextColor)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ArchiveButton(),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppTheme.lightSurfaceColor.withValues(alpha: .25),
                  valueColor: const AlwaysStoppedAnimation(AppTheme.secondaryColor),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('BP ${user.engagementScore}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.secondaryTextColor)),
                  const SizedBox(width: 6),
                  Text('%${(progress*100).toStringAsFixed(0)} rütbe ilerleme', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondaryTextColor)),
                ],
              ),
              const SizedBox(height: 4),
              Text(lastInfo, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondaryTextColor.withValues(alpha: .85))),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 72, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _ArchiveButton extends StatefulWidget {
  @override
  State<_ArchiveButton> createState() => _ArchiveButtonState();
}

class _ArchiveButtonState extends State<_ArchiveButton> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final glow = (0.5 + 0.5 * (1 + math.sin(_c.value * 6.283))) * 0.4; // 0..0.4
        return InkWell(
          onTap: () => context.go('/library'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.secondaryColor.withValues(alpha: .7), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.secondaryColor.withValues(alpha: glow),
                  blurRadius: 12,
                  spreadRadius: 1,
                )
              ],
              color: AppTheme.secondaryColor.withValues(alpha: .1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history_edu_rounded, size: 18, color: AppTheme.secondaryColor),
                const SizedBox(width: 6),
                Text('Arşiv', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondaryColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      },
    );
  }
}
