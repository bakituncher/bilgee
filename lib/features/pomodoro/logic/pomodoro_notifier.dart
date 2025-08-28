// lib/features/pomodoro/logic/pomodoro_notifier.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/models/focus_session_model.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';
import 'package:intl/intl.dart';
import 'package:bilge_ai/features/quests/logic/quest_notifier.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';

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
  final FocusSessionResult? lastResult;

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
    this.lastResult,
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
    bool clearTaskIdentifier = false,
    FocusSessionResult? lastResult,
    bool clearLastResult = false,
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
      lastResult: clearLastResult ? null : lastResult ?? this.lastResult,
    );
  }
}

class PomodoroNotifier extends StateNotifier<PomodoroModel> {
  final Ref _ref;
  Timer? _timer;

  PomodoroNotifier(this._ref) : super(PomodoroModel());

  void _startTimer() {
    _timer?.cancel();
    state = state.copyWith(isPaused: false);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.timeRemaining > 0) {
        state = state.copyWith(timeRemaining: state.timeRemaining - 1);
      } else {
        _timer?.cancel();
        _handleSessionEnd();
      }
    });
  }

  void _handleSessionEnd() {
    if (state.sessionState == PomodoroSessionState.work) {
      // 1. Odaklanma seansını veritabanına kaydet.
      _saveSession(state.currentTask, state.workDuration);

      // 2. Sonucu oluştur ve ekran durumunu "tamamlandı" olarak değiştir.
      // Not: QuestNotifier bu state değişikliğini dinleyerek görevi OTOMATİK tamamlayacak.
      final result = FocusSessionResult(
        totalFocusSeconds: state.workDuration,
        roundsCompleted: state.currentRound,
        task: state.currentTask,
      );
      state = state.copyWith(sessionState: PomodoroSessionState.completed, isPaused: true, lastResult: result);
    } else {
      // Mola bittiyse, bir sonraki çalışma turuna hazırlan.
      state = state.copyWith(
        sessionState: PomodoroSessionState.work,
        timeRemaining: state.workDuration,
        isPaused: true,
        // Eğer uzun bir aradan geliyorsak tur sayısını sıfırla, değilse bir artır.
        currentRound: (state.sessionState == PomodoroSessionState.longBreak) ? 1 : state.currentRound + 1,
      );
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
    }
  }

  void startNextSession() {
    if (state.lastResult == null) return;
    final previousRound = state.lastResult!.roundsCompleted;
    final isLongBreakTime = previousRound % state.longBreakInterval == 0;

    if (isLongBreakTime) {
      state = state.copyWith(
        sessionState: PomodoroSessionState.longBreak,
        timeRemaining: state.longBreakDuration,
        isPaused: true,
        clearLastResult: true,
        currentRound: previousRound,
      );
    } else {
      state = state.copyWith(
        sessionState: PomodoroSessionState.shortBreak,
        timeRemaining: state.shortBreakDuration,
        isPaused: true,
        clearLastResult: true,
        currentRound: previousRound,
      );
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
  }

  void reset() {
    _timer?.cancel();
    state = PomodoroModel(
      workDuration: state.workDuration,
      shortBreakDuration: state.shortBreakDuration,
      longBreakDuration: state.longBreakDuration,
      longBreakInterval: state.longBreakInterval,
    );
  }

  void setTask({required String task, String? identifier}) {
    state = state.copyWith(
      currentTask: task,
      currentTaskIdentifier: identifier,
      clearTaskIdentifier: identifier == null,
    );
  }

  void markTaskAsCompleted() {
    if (state.currentTaskIdentifier == null) return;
    final userId = _ref.read(authControllerProvider).value?.uid;
    if (userId == null) return;
    final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _ref.read(firestoreServiceProvider).updateDailyTaskCompletion(
      userId: userId,
      dateKey: dateKey,
      task: state.currentTaskIdentifier!,
      isCompleted: true,
    );
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

  void _saveSession(String task, int duration) {
    final userId = _ref.read(authControllerProvider).value?.uid;
    if (userId == null) return;
    final session = FocusSessionModel(
      userId: userId,
      date: DateTime.now(),
      durationInSeconds: duration,
      task: task,
    );
    _ref.read(firestoreServiceProvider).addFocusSession(session);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final pomodoroProvider = StateNotifierProvider.autoDispose<PomodoroNotifier, PomodoroModel>((ref) {
  return PomodoroNotifier(ref);
});