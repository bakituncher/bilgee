// lib/features/pomodoro/widgets/pomodoro_completed_view.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import '../logic/pomodoro_notifier.dart';

class PomodoroCompletedView extends StatefulWidget {
  final FocusSessionResult result;
  const PomodoroCompletedView({super.key, required this.result});

  @override
  State<PomodoroCompletedView> createState() => _PomodoroCompletedViewState();
}

class _PomodoroCompletedViewState extends State<PomodoroCompletedView> {
  // Basit bir konfeti animasyonu için
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
    return Consumer(
      builder: (context, ref, child) {
        final notifier = ref.read(pomodoroProvider.notifier);
        final pomodoro = ref.watch(pomodoroProvider);

        final isLongBreakTime = widget.result.roundsCompleted % pomodoro.longBreakInterval == 0;
        final breakDuration = isLongBreakTime ? pomodoro.longBreakDuration : pomodoro.shortBreakDuration;

        return Stack(
          alignment: Alignment.topCenter,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  const Icon(Icons.check_circle_outline_rounded, size: 80, color: AppTheme.successColor)
                      .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 24),
                  Text(
                    "Yaratım Tamamlandı!",
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.5),
                  Text(
                    "'${widget.result.task}' görevine ${(widget.result.totalFocusSeconds/60).round()} dakika odaklandın.",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.secondaryTextColor),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.5),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text("+25 Bilgelik Puanı", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    ],
                  ).animate().fadeIn(delay: 400.ms).shake(),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: Icon(isLongBreakTime ? Icons.bedtime_rounded : Icons.coffee_rounded),
                    label: Text("${(breakDuration/60).round()} Dakika Mola Ver"),
                    onPressed: notifier.startNextSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: AppTheme.primaryColor,
                    ),
                  ),
                  TextButton(
                    onPressed: notifier.reset,
                    child: const Text("Mabedi Terk Et"),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            ),
          ],
        );
      },
    );
  }
}

// Basit Konfeti Animasyonu için gerekli paket: `confetti`
// pubspec.yaml'a ekle:
// confetti: ^0.7.0
// Sonra `import 'package:confetti/confetti.dart';` ekle.

// Şimdilik, paketi eklemeden çalışması için sahte bir class oluşturalım:
class ConfettiController extends ChangeNotifier {
  ConfettiController({Duration? duration});
  void play() {}
  @override
  void dispose() {}
}

class ConfettiWidget extends StatelessWidget {
  final ConfettiController confettiController;
  final BlastDirectionality blastDirectionality;
  final bool shouldLoop;
  final List<Color> colors;

  const ConfettiWidget({
    super.key,
    required this.confettiController,
    required this.blastDirectionality,
    required this.shouldLoop,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(); // Placeholder
  }
}

enum BlastDirectionality {
  explosive
}