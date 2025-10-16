// lib/features/pomodoro/widgets/pomodoro_stats_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/pomodoro/logic/pomodoro_notifier.dart';

class PomodoroStatsView extends ConsumerStatefulWidget {
  const PomodoroStatsView({super.key});

  @override
  ConsumerState<PomodoroStatsView> createState() => _PomodoroStatsViewState();
}

class _PomodoroStatsViewState extends ConsumerState<PomodoroStatsView> {
  // Cache for parsed date strings to avoid re-parsing
  List<MapEntry<DateTime, int>>? _parsedRollupCache;
  int _rollupSignature = 0;

  int _computeSignature(Map<String, int> rollup) {
    int hash = rollup.length;
    for (final k in rollup.keys) {
      hash = 0x1fffffff & (hash + k.hashCode);
    }
    return hash;
  }

  void _prepareRollupCache(Map<String, int> rollup) {
    final sig = _computeSignature(rollup);
    if (_parsedRollupCache != null && sig == _rollupSignature) return; // Cache is valid
    final list = <MapEntry<DateTime, int>>[];
    rollup.forEach((k, v) {
      try {
        list.add(MapEntry(DateTime.parse(k), v));
      } catch (_) {}
    });
    _parsedRollupCache = list;
    _rollupSignature = sig;
  }

  int _sumForLastDays(int days, DateTime now) {
    if (_parsedRollupCache == null) return 0;
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: days - 1));
    int total = 0;
    for (final e in _parsedRollupCache!) {
      final d = e.key;
      if (d.isBefore(start) || d.isAfter(today)) continue;
      total += e.value;
    }
    return total;
  }

  void _openStatsSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final asyncStats = ref.watch(userStatsStreamProvider);
          final userStats = asyncStats.value;
          if (userStats == null) {
            return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
          }
          _prepareRollupCache(userStats.focusRollup30);
          final now = DateTime.now();
          final weekTotal = _sumForLastDays(7, now);
          final monthTotal = _sumForLastDays(30, now);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bar_chart_rounded, color: AppTheme.secondaryColor, size: 28),
                      const SizedBox(width: 12),
                      const Text('Odak İstatistikleri', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _MetricTile(title: 'Son 7 Gün Odak', value: '$weekTotal dk'),
                  _MetricTile(title: 'Son 30 Gün Odak', value: '$monthTotal dk'),
                  _MetricTile(title: 'Toplam Odak Süresi', value: '${userStats.focusMinutes} dk'),
                  _MetricTile(title: 'Tamamlanan Seans', value: '${userStats.pomodoroSessions}'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text('Pomodoro BP: ${userStats.pomodoroBp}', style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.w700)),
                    ]),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      key: const ValueKey('stats'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(flex: 2),
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'İstatistikler',
                onPressed: _openStatsSheet,
                icon: const Icon(Icons.bar_chart_rounded, size: 28),
              ),
            ).animate().fadeIn(delay: 200.ms),
            const Spacer(flex: 1),
            Text(
              "Zihinsel Mabet",
              textAlign: TextAlign.center,
              style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, duration: 500.ms, curve: Curves.easeOutCubic),
            const SizedBox(height: 8),
            Text(
              "Zihnini sustur, potansiyelini serbest bırak.",
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(color: AppTheme.secondaryTextColor),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, duration: 500.ms, curve: Curves.easeOutCubic),
            const Spacer(flex: 3),
            ElevatedButton(
              onPressed: () => ref.read(pomodoroProvider.notifier).prepareForWork(),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              child: const Text('Odaklanmaya Başla'),
            ).animate(
              onPlay: (controller) => controller.repeat(reverse: true),
            ).shimmer(
              delay: 3.seconds,
              duration: 1.5.seconds,
              color: AppTheme.secondaryColor.withOpacity(0.5),
            ).animate().scale(
              delay: 500.ms,
              duration: 600.ms,
              curve: Curves.elasticOut,
              begin: const Offset(0.8, 0.8)
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  const _MetricTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}