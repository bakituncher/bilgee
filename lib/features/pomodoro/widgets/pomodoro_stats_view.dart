// lib/features/pomodoro/widgets/pomodoro_stats_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/pomodoro/logic/pomodoro_notifier.dart';

class PomodoroStatsView extends ConsumerStatefulWidget {
  const PomodoroStatsView({super.key});

  @override
  ConsumerState<PomodoroStatsView> createState() => _PomodoroStatsViewState();
}

class _PomodoroStatsViewState extends ConsumerState<PomodoroStatsView> {
  void _openStatsSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final userStats = ref.watch(userStatsStreamProvider).value;
          if (userStats == null) {
            return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
          }
          final now = DateTime.now();
          final dateKey = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, now.day));
          // Rollup map (son ~30 gün) üzerinden haftalık ve 30 günlük toplamları hesapla
            int sumForLast(int days) {
              final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
              int total = 0;
              userStats.focusRollup30.forEach((k, v) {
                try {
                  final d = DateTime.parse(k);
                  if (!d.isBefore(start) && !d.isAfter(now)) total += v;
                } catch (_) {}
              });
              return total;
            }
          final weekTotal = sumForLast(7);
          final monthTotal = sumForLast(30);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bar_chart_rounded, color: AppTheme.secondaryColor),
                      const SizedBox(width: 8),
                      const Text('Odak İstatistikleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                          const SizedBox(width: 6),
                          Text('Pomodoro BP: ${userStats.pomodoroBp}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700)),
                        ]),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MetricTile(title: 'Son 7 gün', value: '$weekTotal dk'),
                  _MetricTile(title: 'Son 30 gün', value: '$monthTotal dk'),
                  _MetricTile(title: 'Toplam odak', value: '${userStats.focusMinutes} dk'),
                  _MetricTile(title: 'Toplam seans', value: '${userStats.pomodoroSessions}'),
                  const SizedBox(height: 8),
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
    final userStatsAsync = ref.watch(userStatsStreamProvider);

    return Center(
      key: const ValueKey('stats'),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_moon_rounded, size: 36, color: AppTheme.successColor),
                const SizedBox(width: 10),
                Expanded(child: Text('Odak Merkezi', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)) ),
                IconButton(
                  tooltip: 'İstatistikler',
                  onPressed: _openStatsSheet,
                  icon: const Icon(Icons.bar_chart_rounded),
                ),
              ],
            ).animate().fadeIn().slideY(begin: 0.1),
            const SizedBox(height: 8),
            userStatsAsync.when(
              data: (stats) => (stats == null) ? const SizedBox.shrink() : Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withOpacity(0.35)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text('Pomodoro BP: ${stats.pomodoroBp}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (e, s) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            userStatsAsync.when(
              data: (stats) {
                if (stats == null) return const SizedBox();
                final totalSeconds = stats.totalFocusSeconds;
                final count = stats.pomodoroSessions;
                final avg = count > 0 ? totalSeconds / count : 0;
                final now = DateTime.now();
                final todayKey = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, now.day));
                final todayMinutes = stats.focusRollup30[todayKey] ?? 0;

                return Column(
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(child: _KpiCard(icon: Icons.timer, label: 'Toplam', value: (totalSeconds / 3600).toStringAsFixed(1) + ' saat', delay: 200.ms)),
                          const SizedBox(width: 12),
                          Expanded(child: _KpiCard(icon: Icons.check_circle_outline, label: 'Seans', value: '$count', delay: 300.ms)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(child: _KpiCard(icon: Icons.speed, label: 'Ortalama', value: '${(avg / 60).round()} dk', delay: 400.ms)),
                          const SizedBox(width: 12),
                          Expanded(child: _KpiCard(icon: Icons.today_rounded, label: 'Bugün', value: '$todayMinutes dk', delay: 500.ms)),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (e, s) => Text('Veri yüklenemedi'),
            ),

            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => ref.read(pomodoroProvider.notifier).prepareForWork(),
              icon: const Icon(Icons.rocket_launch_rounded),
              label: const Text('Mabedi Harekete Geçir'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.center,
              child: Text('Odaklanmaya başla.', style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Duration delay;
  const _KpiCard({required this.icon, required this.label, required this.value, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(radius: 18, backgroundColor: AppTheme.secondaryColor.withOpacity(0.18), child: Icon(icon, color: AppTheme.secondaryColor, size: 20)),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor)),
          ],
        ),
      ),
    ).animate().fadeIn(delay: delay).slideY(begin: 0.12);
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  const _MetricTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}