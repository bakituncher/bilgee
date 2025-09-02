// lib/features/quests/logic/quest_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/features/quests/logic/quest_progress_controller.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'package:bilge_ai/features/pomodoro/logic/pomodoro_notifier.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';

// Bu provider'ın varlığı devam etmeli, arayüzden çağrılar bunun üzerinden yapılacak.
final questNotifierProvider = StateNotifierProvider.autoDispose<QuestNotifier, bool>((ref) {
  return QuestNotifier(ref);
});

/// Uygulamadaki görev ilerlemesiyle ilgili tüm eylemler için TEK MERKEZİ NOKTA.
/// Arayüzden gelen "Kullanıcı X eylemini yaptı" bilgisini alıp, hangi görevlerin
/// güncelleneceğine karar verir.
class QuestNotifier extends StateNotifier<bool> {
  final Ref _ref;
  // QuestProgressController, tüm ağır işi yapan merkezi mantık birimidir.
  final QuestProgressController _controller = const QuestProgressController();

  QuestNotifier(this._ref) : super(false) {
    // Pomodoro gibi arkaplan state'lerini dinlemeye devam et.
    _listenToSystemEvents();
  }

  /// Pomodoro gibi state değişikliklerini dinleyerek görevleri günceller.
  void _listenToSystemEvents() {
    _ref.listen<PomodoroModel>(pomodoroProvider, (previous, next) {
      // Sadece 'completed' durumuna ilk geçişte tetikle
      if (previous?.sessionState != PomodoroSessionState.completed && next.sessionState == PomodoroSessionState.completed) {
        if (next.lastResult != null) {
          userCompletedPomodoroSession(next.lastResult!.totalFocusSeconds);
        }
      }
    });

    // Haftalık plan tamamlamalarını dinle ve Study görevlerini ilerlet
    final today = DateTime.now();
    _ref.listen(completedTasksForDateProvider(today), (prev, next) {
      final int prevCount = prev?.maybeWhen(data: (List<String> l) => l.length, orElse: () => 0) ?? 0;
      final int nextCount = next.maybeWhen(data: (List<String> l) => l.length, orElse: () => 0);
      final int diff = nextCount - prevCount;
      if (diff > 0) {
        _controller.updateQuestProgress(_ref, QuestCategory.study, amount: diff);
      }
    });
  }

  // --- YENİ EYLEM BAZLI METOTLAR ---

  /// Kullanıcı bir Pomodoro seansını tamamladığında bu metot çağrılır.
  void userCompletedPomodoroSession(int focusSeconds) {
    _controller.updateQuestProgress(_ref, QuestCategory.engagement, amount: 1);
    final int minutes = focusSeconds ~/ 60;
    if (minutes > 0) {
      _controller.updateQuestProgress(_ref, QuestCategory.focus, amount: minutes);
    }
  }

  /// Haftalık planından bir görev tamamlandığında çağrılır (Planlı Harekât vb.).
  void userCompletedWeeklyPlanTask() {
    _controller.updateQuestProgress(_ref, QuestCategory.study, amount: 1);
  }

  /// Kullanıcı "Cevher Atölyesi"nde bir quiz bitirdiğinde bu metot çağrılır.
  void userCompletedWorkshopQuiz(String subject, String topic) {
    _controller.updateQuestProgress(_ref, QuestCategory.engagement, amount: 1);
    _controller.updatePracticeWithContext(_ref, amount: 1, subject: subject, topic: topic, source: PracticeSource.workshop);
  }

  /// Kullanıcı yeni bir deneme sonucu eklediğinde bu metot çağrılır.
  void userSubmittedTest() {
    _controller.updateQuestProgress(_ref, QuestCategory.test_submission);
  }

  /// Kullanıcı bir konunun performansını manuel olarak güncellediğinde bu metot çağrılır.
  void userUpdatedTopicPerformance(String subject, String topic, int questionCount) {
    _controller.updatePracticeWithContext(_ref, amount: questionCount, subject: subject, topic: topic);
    _controller.updateQuestProgress(_ref, QuestCategory.study, amount: 1);
  }

  /// Kullanıcı yeni bir stratejik planı onayladığında bu metot çağrılır.
  void userApprovedStrategy() {
    _controller.updateQuestProgress(_ref, QuestCategory.engagement, amount: 1);
  }

  /// Kullanıcı giriş yaptığında veya uygulamayı açtığında tutarlılık görevlerini tetikler.
  void userLoggedInOrOpenedApp() {
    _controller.updateQuestProgress(_ref, QuestCategory.consistency);
  }

  /// Kullanıcı performans/istatistik raporunu görüntülediğinde çağrılır.
  void userViewedStatsReport() {
    _controller.updateEngagementForRoute(_ref, QuestRoute.stats, amount: 1);
  }

  /// Kullanıcı kütüphaneyi/Arşiv ekranını görüntülediğinde çağrılır.
  void userVisitedLibrary() {
    _controller.updateEngagementForRoute(_ref, QuestRoute.library, amount: 1);
  }

  /// Belirli bir ID'ye sahip görevi ilerletmek için (nadiren kullanılır).
  Future<void> updateQuestProgressById(String questId, {int amount = 1}) async {
    await _controller.updateQuestProgressById(_ref, questId, amount: amount);
  }
}
