// lib/features/pomodoro/pomodoro_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    // Pil tasarrufu için: repeat() yerine sadece bir kez çalıştır
    _bgController = AnimationController(vsync: this, duration: 20.seconds)..forward();
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
        final model = ref.read(pomodoroProvider);
        // Yalnızca aktif ve çalışan bir seans varken uyar
        final isActiveRunning =
            (model.sessionState == PomodoroSessionState.work ||
             model.sessionState == PomodoroSessionState.shortBreak ||
             model.sessionState == PomodoroSessionState.longBreak) &&
            !model.isPaused;

        if (!isActiveRunning) {
          // Ana ekran (idle), tamamlandı veya duraklatılmışken doğrudan çık
          return true;
        }

        final shouldResetAndExit = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('İlerleme kaybolacak'),
                content: const Text('Ekrandan ayrılırsan mevcut seans sıfırlanacak. Devam etmek istiyor musun?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Vazgeç'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Çık ve Sıfırla'),
                  ),
                ],
              ),
            ) ??
            false;

        if (shouldResetAndExit) {
          ref.read(pomodoroProvider.notifier).reset();
          return true;
        }
        return false;
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Pomodoro'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          // Fix back button visibility - use white color for better contrast on blue gradient
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        body: AnimatedContainer(
          duration: 1.seconds,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getBackgroundColor(pomodoro.sessionState).withOpacity(0.9),
                Theme.of(context).colorScheme.surface,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Yıldız alanı (mevcut animasyon korunur)
              _StarsBackground(controller: _bgController, state: pomodoro.sessionState),
              // Yumuşak hareket eden renkli blob katmanları (dinamik, enerjik arka plan)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: AnimatedBuilder(
                    animation: _bgController,
                    builder: (context, _) {
                      final t = _bgController.value;
                      return Stack(children: [
                        Align(
                          alignment: Alignment(-0.9 + 0.2 * (t - 0.5), -1.1),
                          child: _Blob(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05), size: 280),
                        ),
                        Align(
                          alignment: Alignment(1.1, -0.3 + 0.2 * (0.5 - t)),
                          child: _Blob(color: Theme.of(context).colorScheme.primary.withOpacity(0.12), size: 220),
                        ),
                        Align(
                          alignment: Alignment(0.8 * (0.5 - t), 1.1),
                          child: _Blob(color: Colors.green.withOpacity(0.08), size: 260),
                        ),
                      ]);
                    },
                  ),
                ),
              ),
              // İçerik
              SafeArea(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: 800.ms,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, alignment: Alignment.center, child: child),
                    ),
                    child: _buildCurrentView(pomodoro),
                  ),
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
      case PomodoroSessionState.work: return Theme.of(context).colorScheme.primary;
      case PomodoroSessionState.shortBreak:
      case PomodoroSessionState.longBreak: return Colors.green;
      case PomodoroSessionState.completed: return Colors.purple.shade300;
      case PomodoroSessionState.idle: return Theme.of(context).colorScheme.surfaceContainerHighest;
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

// Enerjik arka plan için yumuşak, bulanık renkli blob
class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color, blurRadius: 60, spreadRadius: 10),
        ],
      ),
    );
  }
}
