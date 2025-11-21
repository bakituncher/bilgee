// lib/features/pomodoro/widgets/pomodoro_stats_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:taktik/features/pomodoro/logic/pomodoro_notifier.dart';
import 'package:taktik/shared/widgets/ad_banner_widget.dart';
import 'dart:ui' as ui;

class PomodoroStatsView extends ConsumerStatefulWidget {
  const PomodoroStatsView({super.key});

  @override
  ConsumerState<PomodoroStatsView> createState() => _PomodoroStatsViewState();
}

class _PomodoroStatsViewState extends ConsumerState<PomodoroStatsView> {
  List<MapEntry<DateTime, int>>? _parsedRollupCache;
  int _rollupSignature = 0;

  int _computeSignature(Map<String, int> rollup) {
    // Basit imza: eleman sayısı + anahtarların hash toplamı
    int hash = rollup.length;
    for (final k in rollup.keys) {
      hash = 0x1fffffff & (hash + k.hashCode);
    }
    return hash;
  }

  void _prepareRollupCache(Map<String, int> rollup) {
    final sig = _computeSignature(rollup);
    if (_parsedRollupCache != null && sig == _rollupSignature) return; // cache geçerli
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
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final asyncStats = ref.watch(userStatsStreamProvider);
          final userStats = asyncStats.value;
          if (userStats == null) {
            return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
          }
          // Cache parse
            _prepareRollupCache(userStats.focusRollup30);
          final now = DateTime.now();
          final weekTotal = _sumForLastDays(7, now);
          final monthTotal = _sumForLastDays(30, now);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bar_chart_rounded, color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 8),
                      const Text('Odak İstatistikleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _GlassPanel(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_moon_rounded, size: 36, color: Theme.of(context).colorScheme.primary),
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
                    data: (stats) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Theme.of(context).colorScheme.tertiary.withOpacity(0.35)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_rounded, color: Theme.of(context).colorScheme.tertiary),
                          const SizedBox(width: 8),
                          Text(
                            'Pomodoro TP: ${stats?.pomodoroBp ?? 0}',
                            style: TextStyle(color: Theme.of(context).colorScheme.tertiary, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (e, s) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 20),
                  userStatsAsync.when(
                    data: (stats) {
                      // Stats null ise varsayılan/boş değerleri kullan, gizleme yapma
                      final totalSeconds = stats?.totalFocusSeconds ?? 0;
                      final count = stats?.pomodoroSessions ?? 0;
                      final avg = count > 0 ? totalSeconds / count : 0;
                      final now = DateTime.now();
                      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, now.day));
                      final todayMinutes = stats?.focusRollup30[todayKey] ?? 0;

                      return Column(
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(child: _KpiCard(icon: Icons.timer, label: 'Toplam', value: '${(totalSeconds / 3600).toStringAsFixed(1)} saat', delay: 200.ms)),
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
                    error: (e, s) => const Text('Veri yüklenemedi'),
                  ),

                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(pomodoroProvider.notifier).prepareForWork(),
                    icon: const Icon(Icons.rocket_launch_rounded),
                    label: const Text('Odaklanmaya Başla'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
                  ).animate().fadeIn(delay: 600.ms),
                  const SizedBox(height: 16),
                  // Banner Reklam
                  Consumer(
                    builder: (context, ref, _) {
                      final isPremium = ref.watch(premiumStatusProvider);

                      return AdBannerWidget(
                        isPremium: isPremium,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.secondary.withOpacity(0.18),
              child: Icon(icon, color: colorScheme.secondary, size: 20),
            ),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
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

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, spreadRadius: 2),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
