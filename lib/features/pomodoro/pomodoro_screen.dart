// lib/features/pomodoro/pomodoro_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'logic/pomodoro_notifier.dart';
import 'widgets/pomodoro_stats_view.dart';
import 'widgets/pomodoro_timer_view.dart';
import 'widgets/pomodoro_completed_view.dart';

class PomodoroScreen extends ConsumerStatefulWidget {
  const PomodoroScreen({super.key});

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}


class _PomodoroScreenState extends ConsumerState<PomodoroScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: 20.seconds)..repeat();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bgController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      // Arka plana geçince sayaç otomatik duraklatılsın
      ref.read(pomodoroProvider.notifier).pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pomodoro = ref.watch(pomodoroProvider);

    return WillPopScope(
      onWillPop: () async {
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Çıkmak istiyor musun?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pomodoro ekranından ayrılırsan sayaç duraklatılacak.'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Vazgeç'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Çık ve Duraklat'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ) ?? false;
        if (shouldExit) {
          ref.read(pomodoroProvider.notifier).pause();
          return true;
        }
        return false;
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Zihinsel Gözlemevi'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: AnimatedContainer(
          duration: 1.seconds,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            gradient: RadialGradient(
              center: const Alignment(0, -1.2),
              radius: 1.5,
              colors: [
                _getBackgroundColor(pomodoro.sessionState).withOpacity(0.4),
                AppTheme.primaryColor,
              ],
              stops: const [0.0, 0.7],
            ),
          ),
          child: Stack(
            children: [
              _StarsBackground(controller: _bgController, state: pomodoro.sessionState),
              Center(
                child: AnimatedSwitcher(
                  duration: 800.ms,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, alignment: Alignment.center, child: child),
                  ),
                  child: _buildCurrentView(pomodoro),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView(PomodoroModel pomodoro) {
    switch (pomodoro.sessionState) {
      case PomodoroSessionState.idle:
        return const PomodoroStatsView(key: ValueKey('stats'));
      case PomodoroSessionState.completed:
        // DÜZELTME: lastResult'ın null olabileceği geçiş anı için kontrol eklendi.
        // Bu durum, tamamlanma ekranından mola veya başa dönme sırasında yaşanır.
        if (pomodoro.lastResult == null) {
          // Geçiş sırasında bir "boş" view göstermek çökmemeyi sağlar.
          return const SizedBox.shrink(key: ValueKey('empty_completed'));
        }
        return PomodoroCompletedView(
          key: const ValueKey('completed'),
          result: pomodoro.lastResult!,
        );
      default:
        return const PomodoroTimerView(key: ValueKey('timer'));
    }
  }

  Color _getBackgroundColor(PomodoroSessionState currentState) {
    switch (currentState) {
      case PomodoroSessionState.work: return AppTheme.secondaryColor;
      case PomodoroSessionState.shortBreak:
      case PomodoroSessionState.longBreak: return AppTheme.successColor;
      case PomodoroSessionState.completed: return Colors.purple.shade300;
      case PomodoroSessionState.idle: return AppTheme.lightSurfaceColor;
    }
  }
}

class _StarsBackground extends ConsumerWidget {
  final AnimationController controller;
  final PomodoroSessionState state;
  const _StarsBackground({required this.controller, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Animate(
      controller: controller,
      effects: [
        CustomEffect(
          duration: controller.duration,
          builder: (context, value, child) {
            final speedMultiplier = (state == PomodoroSessionState.work && !ref.watch(pomodoroProvider).isPaused) ? 2.5 : 1.0;
            return _starfieldBuilder(context, value * speedMultiplier, child);
          },
        ),
      ],
      child: Container(),
    );
  }

  static Widget _starfieldBuilder(BuildContext context, double value, Widget child) {
    final stars = List.generate(100, (index) {
      final size = 1.0 + ((index * 3) % 3);
      final x = ((index * 31.41592) % 100) / 100;
      final y = ((index * 52.5321) % 100) / 100;
      final speed = 0.1 + ((index * 7) % 4) * 0.05;
      return Positioned(
        left: x * MediaQuery.of(context).size.width,
        top: ((y + (value * speed)) % 1.0) * MediaQuery.of(context).size.height,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3 + ((index * 5) % 7) / 10),
            shape: BoxShape.circle,
          ),
        ),
      );
    });
    return Stack(children: stars);
  }
}