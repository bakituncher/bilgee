// lib/features/quests/logic/quest_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/features/quests/models/quest_model.dart';
import 'package:taktik/features/pomodoro/logic/pomodoro_notifier.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/quests/logic/quest_session_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/features/quests/logic/quest_completion_notifier.dart';
import 'package:taktik/features/quests/logic/optimized_quests_provider.dart';
import 'package:flutter/foundation.dart';

// Bu provider'ın varlığı devam etmeli, arayüzden çağrılar bunun üzerinden yapılacak.
final questNotifierProvider = StateNotifierProvider.autoDispose<QuestNotifier, bool>((ref) {
  return QuestNotifier(ref);
});

/// Uygulamadaki görev ilerlemesiyle ilgili tüm eylemler için TEK MERKEZİ NOKTA.
/// Arayüzden gelen "Kullanıcı X eylemini yaptı" bilgisini alıp,
/// sunucu fonksiyonu üzerinden görevleri günceller.
class QuestNotifier extends StateNotifier<bool> {
  final Ref _ref;

  QuestNotifier(this._ref) : super(false) {
    // Pomodoro gibi arkaplan state'lerini dinlemeye devam et.
    _listenToSystemEvents();
  }

  /// Pomodoro gibi state değişikliklerini dinleyerek görevleri günceller.
  void _listenToSystemEvents() {
    _ref.listen<PomodoroModel>(pomodoroProvider, (previous, next) {
      // Sadece 'completed' durumuna ilk geçişte tetikle ve henüz ödüllendirilmemişse
      if (previous?.sessionState != PomodoroSessionState.completed &&
          next.sessionState == PomodoroSessionState.completed &&
          next.lastResult != null &&
          !(next.lastResultRewarded)) {
        userCompletedPomodoroSession(next.lastResult!.totalFocusSeconds);
        // Tekrarlamayı engelle
        _ref.read(pomodoroProvider.notifier).markLastResultRewarded();
      }
    });

    // Haftalık plan tamamlamalarını dinle ve Study görevlerini ilerlet
    final today = DateTime.now();
    _ref.listen(completedTasksForDateProvider(today), (prev, next) {
      final int prevCount = prev?.maybeWhen(data: (List<String> l) => l.length, orElse: () => 0) ?? 0;
      final int nextCount = next.maybeWhen(data: (List<String> l) => l.length, orElse: () => 0);
      final int diff = nextCount - prevCount;
      if (diff > 0) {
        userCompletedWeeklyPlanTask();
      }
    });
  }

  /// Merkezi Eylem Raporlama Fonksiyonu - Sunucu tarafında görev günceller
  Future<void> _reportAction(
    QuestCategory category, {
    int amount = 1,
    QuestRoute? route,
    List<String>? tags,
  }) async {
    try {
      final functions = _ref.read(functionsProvider);
      final callable = functions.httpsCallable('quests-reportAction');

      final params = <String, dynamic>{
        'category': category.name,
        'amount': amount,
      };

      // Route bazlı filtreleme
      if (route != null) {
        params['routeKey'] = route.name;
      }

      // Tag bazlı filtreleme
      if (tags != null && tags.isNotEmpty) {
        params['tags'] = tags;
      }

      final result = await callable.call(params);

      // Fonksiyon bir görev tamamlandığını bildirirse, UI'ı tetikle
      final data = result.data as Map<String, dynamic>?;
      if (data?['completedQuest'] != null) {
        final questData = data!['completedQuest'] as Map<String, dynamic>;
        final questId = questData['id'] ?? questData['qid'] ?? '';
        if (questId.isNotEmpty) {
          final quest = Quest.fromMap(questData, questId);
          _ref.read(questCompletionProvider.notifier).show(quest);
        }
      }

      // Provider'ları yenile
      _ref.invalidate(optimizedQuestsProvider);

    } catch (e) {
      if (kDebugMode) {
        debugPrint('[QuestNotifier] reportAction hatası: $e');
      }
    }
  }

  // --- EYLEM BAZLI METOTLAR ---

  /// Kullanıcı bir Pomodoro seansını tamamladığında bu metot çağrılır.
  void userCompletedPomodoroSession(int focusSeconds) {
    final int minutes = focusSeconds ~/ 60;
    if (minutes > 0) {
      _reportAction(
        QuestCategory.focus,
        amount: minutes,
        route: QuestRoute.pomodoro,
        tags: ['pomodoro', 'deep_work'],
      );
    }
    _updateUserFeatureUsage('pomodoro');
  }

  /// Haftalık planından bir görev tamamlandığında çağrılır (Planlı Harekât vb.).
  void userCompletedWeeklyPlanTask() {
    _reportAction(
      QuestCategory.study,
      amount: 1,
      route: QuestRoute.weeklyPlan,
      tags: ['plan', 'schedule'],
    );
    _updateUserFeatureUsage('weeklyPlan');
  }

  /// Kullanıcı "Cevher Atölyesi"nde bir quiz bitirdiğinde bu metot çağrılır.
  void userCompletedWorkshopQuiz(String subject, String topic) {
    _reportAction(
      QuestCategory.practice,
      amount: 1,
      route: QuestRoute.workshop,
      tags: ['workshop', subject.toLowerCase()],
    );
    _updateUserFeatureUsage('workshop');
    if (kDebugMode) {
      debugPrint('[QuestNotifier] Atölye quizi tamamlandı - $subject/$topic');
    }
  }

  /// Kullanıcı yeni bir deneme sonucu eklediğinde bu metot çağrılır.
  void userSubmittedTest() {
    _reportAction(
      QuestCategory.test_submission,
      amount: 1,
      route: QuestRoute.addTest,
      tags: ['test', 'analysis'],
    );
    _updateUserFeatureUsage('testSubmission');
  }

  /// Kullanıcı bir konunun performansını manuel olarak güncellediğinde bu metot çağrılır.
  void userUpdatedTopicPerformance(String subject, String topic, int questionCount) {
    _reportAction(
      QuestCategory.practice,
      amount: questionCount,
      route: QuestRoute.coach,
      tags: ['topic_update', subject.toLowerCase()],
    );
    _reportAction(
      QuestCategory.study,
      amount: 1,
      tags: ['mastery'],
    );
  }

  /// Kullanıcı yeni bir stratejik planı onayladığında bu metot çağrılır.
  void userApprovedStrategy() {
    _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.strategy,
      tags: ['strategy', 'planning'],
    );
    _updateUserFeatureUsage('strategy');
    _markUserCreatedStrategicPlan();
    if (kDebugMode) {
      debugPrint('[QuestNotifier] Stratejik plan onaylandı - görevler güncellendi');
    }
  }

  /// Kullanıcı giriş yaptığında veya uygulamayı açtığında tutarlılık görevlerini tetikler.
  void userLoggedInOrOpenedApp() {
    // Session state'i temizle - günlük görevler yenilendiğinde eski tamamlanmışları temizlemek için
    _ref.read(sessionCompletedQuestsProvider.notifier).state = <String>{};
    _reportAction(
      QuestCategory.consistency,
      amount: 1,
      tags: ['login', 'daily'],
    );
  }

  /// Kullanıcı bir soru çözdüğünde (coach'ta)
  void userSolvedQuestions(int questionCount, {String? subject, String? topic}) {
    final tags = <String>['practice'];
    if (subject != null) tags.add(subject.toLowerCase());

    _reportAction(
      QuestCategory.practice,
      amount: questionCount,
      route: QuestRoute.coach,
      tags: tags,
    );
  }

  /// Kullanıcı arena'da yarışmaya katıldığında
  Future<void> userParticipatedInArena() async {
    await _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.arena,
      tags: ['arena', 'competition'],
    );
    _updateUserFeatureUsage('arena');
  }

  /// Kullanıcı kütüphaneyi ziyaret ettiğinde
  Future<void> userVisitedLibrary() async {
    await _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.library,
      tags: ['library', 'review'],
    );
  }

  /// Kullanıcı stats raporunu görüntülediğinde
  void userViewedStatsReport() {
    _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.stats,
      tags: ['stats', 'analysis'],
    );
    _updateUserFeatureUsage('stats');
  }

  /// Legacy metod - geriye dönük uyumluluk için
  void updateQuestProgressById(String questId, {int amount = 1}) {
    // Artık kullanılmıyor - kategori bazlı güncelleme kullanın
    if (kDebugMode) {
      debugPrint('[QuestNotifier] updateQuestProgressById deprecated - use category-based methods instead');
    }
  }

  // --- YARDIMCI METOTLAR ---

  /// Kullanıcının bir özelliği kullandığını Firestore'da işaretler
  void _updateUserFeatureUsage(String featureName) {
    final user = _ref.read(userProfileProvider).value;
    if (user == null) return;

    try {
      final firestore = _ref.read(firestoreProvider);
      firestore.collection('users').doc(user.id).update({
        'usedFeatures.$featureName': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[QuestNotifier] Feature usage update hatası: $e');
      }
    }
  }

  /// Kullanıcının stratejik plan oluşturduğunu işaretler
  void _markUserCreatedStrategicPlan() {
    final user = _ref.read(userProfileProvider).value;
    if (user == null) return;

    try {
      final firestore = _ref.read(firestoreProvider);
      firestore.collection('users').doc(user.id).update({
        'hasCreatedStrategicPlan': true,
        'lastStrategyCreationDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[QuestNotifier] Strategy plan mark hatası: $e');
      }
    }
  }
}

