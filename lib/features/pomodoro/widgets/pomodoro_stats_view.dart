// lib/features/pomodoro/widgets/pomodoro_stats_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/features/profile/screens/profile_screen.dart'; // HATA DÜZELTİLDİ: Doğru import
import 'package:bilge_ai/features/pomodoro/logic/pomodoro_notifier.dart';

class PomodoroStatsView extends ConsumerWidget {
  const PomodoroStatsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusSessionsAsync = ref.watch(focusSessionsProvider);
    final textTheme = Theme.of(context).textTheme;

    return Center(
      key: const ValueKey('stats'),
      child: focusSessionsAsync.when(
        data: (sessions) {
          final totalDuration = sessions.fold(0, (sum, session) => sum + session.durationInSeconds);
          final completedSessions = sessions.length;
          final avgDuration = completedSessions > 0 ? (totalDuration / completedSessions) : 0;
          final completedTasks = sessions.where((s) => s.task != "Genel Çalışma").length;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_moon_rounded, size: 80, color: AppTheme.successColor).animate().fadeIn().scale(duration: 800.ms),
                const SizedBox(height: 24),
                Text(
                  "Zihinsel Gözlem Raporu",
                  style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                const SizedBox(height: 32),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(child: _StatCard(value: (totalDuration / 3600).toStringAsFixed(1), label: 'Toplam Süre (saat)', icon: Icons.timer, delay: 300.ms)),
                      const SizedBox(width: 16),
                      Expanded(child: _StatCard(value: completedSessions.toString(), label: 'Tamamlanan Seans', icon: Icons.check_circle_outline, delay: 400.ms)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(child: _StatCard(value: (avgDuration / 60).toStringAsFixed(0), label: 'Ortalama Seans (dk)', icon: Icons.speed, delay: 500.ms)),
                      const SizedBox(width: 16),
                      Expanded(child: _StatCard(value: completedTasks.toString(), label: 'Tamamlanan Görev', icon: Icons.assignment_turned_in, delay: 600.ms)),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton.icon(
                  onPressed: () => ref.read(pomodoroProvider.notifier).prepareForWork(),
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: const Text("Mabedi Harekete Geçir"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ).animate().fadeIn(delay: 800.ms),
                const SizedBox(height: 8),
                Text(
                    "Odaklanma ayinine başla.",
                    style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 12)
                ).animate().fadeIn(delay: 900.ms),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor)),
        error: (e, s) => Text('Veriler yüklenemedi: $e'),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Duration delay;

  const _StatCard({required this.value, required this.label, required this.icon, required this.delay});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(radius: 18, backgroundColor: AppTheme.secondaryColor.withOpacity(0.2), child: Icon(icon, color: AppTheme.secondaryColor, size: 20)),
            const SizedBox(height: 12),
            Text(value, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ).animate().fadeIn(delay: delay).slideY(begin: 0.2);
  }
}