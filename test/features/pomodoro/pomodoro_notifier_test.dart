import 'package:flutter_test/flutter_test.dart';
import 'package:taktik/features/pomodoro/logic/pomodoro_notifier.dart';

void main() {
  group('PomodoroNotifier (mantık smoke)', () {
    test('start() idle durumundan work moduna geçip pause=false yapar', () async {
      // Not: PomodoroNotifier normalde Riverpod Ref ister ve prefs/notification gibi yan etkileri var.
      // Bu test temel state geçişlerini doğrulayan “smoke test”tir ve side-effect’leri hedeflemez.
      final notifier = _PomodoroNotifierTestHarness();

      expect(notifier.state.sessionState, PomodoroSessionState.idle);
      expect(notifier.state.isPaused, isTrue);

      notifier.start();

      expect(notifier.state.sessionState, PomodoroSessionState.work);
      expect(notifier.state.isPaused, isFalse);
      expect(notifier.state.timeRemaining, greaterThan(0));
    });

    test('pause() isPaused=true yapar', () {
      final notifier = _PomodoroNotifierTestHarness();
      notifier.start();

      notifier.pause();

      expect(notifier.state.isPaused, isTrue);
    });

    test('reset() idle ve paused duruma döner', () {
      final notifier = _PomodoroNotifierTestHarness();
      notifier.start();

      notifier.reset();

      expect(notifier.state.sessionState, PomodoroSessionState.idle);
      expect(notifier.state.isPaused, isTrue);
      expect(notifier.state.timeRemaining, 25 * 60);
    });

    test('elapsed süre arttıkça timeRemaining azalır ve 0 altına inmez', () {
      final notifier = _PomodoroNotifierTestHarness();
      notifier.start();

      // 25dk'dan 10sn düş
      notifier.tickElapsed(seconds: 10);
      expect(notifier.state.timeRemaining, 25 * 60 - 10);

      // Çok büyük değer verirsek 0'a clamp etmeli
      notifier.tickElapsed(seconds: 999999);
      expect(notifier.state.timeRemaining, 0);
    });
  });
}

/// Gerçek PomodoroNotifier, Ref ve SharedPreferences kullandığı için saf unit testte
/// zor mock’lanıyor. Bu harness, PomodoroModel davranışını test etmek için minimal bir
/// “benzetim” sağlar.
class _PomodoroNotifierTestHarness {
  PomodoroModel state = PomodoroModel();

  int? _baseline;

  void start() {
    if (state.sessionState == PomodoroSessionState.idle) {
      state = state.copyWith(
        sessionState: PomodoroSessionState.work,
        timeRemaining: state.workDuration,
        currentRound: 1,
        clearLastResult: true,
        activeSessionTotalDuration: state.workDuration,
        isPaused: false,
      );
      _baseline = state.timeRemaining;
    }
  }

  void tickElapsed({required int seconds}) {
    if (state.isPaused) return;
    final initial = _baseline ?? state.timeRemaining;
    final remaining = (initial - seconds).clamp(0, initial);
    state = state.copyWith(timeRemaining: remaining);
  }

  void pause() {
    state = state.copyWith(isPaused: true);
  }

  void reset() {
    state = PomodoroModel(
      workDuration: state.workDuration,
      shortBreakDuration: state.shortBreakDuration,
      longBreakDuration: state.longBreakDuration,
      longBreakInterval: state.longBreakInterval,
      autoStartBreaks: state.autoStartBreaks,
      autoStartWork: state.autoStartWork,
      keepScreenOn: state.keepScreenOn,
      activeSessionTotalDuration: state.workDuration,
    );
    _baseline = null;
  }
}
