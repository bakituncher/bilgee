// lib/features/quests/logic/quest_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/features/quests/models/quest_model.dart';
import 'package:taktik/features/pomodoro/logic/pomodoro_notifier.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/quests/logic/quest_session_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/features/quests/logic/quest_completion_notifier.dart';
import 'package:taktik/features/quests/logic/optimized_quests_provider.dart';
import 'package:taktik/features/quests/logic/tp_earned_notifier.dart';
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
      // Focus kategorisi görevlerini güncelle
      _reportAction(
        QuestCategory.focus,
        amount: minutes,
        route: QuestRoute.pomodoro,
        tags: ['pomodoro', 'deep_work'],
      );

      // Study kategorisi görevlerini de güncelle (comprehensive study gibi)
      _reportAction(
        QuestCategory.study,
        amount: minutes,
        route: QuestRoute.pomodoro,
        tags: ['intensive', 'productivity'],
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

  /// Kullanıcı "Etüt Odası"nda bir quiz bitirdiğinde bu metot çağrılır.
  void userCompletedWorkshopQuiz(String subject, String topic) {
    // 1. Practice (Ana kategori)
    _reportAction(
      QuestCategory.practice,
      amount: 1,
      route: QuestRoute.workshop,
      tags: ['workshop', subject.toLowerCase(), 'practice'],
    );

    // 2. Engagement (Etüt Odası keşif/oturum görevleri için)
    // Örn: daily_eng_06_workshop_session, daily_eng_03_workshop_intro
    _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.workshop,
      tags: ['workshop', 'discovery', 'review'],
    );

    // Etüt odası quiz tamamlama için puan ve toast,
    // weakness_workshop_screen.dart içinde doğrudan tetikleniyor.
    _updateUserFeatureUsage('workshop');
    if (kDebugMode) {
      debugPrint('[QuestNotifier] Atölye quizi tamamlandı - $subject/$topic');
    }
  }

  /// Kullanıcı "Etüt Odası"nda sadece konu anlatımı (study) tamamladığında bu metot çağrılır.
  /// Quiz olmadan sadece konu çalışıldığında tetiklenir.
  void userCompletedWorkshopStudy(String subject, String topic) {
    // 1. Study (Konu anlatımı kategorisi)
    _reportAction(
      QuestCategory.study,
      amount: 1,
      route: QuestRoute.workshop,
      tags: ['workshop', subject.toLowerCase(), 'study'],
    );

    // 2. Engagement (Etüt Odası keşif/oturum görevleri için)
    // Örn: daily_eng_06_workshop_session, daily_eng_03_workshop_intro
    _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.workshop,
      tags: ['workshop', 'discovery', 'review'],
    );

    // Etüt odası konu çalışması için puan ve toast,
    // weakness_workshop_screen.dart içinde doğrudan tetikleniyor.
    _updateUserFeatureUsage('workshop');
    if (kDebugMode) {
      debugPrint('[QuestNotifier] Etüt odası konu çalışması tamamlandı - $subject/$topic');
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
    // Coach'ta çözülen sorular için tüm ilgili görevlerin tag'lerini ekle:
    // - 100 Soru Maratonu: high_volume, intensive, high_value
    // - Hafta Sonu Kampı: weekend, high_volume
    // - 10 Soru Çöz: quick_win, micro_session
    // - Eksik Konu Çalışması: adaptive, weakness
    // - Hız Testi: adaptive, strength
    final tags = <String>[
      'practice',
      'topic_update',
      subject.toLowerCase(),
      // Yüksek hacimli görevler
      'high_volume',
      'intensive',
      // Hızlı görevler
      'quick_win',
      'micro_session',
      // Adaptif görevler (zayıf/güçlü konu)
      'adaptive',
      'weakness',
      'strength',
    ];

    _reportAction(
      QuestCategory.practice,
      amount: questionCount,
      route: QuestRoute.coach,
      tags: tags,
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
    // Haftalık plan oluşturma: backend updateStrategicPlan içinde +100 TP ekliyor.
    // Toast strategy_review_screen'de gösteriliyor.
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
      tags: ['login', 'daily', 'habit', 'streak'],
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
    // 1. Study (Analiz inceleme görevleri: daily_tes_02_analysis_pro)
    _reportAction(
      QuestCategory.study,
      amount: 1,
      route: QuestRoute.stats,
      tags: ['stats', 'analysis', 'review'],
    );

    // 2. Engagement (Genel kullanım)
    _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.stats,
      tags: ['stats', 'analysis'],
    );

    _updateUserFeatureUsage('stats');
  }

  /// Kullanıcı avatarını özelleştirdiğinde
  void userCustomizedAvatar() {
    _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.avatar,
      tags: ['profile', 'customization'],
    );
    _updateUserFeatureUsage('avatar');
  }

  /// Kullanıcı motivasyon chat'i kullandığında
  void userUsedMotivationChat() {
    _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.motivationChat,
      tags: ['ai_feature', 'wellness'],
    );
    _updateUserFeatureUsage('motivationChat');
  }

  /// Kullanıcı Soru Çözücü'yü kullandığında
  void userUsedQuestionSolver() {
    // 1. Focus (Ana kategori - Günlük görev)
    _reportAction(
      QuestCategory.focus,
      amount: 1,
      route: QuestRoute.questionSolver,
      tags: ['question_solver', 'ai_feature', 'practice'],
    );

    // 2. Engagement (Keşif görevi: daily_eng_04_question_solver_intro)
    _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.questionSolver,
      tags: ['question_solver', 'discovery', 'ai_feature'],
    );

    // Soru çözücü kullanımı: +10 TP
    _addDirectPoints(10, featureLabel: 'Soru Çözücü');

    _updateUserFeatureUsage('questionSolver');
  }

  /// Kullanıcı Zihin Haritası oluşturduğunda
  void userUsedMindMap() {
    // 1. Study (Ana kategori: daily_stu_01_mind_map_study)
    _reportAction(
      QuestCategory.study,
      amount: 1,
      route: QuestRoute.mindMap,
      tags: ['mind_map', 'study', 'visualization'],
    );

    // 2. Focus (Bağlantı görevi: daily_foc_05_mind_map_connect)
    _reportAction(
      QuestCategory.focus,
      amount: 1,
      route: QuestRoute.mindMap,
      tags: ['mind_map', 'study', 'connection'],
    );

    // 3. Engagement (Keşif: daily_eng_08_mind_map_explore)
    _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.mindMap,
      tags: ['mind_map', 'discovery', 'visualization'],
    );

    // Zihin haritası oluşturma: +15 TP
    _addDirectPoints(15, featureLabel: 'Zihin Haritası');

    _updateUserFeatureUsage('mindMap');
  }

  /// Kullanıcı İçerik Üretici'yi kullandığında
  void userUsedContentGenerator() {
    _reportAction(
      QuestCategory.focus, // Fixed: was study
      amount: 1,
      route: QuestRoute.contentGenerator,
      tags: ['content', 'notes', 'study'],
    );
    // Not defteri kullanımı: +10 TP
    _addDirectPoints(10, featureLabel: 'Dönüştürücü');
    _updateUserFeatureUsage('contentGenerator');
  }

  /// Kullanıcı Soru Kutusu'na soru eklediğinde
  void userUsedQuestionBox() {
    _reportAction(
      QuestCategory.focus, // Fixed: was practice (daily_foc_02_question_box is focus)
      amount: 1,
      route: QuestRoute.questionBox,
      tags: ['question_box', 'practice', 'review'],
    );
    _updateUserFeatureUsage('questionBox');
  }

  /// Kullanıcı Soru Kutusu'ndaki bir soruyu incelediğinde (Tekrar)
  void userReviewedQuestionBox() {
    _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.questionBox,
      tags: ['question_box', 'review', 'practice'],
    );
  }

  /// Kullanıcı profil ekranını ziyaret ettiğinde
  void userVisitedProfile() {
    _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.home,
      tags: ['profile', 'discovery'],
    );
  }

  /// Kullanıcı blog yazısı okuduğunda
  void userReadBlogPost() {
    _reportAction(
      QuestCategory.engagement,
      amount: 1,
      route: QuestRoute.blog,
      tags: ['discovery', 'reading', 'blog'],
    );
    _updateUserFeatureUsage('blog');
  }

  /// Legacy metod - geriye dönük uyumluluk için
  void updateQuestProgressById(String questId, {int amount = 1}) {
    // Artık kullanılmıyor - kategori bazlı güncelleme kullanın
    if (kDebugMode) {
      debugPrint('[QuestNotifier] updateQuestProgressById deprecated - use category-based methods instead');
    }
  }

  // --- YARDIMCI METOTLAR ---

  /// Doğrudan TP (engagementScore) ekler — AI Hub özellik kullanımları için.
  /// Backend rate limit + günlük kota koruması mevcuttur.
  Future<void> _addDirectPoints(int points, {String featureLabel = ''}) async {
    try {
      final functions = _ref.read(functionsProvider);
      final callable = functions.httpsCallable('tests-addEngagementPoints');
      await callable.call({'pointsToAdd': points});
      // Başarılı olunca UI bildirimi tetikle
      _ref.read(tpEarnedProvider.notifier).show(points, featureLabel);
      if (kDebugMode) {
        debugPrint('[QuestNotifier] +$points TP eklendi (AI Hub özelliği: $featureLabel)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[QuestNotifier] _addDirectPoints hatası: $e');
      }
    }
  }

  /// Kullanıcının bir özelliği kullandığını Firestore'da işaretler
  void _updateUserFeatureUsage(String featureName) {
    final user = _ref.read(userProfileProvider).value;
    if (user == null) return;

    try {
      final firestore = _ref.read(firestoreProvider);
      // FIX: Nested field update yerine map merge kullan (permission error çözümü)
      firestore.collection('users').doc(user.id).set({
        'usedFeatures': {featureName: true},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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

