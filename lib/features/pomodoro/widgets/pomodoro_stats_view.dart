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

          return asyncStats.when(
            loading: () => const SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2),
                    SizedBox(height: 12),
                    Text('İstatistikler yükleniyor...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            error: (error, stack) => SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 12),
                    const Text('İstatistikler yüklenemedi', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
            data: (userStats) {
              // Veri yoksa veya sıfırsa
              if (userStats == null || (userStats.pomodoroSessions == 0 && userStats.focusMinutes == 0)) {
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bar_chart_rounded, color: Theme.of(context).colorScheme.secondary),
                            const SizedBox(width: 8),
                            const Text('Odak İstatistikleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF2E3192).withOpacity(0.1),
                                const Color(0xFF1BFFFF).withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF2E3192).withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 48,
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Henüz Pomodoro Seansı Yok',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'İlk odaklanma seansını başlatarak\nistatistiklerini biriktirmeye başla!',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Veri varsa normal göster
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2E3192).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.shield_moon_rounded, size: 28, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                          ).createShader(bounds),
                          child: Text(
                            'Odak Merkezi',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'İstatistikler',
                        onPressed: _openStatsSheet,
                        icon: const Icon(Icons.bar_chart_rounded),
                      ),
                    ],
                  ).animate().fadeIn().slideY(begin: 0.1),
                  const SizedBox(height: 8),
                  userStatsAsync.when(
                    data: (stats) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    const Color(0xFFFFD700).withOpacity(0.15),
                                    const Color(0xFFFFA500).withOpacity(0.1),
                                  ]
                                : [
                                    const Color(0xFFFFD700).withOpacity(0.2),
                                    const Color(0xFFFFA500).withOpacity(0.15),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFFD700).withOpacity(isDark ? 0.3 : 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.star_rounded, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Pomodoro TP: ${stats?.pomodoroBp ?? 0}',
                              style: TextStyle(
                                color: isDark ? const Color(0xFFFFD700) : const Color(0xFFD97706),
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E3192).withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => ref.read(pomodoroProvider.notifier).prepareForWork(),
                      icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white),
                      label: const Text('Odaklanmaya Başla', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms),
            ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.04),
                ]
              : [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(isDark ? 0.15 : 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E3192).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 24,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? Colors.white.withOpacity(0.7)
                  : Colors.black.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

