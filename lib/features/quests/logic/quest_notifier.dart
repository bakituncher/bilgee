// lib/features/quests/logic/quest_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/features/quests/logic/quest_progress_controller.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'package:bilge_ai/features/pomodoro/logic/pomodoro_notifier.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/quests/logic/quest_session_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // FieldValue, SetOptions

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
    // YENİ: Pomodoro için spesifik route güncellemesi
    _controller.updateEngagementForRoute(_ref, QuestRoute.pomodoro, amount: 1);

    final int minutes = focusSeconds ~/ 60;
    if (minutes > 0) {
      _controller.updateQuestProgress(_ref, QuestCategory.focus, amount: minutes);
    }

    // Kullanıcının pomodoro kullandığını işaretle
    _updateUserFeatureUsage('pomodoro');
  }

  /// Haftalık planından bir görev tamamlandığında çağrılır (Planlı Harekât vb.).
  void userCompletedWeeklyPlanTask() {
    _controller.updateQuestProgress(_ref, QuestCategory.study, amount: 1);
    _updateUserFeatureUsage('weeklyPlan');
  }

  /// Kullanıcı "Cevher Atölyesi"nde bir quiz bitirdiğinde bu metot çağrılır.
  void userCompletedWorkshopQuiz(String subject, String topic) {
    // YENİ: Route bazlı engagement ve context bazlı practice güncellemesi
    _controller.updateEngagementForRoute(_ref, QuestRoute.workshop, amount: 1);
    _controller.updatePracticeWithContext(_ref,
      amount: 1,
      subject: subject,
      topic: topic,
      source: PracticeSource.workshop
    );

    _updateUserFeatureUsage('workshop');
    print('[QuestNotifier] Atölye quizi tamamlandı - $subject/$topic');
  }

  /// Kullanıcı yeni bir deneme sonucu eklediğinde bu metot çağrılır.
  void userSubmittedTest() {
    _controller.updateQuestProgress(_ref, QuestCategory.test_submission);
    _updateUserFeatureUsage('testSubmission');
  }

  /// Kullanıcı bir konunun performansını manuel olarak güncellediğinde bu metot çağrılır.
  void userUpdatedTopicPerformance(String subject, String topic, int questionCount) {
    _controller.updatePracticeWithContext(_ref,
      amount: questionCount,
      subject: subject,
      topic: topic,
      source: PracticeSource.general
    );
    _controller.updateQuestProgress(_ref, QuestCategory.study, amount: 1);
  }

  /// Kullanıcı yeni bir stratejik planı onayladığında bu metot çağrılır.
  void userApprovedStrategy() {
    // YENİ: Stratejik planlama için spesifik route güncellemesi
    _controller.updateEngagementForRoute(_ref, QuestRoute.strategy, amount: 1);

    // Kullanıcının strateji özelliğini kullandığını işaretle
    _updateUserFeatureUsage('strategy');
    _markUserCreatedStrategicPlan();

    print('[QuestNotifier] Stratejik plan onaylandı - görevler güncellendi');
  }

  /// Kullanıcı giriş yaptığında veya uygulamayı açtığında tutarlılık görevlerini tetikler.
  void userLoggedInOrOpenedApp() {
    // Session state'i temizle - günlük görevler yenilendiğinde eski tamamlanmışları temizlemek için
    _ref.read(sessionCompletedQuestsProvider.notifier).state = <String>{};
    _controller.updateQuestProgress(_ref, QuestCategory.consistency);
  }

  /// YENİ: Kullanıcı bir soru çözdüğünde (coach'ta)
  void userSolvedQuestions(int questionCount, {String? subject, String? topic}) {
    _controller.updatePracticeWithContext(_ref,
      amount: questionCount,
      subject: subject,
      topic: topic,
      source: PracticeSource.general,
    );
  }

  /// YENİ: Kullanıcı arena'da yarışmaya katıldığında
  void userParticipatedInArena() {
    _controller.updateEngagementForRoute(_ref, QuestRoute.arena, amount: 1);
    _updateUserFeatureUsage('arena');
  }

  /// YENİ: Kullanıcı kütüphaneyi ziyaret ettiğinde
  void userVisitedLibrary() {
    _controller.updateEngagementForRoute(_ref, QuestRoute.library, amount: 1);
  }

  /// ESKI UYUMLULUK: Legacy metod - ID ile görev ilerletme
  void updateQuestProgressById(String questId, {int amount = 1}) {
    // Bu metod artık genel kategori güncellemesi yapıyor
    // Spesifik ID güncellemesi için backend'e yönlendirme yapılabilir
    _controller.updateQuestProgress(_ref, QuestCategory.study, amount: amount);
  }

  /// YENİ: Kullanıcı stats raporunu görüntülediğinde
  void userViewedStatsReport() {
    _controller.updateEngagementForRoute(_ref, QuestRoute.stats, amount: 1);
    _updateUserFeatureUsage('stats');
  }

  /// YENİ: Kullanıcı özellik kullanımını işaretle (kişiselleştirme için)
  void _updateUserFeatureUsage(String feature) {
    final user = _ref.read(userProfileProvider).value;
    if (user == null) return;

    // Firestore'da kullanıcının usedFeatures alanını güncelle
    final fs = _ref.read(firestoreProvider);
    fs.collection('users').doc(user.id).set(
      {'usedFeatures.$feature': true},
      SetOptions(merge: true),
    ).catchError((e) {
      print('[QuestNotifier] Feature usage update failed: $e');
    });
  }

  /// YENİ: Kullanıcının stratejik plan oluşturduğunu işaretle
  void _markUserCreatedStrategicPlan() {
    final user = _ref.read(userProfileProvider).value;
    if (user == null) return;

    final fs = _ref.read(firestoreProvider);
    fs.collection('users').doc(user.id).set(
      {
        'hasCreatedStrategicPlan': true,
        'lastStrategyCreationDate': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    ).catchError((e) {
      print('[QuestNotifier] Strategic plan marking failed: $e');
    });
  }
}
