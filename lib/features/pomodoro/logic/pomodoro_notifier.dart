// lib/features/pomodoro/logic/pomodoro_notifier.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/models/focus_session_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:intl/intl.dart';
import 'package:taktik/shared/notifications/notification_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:taktik/data/providers/shared_prefs_provider.dart';
import 'package:flutter/services.dart'; // HapticFeedback için

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
  // YENI: Aktif oturumun toplam süresi (ayar değişimlerinden etkilenmez)
  final int activeSessionTotalDuration;
  // YENI: lastResult için ödül yazıldı mı?
  final bool lastResultRewarded;

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
    this.activeSessionTotalDuration = 25 * 60,
    this.lastResultRewarded = false,
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
    int? activeSessionTotalDuration,
    bool? lastResultRewarded,
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
      activeSessionTotalDuration: activeSessionTotalDuration ?? this.activeSessionTotalDuration,
      lastResultRewarded: lastResultRewarded ?? this.lastResultRewarded,
    );
  }
}

class PomodoroNotifier extends StateNotifier<PomodoroModel> {
  final Ref _ref;
  Timer? _timer;

  // YENİ: Kalıcı kayıt anahtarları
  static const _kPrefix = 'pomodoro.';
  static const _kSessionState = '${_kPrefix}sessionState';
  static const _kTimeRemaining = '${_kPrefix}timeRemaining';
  static const _kIsPaused = '${_kPrefix}isPaused';
  static const _kWork = '${_kPrefix}work';
  static const _kShort = '${_kPrefix}short';
  static const _kLong = '${_kPrefix}long';
  static const _kInterval = '${_kPrefix}interval';
  static const _kRound = '${_kPrefix}round';
  static const _kTask = '${_kPrefix}task';
  static const _kTaskId = '${_kPrefix}taskId';
  static const _kTaskDate = '${_kPrefix}taskDate';
  static const _kActiveTotal = '${_kPrefix}activeTotal';
  static const _kAutoBreaks = '${_kPrefix}autoBreaks';
  static const _kAutoWork = '${_kPrefix}autoWork';
  static const _kKeepScreenOn = '${_kPrefix}keepOn';
  static const _kLastResultTotal = '${_kPrefix}last.total';
  static const _kLastResultRounds = '${_kPrefix}last.rounds';
  static const _kLastResultTask = '${_kPrefix}last.task';
  static const _kLastResultRewarded = '${_kPrefix}last.rewarded';
  static const _kRunStartEpoch = '${_kPrefix}run.startEpoch';
  static const _kBaselineRemaining = '${_kPrefix}run.baselineRemaining';

  PomodoroNotifier(this._ref) : super(PomodoroModel()) {
    // YENİ: Uygulama açılışında/hot-reload sonrası durumu geri yükle
    Future.microtask(_hydrateFromPrefs);
  }

  Future<void> _applyWakelock() async {
    if (state.keepScreenOn && !state.isPaused &&
        (state.sessionState == PomodoroSessionState.work ||
         state.sessionState == PomodoroSessionState.shortBreak ||
         state.sessionState == PomodoroSessionState.longBreak)) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }

  Future<void> _persistState() async {
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      await prefs.setInt(_kSessionState, state.sessionState.index);
      await prefs.setInt(_kTimeRemaining, state.timeRemaining);
      await prefs.setBool(_kIsPaused, state.isPaused);
      await prefs.setInt(_kWork, state.workDuration);
      await prefs.setInt(_kShort, state.shortBreakDuration);
      await prefs.setInt(_kLong, state.longBreakDuration);
      await prefs.setInt(_kInterval, state.longBreakInterval);
      await prefs.setInt(_kRound, state.currentRound);
      await prefs.setString(_kTask, state.currentTask);
      if (state.currentTaskIdentifier != null) {
        await prefs.setString(_kTaskId, state.currentTaskIdentifier!);
      } else {
        await prefs.remove(_kTaskId);
      }
      if (state.currentTaskDateKey != null) {
        await prefs.setString(_kTaskDate, state.currentTaskDateKey!);
      } else {
        await prefs.remove(_kTaskDate);
      }
      await prefs.setInt(_kActiveTotal, state.activeSessionTotalDuration);
      await prefs.setBool(_kAutoBreaks, state.autoStartBreaks);
      await prefs.setBool(_kAutoWork, state.autoStartWork);
      await prefs.setBool(_kKeepScreenOn, state.keepScreenOn);
      if (state.lastResult != null) {
        await prefs.setInt(_kLastResultTotal, state.lastResult!.totalFocusSeconds);
        await prefs.setInt(_kLastResultRounds, state.lastResult!.roundsCompleted);
        await prefs.setString(_kLastResultTask, state.lastResult!.task);
        await prefs.setBool(_kLastResultRewarded, state.lastResultRewarded);
      } else {
        await prefs.remove(_kLastResultTotal);
        await prefs.remove(_kLastResultRounds);
        await prefs.remove(_kLastResultTask);
        await prefs.remove(_kLastResultRewarded);
      }
    } catch (_) {}
  }

  Future<void> _persistRunStart({required int baselineRemaining}) async {
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      await prefs.setInt(_kRunStartEpoch, DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await prefs.setInt(_kBaselineRemaining, baselineRemaining);
    } catch (_) {}
  }

  Future<void> _clearRunStart() async {
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      await prefs.remove(_kRunStartEpoch);
      await prefs.remove(_kBaselineRemaining);
    } catch (_) {}
  }

  Future<void> _hydrateFromPrefs() async {
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      if (!prefs.containsKey(_kSessionState)) return;
      final sessIndex = prefs.getInt(_kSessionState) ?? PomodoroSessionState.idle.index;
      final restoredState = PomodoroSessionState.values[sessIndex];
      final isPaused = prefs.getBool(_kIsPaused) ?? true;
      final work = prefs.getInt(_kWork) ?? 25 * 60;
      final shortB = prefs.getInt(_kShort) ?? 5 * 60;
      final longB = prefs.getInt(_kLong) ?? 15 * 60;
      final interval = prefs.getInt(_kInterval) ?? 4;
      final round = prefs.getInt(_kRound) ?? 1;
      final task = prefs.getString(_kTask) ?? 'Genel Çalışma';
      final taskId = prefs.getString(_kTaskId);
      final taskDate = prefs.getString(_kTaskDate);
      final activeTotal = prefs.getInt(_kActiveTotal) ?? work;
      int timeRemaining = prefs.getInt(_kTimeRemaining) ?? work;
      final lastTotal = prefs.getInt(_kLastResultTotal);
      final lastRounds = prefs.getInt(_kLastResultRounds);
      final lastTask = prefs.getString(_kLastResultTask);
      final lastRewarded = prefs.getBool(_kLastResultRewarded) ?? false;

      // Eğer çalışır durumdayken kapanmışsa süreyi akışkan şekilde hesapla
      final runEpoch = prefs.getInt(_kRunStartEpoch);
      final baseline = prefs.getInt(_kBaselineRemaining);
      if (runEpoch != null && baseline != null && !isPaused &&
          (restoredState == PomodoroSessionState.work || restoredState == PomodoroSessionState.shortBreak || restoredState == PomodoroSessionState.longBreak)) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final elapsed = (now - runEpoch).clamp(0, 24 * 60 * 60);
        timeRemaining = (baseline - elapsed).clamp(0, activeTotal);
      }

      FocusSessionResult? last;
      if (lastTotal != null && lastRounds != null && lastTask != null) {
        last = FocusSessionResult(totalFocusSeconds: lastTotal, roundsCompleted: lastRounds, task: lastTask);
      }

      state = PomodoroModel(
        sessionState: restoredState,
        timeRemaining: timeRemaining,
        isPaused: isPaused,
        workDuration: work,
        shortBreakDuration: shortB,
        longBreakDuration: longB,
        longBreakInterval: interval,
        currentRound: round,
        currentTask: task,
        currentTaskIdentifier: taskId,
        currentTaskDateKey: taskDate,
        lastResult: last,
        autoStartBreaks: prefs.getBool(_kAutoBreaks) ?? false,
        autoStartWork: prefs.getBool(_kAutoWork) ?? false,
        keepScreenOn: prefs.getBool(_kKeepScreenOn) ?? false,
        activeSessionTotalDuration: activeTotal,
        lastResultRewarded: lastRewarded,
      );

      // Eğer süre bitmişse, uygun bitiş mantığını tetikle
      if (!state.isPaused && state.timeRemaining <= 0) {
        _timer?.cancel();
        _handleSessionEnd();
      } else if (!state.isPaused && state.timeRemaining > 0) {
        // Çalışma devam ediyorsa timer'ı başlat
        _startTimer();
      } else {
        _applyWakelock();
      }
    } catch (_) {}
  }

  void _startTimer() {
    _timer?.cancel();
    final baseline = state.timeRemaining;
    state = state.copyWith(isPaused: false);
    _applyWakelock();
    _persistRunStart(baselineRemaining: baseline);

    // Başlatma geri bildirimi
    try { HapticFeedback.selectionClick(); } catch (_) {}

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.timeRemaining > 0) {
        final nextRemaining = state.timeRemaining - 1;
        // Bitime 10 sn kala uyarı (yalnızca bir kez tetiklenir)
        if (nextRemaining == 10) {
          _notify('Birazdan bitiyor', 'Hazırlan: 10 saniye kaldı.');
          try { HapticFeedback.lightImpact(); } catch (_) {}
        }
        state = state.copyWith(timeRemaining: nextRemaining);
      } else {
        _timer?.cancel();
        _clearRunStart();
        _handleSessionEnd();
      }
    });
    // Durumu hafifçe gecikmeli yaz (IO yükünü azaltmak için)
    _persistState();
  }

  void _notify(String title, String body) {
    NotificationService.instance.showLocalSimple(title: title, body: body);
  }

  void _handleSessionEnd() {
    // Bitişte çalışır kayıtları temizle
    _clearRunStart();

    if (state.sessionState == PomodoroSessionState.work) {
      // 1. Odaklanma seansını veritabanına kaydet.
      _saveSession(state.currentTask, state.activeSessionTotalDuration);

      // 2. Sonucu oluştur ve ekran durumunu "tamamlandı" olarak değiştir.
      final result = FocusSessionResult(
        totalFocusSeconds: state.activeSessionTotalDuration,
        roundsCompleted: state.currentRound,
        task: state.currentTask,
      );
      state = state.copyWith(sessionState: PomodoroSessionState.completed, isPaused: true, lastResult: result, lastResultRewarded: false);
      _applyWakelock();
      _persistState();

      _notify('Odak tamamlandı', '"${state.currentTask}" için mola zamanı.');
      try { HapticFeedback.mediumImpact(); } catch (_) {}

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
        activeSessionTotalDuration: state.workDuration,
      );
      _applyWakelock();
      _persistState();
      _notify('Mola bitti', 'Yeni bir odak turu seni bekliyor.');
      try { HapticFeedback.lightImpact(); } catch (_) {}
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
        activeSessionTotalDuration: state.workDuration,
      );
      _persistState();
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
        activeSessionTotalDuration: state.longBreakDuration,
      );
      _notify('Uzun mola başladı', '${(state.longBreakDuration / 60).round()} dk dinlen.');
    } else {
      state = state.copyWith(
        sessionState: PomodoroSessionState.shortBreak,
        timeRemaining: state.shortBreakDuration,
        isPaused: true,
        clearLastResult: true,
        currentRound: previousRound,
        activeSessionTotalDuration: state.shortBreakDuration,
      );
      _notify('Mola başladı', '${(state.shortBreakDuration / 60).round()} dk nefes al.');
    }

    _applyWakelock();
    _persistState();
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
          clearLastResult: true,
          activeSessionTotalDuration: state.workDuration);
    }
    _persistState();
    _startTimer();
  }

  void pause() {
    _timer?.cancel();
    state = state.copyWith(isPaused: true);
    _applyWakelock();
    _persistState();
    _clearRunStart();
    // Duraklatma geri bildirimi
    try { HapticFeedback.selectionClick(); } catch (_) {}
  }

  void reset() {
    _timer?.cancel();
    final newModel = PomodoroModel(
      workDuration: state.workDuration,
      shortBreakDuration: state.shortBreakDuration,
      longBreakDuration: state.longBreakDuration,
      longBreakInterval: state.longBreakInterval,
      autoStartBreaks: state.autoStartBreaks,
      autoStartWork: state.autoStartWork,
      keepScreenOn: state.keepScreenOn,
      activeSessionTotalDuration: state.workDuration,
    );
    state = newModel;
    _applyWakelock();
    _persistState();
    _clearRunStart();
  }

  void skipBreakAndStartWork() {
    if (state.sessionState == PomodoroSessionState.shortBreak || state.sessionState == PomodoroSessionState.longBreak) {
      state = state.copyWith(
        sessionState: PomodoroSessionState.work,
        timeRemaining: state.workDuration,
        isPaused: true,
        activeSessionTotalDuration: state.workDuration,
      );
      _applyWakelock();
      _persistState();
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
    _persistState();
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

  void updateSettings({int? work, int? short, int? long, int? interval, bool applyToCurrent = false}) {
    final newWorkDuration = (work ?? (state.workDuration ~/ 60)) * 60;
    final newShort = (short ?? (state.shortBreakDuration ~/ 60)) * 60;
    final newLong = (long ?? (state.longBreakDuration ~/ 60)) * 60;
    final newInterval = interval ?? state.longBreakInterval;

    // Temel: yeni ayarları yaz
    state = state.copyWith(
      workDuration: newWorkDuration,
      shortBreakDuration: newShort,
      longBreakDuration: newLong,
      longBreakInterval: newInterval,
    );

    if (state.sessionState == PomodoroSessionState.idle) {
      state = state.copyWith(timeRemaining: newWorkDuration, activeSessionTotalDuration: newWorkDuration);
    } else if (applyToCurrent) {
      // Mevcut oturuma uygula: ilgili oturumu yeni toplamla yeniden başlat
      int target = switch (state.sessionState) {
        PomodoroSessionState.work => newWorkDuration,
        PomodoroSessionState.shortBreak => newShort,
        PomodoroSessionState.longBreak => newLong,
        PomodoroSessionState.completed => newWorkDuration,
        PomodoroSessionState.idle => newWorkDuration,
      };
      final wasPaused = state.isPaused;
      state = state.copyWith(
        activeSessionTotalDuration: target,
        timeRemaining: target,
        // paused durumunu koru
        isPaused: wasPaused,
      );
      if (!wasPaused) {
        // Timer koşuyorsa yeni baseline yaz
        _persistRunStart(baselineRemaining: target);
      }
    }

    _persistState();
  }

  void updatePreferences({bool? autoStartBreaks, bool? autoStartWork, bool? keepScreenOn}) {
    state = state.copyWith(
      autoStartBreaks: autoStartBreaks ?? state.autoStartBreaks,
      autoStartWork: autoStartWork ?? state.autoStartWork,
      keepScreenOn: keepScreenOn ?? state.keepScreenOn,
    );
    _applyWakelock();
    _persistState();
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

  // YENI: lastResult ödülü yazıldı olarak işaretle
  void markLastResultRewarded() {
    if (state.lastResult != null && !state.lastResultRewarded) {
      state = state.copyWith(lastResultRewarded: true);
      _persistState();
    }
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
