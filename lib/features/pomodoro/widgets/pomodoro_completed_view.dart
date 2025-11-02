// lib/features/pomodoro/widgets/pomodoro_completed_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'dart:ui' as ui;
import '../logic/pomodoro_notifier.dart';

class PomodoroCompletedView extends StatefulWidget {
  final FocusSessionResult result;
  const PomodoroCompletedView({super.key, required this.result});

  @override
  State<PomodoroCompletedView> createState() => _PomodoroCompletedViewState();
}

class _PomodoroCompletedViewState extends State<PomodoroCompletedView> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final earnedMinutes = (widget.result.totalFocusSeconds / 60).floor();
    return Consumer(
      builder: (context, ref, child) {
        final notifier = ref.read(pomodoroProvider.notifier);
        final pomodoro = ref.watch(pomodoroProvider);

        // DÜZELTME: 'longBreakInterval' sıfır olabileceğinden, crash'i önlemek için kontrol eklendi.
        final isLongBreakTime = pomodoro.longBreakInterval > 0
            ? (widget.result.roundsCompleted % pomodoro.longBreakInterval == 0)
            : false;
        final breakDuration = isLongBreakTime ? pomodoro.longBreakDuration : pomodoro.shortBreakDuration;

        return Stack(
          alignment: Alignment.topCenter,
          children: [
            // Cam panel içinde içerik
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _GlassPanel(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          const Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.green)
                              .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                          const SizedBox(height: 16),
                          Text(
                            "Yaratım Tamamlandı!",
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.5),
                          const SizedBox(height: 4),
                          Text(
                            "'${widget.result.task}' görevine $earnedMinutes dakika odaklandın.",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.5),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber),
                              const SizedBox(width: 8),
                              Text("+$earnedMinutes Taktik Puanı", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                            ],
                          ).animate().fadeIn(delay: 400.ms).shake(),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: Icon(isLongBreakTime ? Icons.bedtime_rounded : Icons.coffee_rounded),
                                  label: Text("${(breakDuration/60).round()} Dakika Mola Ver"),
                                  onPressed: notifier.startNextSession,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: notifier.reset,
                            child: const Text("Mabedi Terk Et"),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Konfeti üstte
            ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: [Colors.green, Theme.of(context).colorScheme.primary, Colors.pink, Colors.orange, Colors.purple],
            ),
          ],
        );
      },
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
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08)),
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
