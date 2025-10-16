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

class _PomodoroScreenState extends ConsumerState<PomodoroScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Pause the timer if the app goes into the background
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      ref.read(pomodoroProvider.notifier).pause();
    }
  }

  String _getAppBarTitle(PomodoroSessionState state) {
    return switch (state) {
      PomodoroSessionState.idle => "Zihinsel Mabet",
      PomodoroSessionState.work => "Odaklanma",
      PomodoroSessionState.shortBreak => "Kısa Mola",
      PomodoroSessionState.longBreak => "Uzun Mola",
      PomodoroSessionState.completed => "Başardın!",
    };
  }

  @override
  Widget build(BuildContext context) {
    final pomodoro = ref.watch(pomodoroProvider);

    return WillPopScope(
      onWillPop: () async {
        final pomodoroState = ref.read(pomodoroProvider);
        // Only show dialog if a session is active
        if (pomodoroState.sessionState == PomodoroSessionState.work ||
            pomodoroState.sessionState == PomodoroSessionState.shortBreak ||
            pomodoroState.sessionState == PomodoroSessionState.longBreak) {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Seansı Duraklat ve Çık?'),
              content: const Text('Ekrandan ayrılırsan mevcut seansın duraklatılacak. Devam etmek istiyor musun?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Vazgeç'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Çık ve Duraklat'),
                ),
              ],
            ),
          ) ?? false;
          if (shouldExit) {
            ref.read(pomodoroProvider.notifier).pause();
            return true;
          }
          return false;
        }
        // If no session is active, allow popping without a dialog
        return true;
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: AnimatedSwitcher(
            duration: 500.ms,
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: Text(
              _getAppBarTitle(pomodoro.sessionState),
              key: ValueKey(pomodoro.sessionState),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: AnimatedContainer(
          duration: 1.seconds,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: _getBackgroundGradient(pomodoro.sessionState),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: 800.ms,
              transitionBuilder: (child, animation) {
                return child.animate()
                    .fadeIn(duration: 600.ms, curve: Curves.easeOutCubic)
                    .slideY(begin: 0.1, end: 0, duration: 600.ms, curve: Curves.easeOutCubic);
              },
              child: _buildCurrentView(pomodoro),
            ),
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
        if (pomodoro.lastResult == null) {
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

  LinearGradient _getBackgroundGradient(PomodoroSessionState currentState) {
    final (begin, end) = switch (currentState) {
      PomodoroSessionState.work => (AppTheme.secondaryColor.withOpacity(0.5), AppTheme.primaryColor),
      PomodoroSessionState.shortBreak || PomodoroSessionState.longBreak => (AppTheme.successColor.withOpacity(0.5), AppTheme.primaryColor),
      PomodoroSessionState.completed => (Colors.purple.shade300.withOpacity(0.6), AppTheme.primaryColor),
      PomodoroSessionState.idle => (AppTheme.primaryColor, AppTheme.lightSurfaceColor.withOpacity(0.2)),
    };
    return LinearGradient(
      colors: [begin, end],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }
}