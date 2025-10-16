// lib/features/pomodoro/widgets/pomodoro_completed_view.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/core/theme/app_theme.dart';
import '../logic/pomodoro_notifier.dart';

class PomodoroCompletedView extends ConsumerWidget {
  final FocusSessionResult result;
  const PomodoroCompletedView({super.key, required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(pomodoroProvider.notifier);
    final pomodoro = ref.watch(pomodoroProvider);
    final textTheme = Theme.of(context).textTheme;

    final isLongBreakTime = pomodoro.longBreakInterval > 0
        ? (result.roundsCompleted % pomodoro.longBreakInterval == 0)
        : false;
    final breakDuration = isLongBreakTime ? pomodoro.longBreakDuration : pomodoro.shortBreakDuration;
    final earnedMinutes = (result.totalFocusSeconds / 60).floor();

    return Stack(
      children: [
        const _FloatingBubbles(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Icon(Icons.verified_rounded, size: 100, color: AppTheme.successColor)
                  .animate().scale(duration: 800.ms, curve: Curves.elasticOut, begin: const Offset(0.5, 0.5)),
              const SizedBox(height: 24),
              Text(
                "Seans Tamamlandı!",
                style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.5),
              const SizedBox(height: 8),
              Text(
                "$earnedMinutes dakika boyunca başarıyla odaklandın.",
                style: textTheme.titleMedium?.copyWith(color: AppTheme.secondaryTextColor),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.5),
              const SizedBox(height: 24),
              Chip(
                avatar: const Icon(Icons.star_rounded, color: Colors.amber),
                label: Text("+$earnedMinutes Taktik Puanı Kazandın!", style: const TextStyle(fontWeight: FontWeight.bold)),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ).animate().fadeIn(delay: 400.ms).shake(delay: 500.ms, hz: 4, duration: 300.ms),
              const Spacer(flex: 3),
              ElevatedButton.icon(
                icon: Icon(isLongBreakTime ? Icons.bedtime_outlined : Icons.local_cafe_outlined),
                label: Text("${(breakDuration/60).round()} Dakika Mola Başlat"),
                onPressed: notifier.startNextSession,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.successColor,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ).animate().slideY(begin: 2, delay: 500.ms, duration: 600.ms, curve: Curves.easeOutCubic),
              const SizedBox(height: 12),
              TextButton(
                onPressed: notifier.reset,
                child: const Text("Bitir ve Çık"),
              ).animate().fadeIn(delay: 600.ms),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ],
    );
  }
}

class _FloatingBubbles extends StatefulWidget {
  const _FloatingBubbles();

  @override
  State<_FloatingBubbles> createState() => _FloatingBubblesState();
}

class _FloatingBubblesState extends State<_FloatingBubbles> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: 10.seconds)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubblesPainter(_controller),
      child: const SizedBox.expand(),
    );
  }
}

class _BubblesPainter extends CustomPainter {
  final Animation<double> animation;
  final List<_Bubble> bubbles;

  _BubblesPainter(this.animation)
      : bubbles = List.generate(20, (index) => _Bubble(index)),
        super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    for (final bubble in bubbles) {
      final progress = (animation.value + bubble.startTime) % 1.0;
      final yPos = size.height - (size.height * progress);
      final xPos = bubble.x * size.width;
      final sizeFactor = 1 - progress;
      final radius = bubble.radius * sizeFactor;

      if (radius < 0.1) continue;

      final paint = Paint()
        ..color = bubble.color.withOpacity(0.4 * sizeFactor)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(xPos, yPos), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) => false;
}

class _Bubble {
  final double x;
  final double radius;
  final Color color;
  final double startTime;

  _Bubble(int seed)
      : x = Random(seed * 5).nextDouble(),
        radius = 15.0 + Random(seed * 10).nextDouble() * 30.0,
        color = [AppTheme.successColor, AppTheme.secondaryColor, Colors.purple.shade300][Random(seed).nextInt(3)],
        startTime = Random(seed * 2).nextDouble();
}