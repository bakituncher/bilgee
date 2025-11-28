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
    // Pomodoro ve diğer state'leri dinlemeye devam et, ancak
    // artık backend triggerları ana işi yaptığı için client-side çağrıları azalttık.
    _listenToSystemEvents();
  }

  void _listenToSystemEvents() {
    _ref.listen<PomodoroModel>(pomodoroProvider, (previous, next) {
      // Pomodoro tamamlanınca feature usage'ı güncelle, ama görev ilerlemesini backend hallediyor.
      if (previous?.sessionState != PomodoroSessionState.completed &&
          next.sessionState == PomodoroSessionState.completed &&
          next.lastResult != null &&
          !(next.lastResultRewarded)) {

        userCompletedPomodoroSession(next.lastResult!.totalFocusSeconds);
        // Tekrarlamayı engelle
        _ref.read(pomodoroProvider.notifier).markLastResultRewarded();
      }
    });

    // Haftalık plan tamamlamalarını dinle
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
  /// GÜVENLİK NOTU: Practice, Study, Focus gibi kategoriler artık backend triggerları
  /// ile yönetildiği için, bu fonksiyon sadece 'engagement' ve 'consistency' gibi
  /// soft-actionlar için kullanılmalıdır.
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

      if (route != null) {
        params['routeKey'] = route.name;
      }

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

      _ref.invalidate(optimizedQuestsProvider);

    } catch (e) {
      if (kDebugMode) {
        debugPrint('[QuestNotifier] reportAction hatası: $e');
      }
    }
  }

  // --- EYLEM BAZLI METOTLAR ---

  /// Kullanıcı bir Pomodoro seansını tamamladığında
  void userCompletedPomodoroSession(int focusSeconds) {
    // GÜVENLİK GÜNCELLEMESİ: Backend Trigger (onFocusSessionCreated) artık görevleri ilerletiyor.
    // Client sadece 'feature usage' takibi yapıyor.
    _updateUserFeatureUsage('pomodoro');
  }

  /// Haftalık planından bir görev tamamlandığında
  void userCompletedWeeklyPlanTask() {
    // Weekly plan henüz backend trigger'a tam entegre değilse client-side devam edebilir
    // veya bu da 'study' kategorisine giriyorsa kısıtlanmalı.
    // Şimdilik engagement olarak bırakıyoruz.
    _reportAction(
      QuestCategory.study,
      amount: 1,
      route: QuestRoute.weeklyPlan,
      tags: ['plan', 'schedule'],
    );
    _updateUserFeatureUsage('weeklyPlan');
  }

  /// Cevher Atölyesi quiz tamamlandı
  void userCompletedWorkshopQuiz(String subject, String topic) {
    // GÜVENLİK GÜNCELLEMESİ: Backend'de 'onTestCreated' trigger'ı bunu yakalamalı
    // (Workshop quizleri de 'tests' koleksiyonuna yazılıyorsa).
    // Eğer yazılmıyorsa, workshop için özel trigger gerekecektir.
    // Varsayım: Workshop sonuçları 'tests'e yazılmıyorsa client-side devam etmeli,
    // FAKAT backend 'practice' kategorisini blokladığı için bu çağrı başarısız olur.
    // DOĞRU YOL: Workshop sonuçlarının da bir dokümana yazılmasını sağlamak.
    _updateUserFeatureUsage('workshop');
  }

  /// Yeni deneme sonucu eklendi
  void userSubmittedTest() {
    // GÜVENLİK GÜNCELLEMESİ: Backend Trigger (onTestCreated) hallediyor.
    _updateUserFeatureUsage('testSubmission');
  }

  /// Konu performansı güncellendi (manuel)
  void userUpdatedTopicPerformance(String subject, String topic, int questionCount) {
    // Bu manuel bir giriş olduğu için 'practice' sayılmalı mı tartışmalı,
    // ancak backend blokladığı için client'tan gönderemeyiz.
    // Kullanıcının manuel veri girişini görev saymak hileye açık olabilir.
    // Şimdilik sadece usage update.
    _updateUserFeatureUsage('topicPerformance');
  }

  /// Stratejik plan onaylandı
  void userApprovedStrategy() {
    _reportAction(
      QuestCategory.engagement, // Engagement hala açık
      amount: 1,
      route: QuestRoute.strategy,
      tags: ['strategy', 'planning'],
    );
    _updateUserFeatureUsage('strategy');
    _markUserCreatedStrategicPlan();
  }

  /// Giriş yapıldı
  void userLoggedInOrOpenedApp() {
    _ref.read(sessionCompletedQuestsProvider.notifier).state = <String>{};
    _reportAction(
      QuestCategory.consistency, // Consistency hala açık
      amount: 1,
      tags: ['login', 'daily'],
    );
  }

  /// Kullanıcı bir soru çözdüğünde (coach'ta)
  void userSolvedQuestions(int questionCount, {String? subject, String? topic}) {
    // GÜVENLİK GÜNCELLEMESİ: Test sonucu kaydedilince backend halledecek.
    // Anlık soru çözümleri (deneme değilse) için backend kaydı şart.
  }

  /// Arena katılımı
  Future<void> userParticipatedInArena() async {
    await _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.arena,
      tags: ['arena', 'competition'],
    );
    _updateUserFeatureUsage('arena');
  }

  /// Kütüphane ziyareti
  Future<void> userVisitedLibrary() async {
    await _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.library,
      tags: ['library', 'review'],
    );
  }

  /// Stats raporu görüntüleme
  void userViewedStatsReport() {
    _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.stats,
      tags: ['stats', 'analysis'],
    );
    _updateUserFeatureUsage('stats');
  }

  /// Avatar özelleştirme
  void userCustomizedAvatar() {
    _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.avatar,
      tags: ['profile', 'customization'],
    );
    _updateUserFeatureUsage('avatar');
  }

  /// Motivasyon chat kullanımı
  void userUsedMotivationChat() {
    _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.motivationChat,
      tags: ['ai_feature', 'wellness'],
    );
    _updateUserFeatureUsage('motivationChat');
  }

  /// Profil ziyareti
  void userVisitedProfile() {
    _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.home,
      tags: ['profile', 'discovery'],
    );
  }

  void updateQuestProgressById(String questId, {int amount = 1}) {
    if (kDebugMode) {
      debugPrint('[QuestNotifier] updateQuestProgressById deprecated');
    }
  }

  // --- YARDIMCI METOTLAR ---

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
