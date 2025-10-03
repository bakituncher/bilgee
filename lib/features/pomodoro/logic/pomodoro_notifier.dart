// lib/features/pomodoro/logic/pomodoro_notifier.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/models/focus_session_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:intl/intl.dart';
import 'package:taktik/shared/notifications/notification_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum PomodoroSessionState { idle, work, shortBreak, longBreak, completed }

class FocusSessionResult {
  final int totalFocusSeconds;
  final int roundsCompleted;
  final String task;
  FocusSessionResult({required this.totalFocusSeconds, required this.roundsCompleted, required this.task});
}

class PomodoroModel {
  final PomodoroSessionState sessionState;
  final int timeRemaining;
  final bool isPaused;
  final int workDuration;
  final int shortBreakDuration;
  final int longBreakDuration;
  final int longBreakInterval;
  final int currentRound;
  final String currentTask;
  final String? currentTaskIdentifier;
  final String? currentTaskDateKey; // YENI: görev ait olduğu gün (yyyy-MM-dd)
  final FocusSessionResult? lastResult;
  // Yeni tercihler
  final bool autoStartBreaks;
  final bool autoStartWork;
  final bool keepScreenOn;

  PomodoroModel({
    this.sessionState = PomodoroSessionState.idle,
    this.timeRemaining = 25 * 60,
    this.isPaused = true,
    this.workDuration = 25 * 60,
    this.shortBreakDuration = 5 * 60,
    this.longBreakDuration = 15 * 60,
    this.longBreakInterval = 4,
    this.currentRound = 1,
    this.currentTask = "Genel Çalışma",
    this.currentTaskIdentifier,
    this.currentTaskDateKey,
    this.lastResult,
    this.autoStartBreaks = false,
    this.autoStartWork = false,
    this.keepScreenOn = false,
  });

  PomodoroModel copyWith({
    PomodoroSessionState? sessionState,
    int? timeRemaining,
    bool? isPaused,
    int? workDuration,
    int? shortBreakDuration,
    int? longBreakDuration,
    int? longBreakInterval,
    int? currentRound,
    String? currentTask,
    String? currentTaskIdentifier,
    String? currentTaskDateKey,
    bool clearTaskIdentifier = false,
    bool clearTaskDateKey = false,
    FocusSessionResult? lastResult,
    bool clearLastResult = false,
    bool? autoStartBreaks,
    bool? autoStartWork,
    bool? keepScreenOn,
  }) {
    return PomodoroModel(
      sessionState: sessionState ?? this.sessionState,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      isPaused: isPaused ?? this.isPaused,
      workDuration: workDuration ?? this.workDuration,
      shortBreakDuration: shortBreakDuration ?? this.shortBreakDuration,
      longBreakDuration: longBreakDuration ?? this.longBreakDuration,
      longBreakInterval: longBreakInterval ?? this.longBreakInterval,
      currentRound: currentRound ?? this.currentRound,
      currentTask: currentTask ?? this.currentTask,
      currentTaskIdentifier: clearTaskIdentifier ? null : currentTaskIdentifier ?? this.currentTaskIdentifier,
      currentTaskDateKey: clearTaskDateKey ? null : currentTaskDateKey ?? this.currentTaskDateKey,
      lastResult: clearLastResult ? null : lastResult ?? this.lastResult,
      autoStartBreaks: autoStartBreaks ?? this.autoStartBreaks,
      autoStartWork: autoStartWork ?? this.autoStartWork,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    );
  }
}

class PomodoroNotifier extends StateNotifier<PomodoroModel> {
  final Ref _ref;
  Timer? _timer;

  PomodoroNotifier(this._ref) : super(PomodoroModel());

  void _applyWakelock() async {
    if (state.keepScreenOn && !state.isPaused &&
        (state.sessionState == PomodoroSessionState.work ||
         state.sessionState == PomodoroSessionState.shortBreak ||
         state.sessionState == PomodoroSessionState.longBreak)) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    state = state.copyWith(isPaused: false);
    _applyWakelock();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.timeRemaining > 0) {
        state = state.copyWith(timeRemaining: state.timeRemaining - 1);
      } else {
        _timer?.cancel();
        _handleSessionEnd();
      }
    });
  }

  void _notify(String title, String body) {
    NotificationService.instance.showLocalSimple(title: title, body: body);
  }

  void _handleSessionEnd() {
    if (state.sessionState == PomodoroSessionState.work) {
      // 1. Odaklanma seansını veritabanına kaydet.
      _saveSession(state.currentTask, state.workDuration);

      // 2. Sonucu oluştur ve ekran durumunu "tamamlandı" olarak değiştir.
      final result = FocusSessionResult(
        totalFocusSeconds: state.workDuration,
        roundsCompleted: state.currentRound,
        task: state.currentTask,
      );
      state = state.copyWith(sessionState: PomodoroSessionState.completed, isPaused: true, lastResult: result);
      _applyWakelock();

      _notify('Odak tamamlandı', '"${state.currentTask}" için mola zamanı.');

      if (state.autoStartBreaks) {
        // Otomatik mola başlat
        startNextSession();
        if (state.sessionState == PomodoroSessionState.shortBreak || state.sessionState == PomodoroSessionState.longBreak) {
          _startTimer();
        }
      }
    } else {
      // Mola bittiyse, bir sonraki çalışma turuna hazırlan.
      final nextRound = (state.sessionState == PomodoroSessionState.longBreak) ? 1 : state.currentRound + 1;
      state = state.copyWith(
        sessionState: PomodoroSessionState.work,
        timeRemaining: state.workDuration,
        isPaused: true,
        currentRound: nextRound,
      );
      _applyWakelock();
      _notify('Mola bitti', 'Yeni bir odak turu seni bekliyor.');
      if (state.autoStartWork) {
        _startTimer();
      }
    }
  }

  void prepareForWork() {
    if (state.sessionState == PomodoroSessionState.idle) {
      state = state.copyWith(
        sessionState: PomodoroSessionState.work,
        timeRemaining: state.workDuration,
        isPaused: true,
        currentRound: 1,
      );
      if (state.autoStartWork) {
        _startTimer();
      }
    }
  }

  void startNextSession() {
    if (state.lastResult == null) return;
    final previousRound = state.lastResult!.roundsCompleted;
    final isLongBreakTime = state.longBreakInterval > 0 && previousRound % state.longBreakInterval == 0;

    if (isLongBreakTime) {
      state = state.copyWith(
        sessionState: PomodoroSessionState.longBreak,
        timeRemaining: state.longBreakDuration,
        isPaused: true,
        clearLastResult: true,
        currentRound: previousRound,
      );
      _notify('Uzun mola başladı', '${(state.longBreakDuration / 60).round()} dk dinlen.');
    } else {
      state = state.copyWith(
        sessionState: PomodoroSessionState.shortBreak,
        timeRemaining: state.shortBreakDuration,
        isPaused: true,
        clearLastResult: true,
        currentRound: previousRound,
      );
      _notify('Mola başladı', '${(state.shortBreakDuration / 60).round()} dk nefes al.');
    }

    _applyWakelock();
    if (state.autoStartBreaks) {
      _startTimer();
    }
  }

  void start() {
    if (state.sessionState == PomodoroSessionState.idle) {
      state = state.copyWith(
          sessionState: PomodoroSessionState.work,
          timeRemaining: state.workDuration,
          currentRound: 1,
          clearLastResult: true);
    }
    _startTimer();
  }

  void pause() {
    _timer?.cancel();
    state = state.copyWith(isPaused: true);
    _applyWakelock();
  }

  void reset() {
    _timer?.cancel();
    state = PomodoroModel(
      workDuration: state.workDuration,
      shortBreakDuration: state.shortBreakDuration,
      longBreakDuration: state.longBreakDuration,
      longBreakInterval: state.longBreakInterval,
      autoStartBreaks: state.autoStartBreaks,
      autoStartWork: state.autoStartWork,
      keepScreenOn: state.keepScreenOn,
    );
    _applyWakelock();
  }

  void skipBreakAndStartWork() {
    if (state.sessionState == PomodoroSessionState.shortBreak || state.sessionState == PomodoroSessionState.longBreak) {
      state = state.copyWith(
        sessionState: PomodoroSessionState.work,
        timeRemaining: state.workDuration,
        isPaused: true,
      );
      _applyWakelock();
      if (state.autoStartWork) {
        _startTimer();
      }
    }
  }

  void setTask({required String task, String? identifier, String? dateKey}) {
    state = state.copyWith(
      currentTask: task,
      currentTaskIdentifier: identifier,
      currentTaskDateKey: dateKey,
      clearTaskIdentifier: identifier == null,
      clearTaskDateKey: dateKey == null,
    );
  }

  void markTaskAsCompleted() async {
    if (state.currentTaskIdentifier == null) return;
    final userId = _ref.read(authControllerProvider).value?.uid;
    if (userId == null) return;
    // Görev hangi güne aitse onu kullan; yoksa bugünü al.
    final date = DateTime.tryParse(state.currentTaskDateKey ?? '') ?? DateTime.now();
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    await _ref.read(firestoreServiceProvider).updateDailyTaskCompletion(
      userId: userId,
      dateKey: dateKey,
      task: state.currentTaskIdentifier!,
      isCompleted: true,
    );
    // Haftalık ve günlük sağlayıcıları yenile
    final day0 = DateTime(date.year, date.month, date.day);
    final startOfWeek = day0.subtract(Duration(days: day0.weekday - 1));
    try {
      await _ref.refresh(completedTasksForWeekProvider(startOfWeek).future);
    } catch (_) {}
    _ref.invalidate(completedTasksForDateProvider(day0));
  }

  void updateSettings({int? work, int? short, int? long, int? interval}) {
    final newWorkDuration = (work ?? (state.workDuration ~/ 60)) * 60;
    state = state.copyWith(
      workDuration: newWorkDuration,
      shortBreakDuration: (short ?? (state.shortBreakDuration ~/ 60)) * 60,
      longBreakDuration: (long ?? (state.longBreakDuration ~/ 60)) * 60,
      longBreakInterval: interval ?? state.longBreakInterval,
    );

    if (state.sessionState == PomodoroSessionState.idle ||
        (state.isPaused && state.sessionState == PomodoroSessionState.work)) {
      state = state.copyWith(timeRemaining: newWorkDuration);
    }
  }

  void updatePreferences({bool? autoStartBreaks, bool? autoStartWork, bool? keepScreenOn}) {
    state = state.copyWith(
      autoStartBreaks: autoStartBreaks ?? state.autoStartBreaks,
      autoStartWork: autoStartWork ?? state.autoStartWork,
      keepScreenOn: keepScreenOn ?? state.keepScreenOn,
    );
    _applyWakelock();
  }

  void _saveSession(String task, int duration) {
    final userId = _ref.read(authControllerProvider).value?.uid;
    if (userId == null) return;
    final session = FocusSessionModel(
      userId: userId,
      date: DateTime.now(),
      durationInSeconds: duration,
      task: task,
    );
    _ref.read(firestoreServiceProvider).recordFocusSessionAndStats(session);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }
}

final pomodoroProvider = StateNotifierProvider.autoDispose<PomodoroNotifier, PomodoroModel>((ref) {
  return PomodoroNotifier(ref);
});