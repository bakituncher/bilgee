// lib/features/pomodoro/widgets/pomodoro_completed_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'dart:ui' as ui;
import 'package:taktik/data/providers/premium_provider.dart';
import '../logic/pomodoro_notifier.dart';

class PomodoroCompletedView extends ConsumerStatefulWidget {
  final FocusSessionResult result;
  const PomodoroCompletedView({super.key, required this.result});

  @override
  ConsumerState<PomodoroCompletedView> createState() => _PomodoroCompletedViewState();
}

class _PomodoroCompletedViewState extends ConsumerState<PomodoroCompletedView> {
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
    final notifier = ref.read(pomodoroProvider.notifier);
    final pomodoro = ref.watch(pomodoroProvider);

    // DÜZELTME: 'longBreakInterval' sıfır olabileceğinden, crash'i önlemek için kontrol eklendi.
    final isLongBreakTime = pomodoro.longBreakInterval > 0
        ? (widget.result.roundsCompleted % pomodoro.longBreakInterval == 0)
        : false;
    final breakDuration = isLongBreakTime ? pomodoro.longBreakDuration : pomodoro.shortBreakDuration;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
          alignment: Alignment.topCenter,
          children: [
            // Modern gradient container
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                Colors.white.withOpacity(0.1),
                                Colors.white.withOpacity(0.05),
                              ]
                            : [
                                Colors.white.withOpacity(0.95),
                                Colors.white.withOpacity(0.85),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withOpacity(isDark ? 0.2 : 0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withOpacity(0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.white),
                          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                          const SizedBox(height: 20),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
                            ).createShader(bounds),
                            child: Text(
                              "Seans Tamamlandı!",
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.5),
                          const SizedBox(height: 8),
                          Text(
                            "'${widget.result.task}' görevine $earnedMinutes dakika odaklandın.",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: isDark
                                  ? Colors.white.withOpacity(0.85)
                                  : Colors.black.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.5),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.star_rounded, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "+$earnedMinutes Taktik Puanı",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 400.ms).shake(),
                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              icon: Icon(isLongBreakTime ? Icons.bedtime_rounded : Icons.coffee_rounded, color: Colors.white),
                              label: Text(
                                "${(breakDuration/60).round()} Dakika Mola Ver",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                              ),
                              onPressed: notifier.startNextSession,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.15),
                                  Colors.white.withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(isDark ? 0.2 : 0.3),
                              ),
                            ),
                            child: TextButton(
                              onPressed: notifier.reset,
                              child: Text(
                                "Ana Sayfaya Dön",
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF2E3192),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
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
  }
}

