// lib/features/quests/logic/quest_system_manager.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/features/quests/models/quest_model.dart';
import 'package:taktik/features/quests/logic/quest_tracking_service.dart';
import 'package:taktik/features/quests/logic/quest_navigation_manager.dart';
import 'package:taktik/features/quests/logic/quest_progress_controller.dart';
import 'package:taktik/features/quests/logic/optimized_quests_provider.dart';

/// Merkezi Quest System Manager
/// Tüm görev işlemlerini tek noktadan yöneten ana servis
class QuestSystemManager {
  final Ref _ref;

  QuestSystemManager(this._ref);

  // Lazy loaded services
  QuestTrackingService get _trackingService => _ref.read(questTrackingServiceProvider);
  QuestNavigationManager get _navigationManager => _ref.read(questNavigationManagerProvider);
  QuestProgressController get _progressController => const QuestProgressController();

  /// =====================
  /// GÜNLÜK FETİHLER İŞLEMLERİ
  /// =====================

  /// Günlük fetih sayfasına güvenli navigasyon
  Future<void> navigateToQuest(BuildContext context, Quest quest) async {
    await _navigationManager.navigateToQuest(context, quest, _ref);
  }

  /// Günlük fetihlerdeki aktif görevleri getir
  List<Quest> getDailyActiveQuests() {
    final questsState = _ref.read(optimizedQuestsProvider);
    return questsState.dailyQuests?.where((q) => !q.isCompleted).toList() ?? [];
  }

  /// Günlük fetih tamamlama oranını hesapla
  double getDailyCompletionRate() {
    final questsState = _ref.read(optimizedQuestsProvider);
    final dailyQuests = questsState.dailyQuests ?? [];
    if (dailyQuests.isEmpty) return 0.0;

    final completed = dailyQuests.where((q) => q.isCompleted).length;
    return completed / dailyQuests.length;
  }

  /// =====================
  /// GÖREV TAKİP İŞLEMLERİ
  /// =====================

  /// Pomodoro oturumu tamamlandığında
  Future<void> onPomodoroSessionCompleted({
    required int minutes,
    String? subject,
  }) async {
    await _progressController.updateStudySession(
      _ref,
      minutes: minutes,
      subject: subject,
      isPomodoroSession: true,
    );
  }

  /// Test çözme tamamlandığında
  Future<void> onTestCompleted({
    required int testCount,
    String? examType,
    int? correctAnswers,
    int? totalQuestions,
  }) async {
    await _progressController.updateTestSubmission(
      _ref,
      testCount: testCount,
      examType: examType,
      correctAnswers: correctAnswers,
      totalQuestions: totalQuestions,
    );
  }

  /// Sayfa ziyareti (engagement)
  Future<void> onPageVisit(QuestRoute route) async {
    await _progressController.updateEngagementForRoute(_ref, route);
  }

  /// Workshop aktivitesi
  Future<void> onWorkshopActivity({
    required int amount,
    String? subject,
  }) async {
    await _progressController.updatePracticeWithContext(
      _ref,
      amount: amount,
      subject: subject,
      source: PracticeSource.workshop,
    );
  }

  /// Focus session tamamlandığında
  Future<void> onFocusSessionCompleted({
    required int minutes,
    bool isDeepWork = false,
    String? technique,
  }) async {
    await _progressController.updateFocusSession(
      _ref,
      minutes: minutes,
      isDeepWork: isDeepWork,
      technique: technique,
    );
  }

  /// Günlük streak güncellemesi
  Future<void> onDailyStreakUpdate({
    int streakDays = 1,
    String? activityType,
  }) async {
    await _progressController.updateConsistency(
      _ref,
      streakDays: streakDays,
      activityType: activityType,
    );
  }

  /// =====================
  /// GENEL GÖREV İŞLEMLERİ
  /// =====================

  /// Spesifik görev güncelleme
  Future<QuestUpdateResult> updateQuest({
    required String questId,
    required int amount,
    Map<String, dynamic>? additionalData,
  }) async {
    return await _trackingService.updateQuestProgress(
      questId: questId,
      amount: amount,
      additionalData: additionalData,
    );
  }

  /// Kategori bazlı görev filtreleme
  List<Quest> getQuestsByCategory(QuestCategory category) {
    final questsState = _ref.read(optimizedQuestsProvider);
    return questsState.getQuestsByCategory(category);
  }

  /// Route bazlı görev filtreleme
  List<Quest> getQuestsByRoute(QuestRoute route) {
    final questsState = _ref.read(optimizedQuestsProvider);
    return questsState.getQuestsByRoute(route);
  }

  /// Toplam ödül hesaplama
  int getTotalReward() {
    final questsState = _ref.read(optimizedQuestsProvider);
    return questsState.totalReward;
  }

  /// =====================
  /// YÖNLENDİRME VE NAVİGASYON
  /// =====================

  /// Route doğrulama
  String validateRoute(String originalRoute, QuestRoute questRoute) {
    return _navigationManager.validateAndCorrectRoute(originalRoute, questRoute);
  }

  /// Premium route erişimi kontrolü
  bool canAccessRoute(QuestRoute route, {required bool isPremiumUser}) {
    return _navigationManager.isRouteAccessible(route, isPremiumUser: isPremiumUser);
  }

  /// Alternatif route önerisi
  QuestRoute getAlternativeRoute(QuestRoute blockedRoute, QuestType questType) {
    return _navigationManager.suggestAlternativeRoute(blockedRoute, questType);
  }

  /// =====================
  /// DEBUG VE MONİTORİNG
  /// =====================

  /// Sistem durumu raporu
  Map<String, dynamic> getSystemStatus() {
    final questsState = _ref.read(optimizedQuestsProvider);

    return {
      'isLoaded': questsState.isLoaded,
      'isRefreshing': questsState.isRefreshing,
      'error': questsState.error,
      'dailyQuests': questsState.dailyQuests?.length ?? 0,
      'totalQuests': questsState.allQuests?.length ?? 0,
      'completionRate': questsState.completionRate,
      'lastRefresh': questsState.lastRefresh?.toIso8601String(),
    };
  }

  /// Görev sistemi yenileme
  Future<void> refreshQuests({bool force = false}) async {
    final notifier = _ref.read(optimizedQuestsProvider.notifier);
    await notifier.refreshQuests(force: force);
  }
}

/// Provider for QuestSystemManager
final questSystemManagerProvider = Provider<QuestSystemManager>((ref) {
  return QuestSystemManager(ref);
});

/// Convenience extensions for easier usage
extension QuestSystemHelper on WidgetRef {
  QuestSystemManager get questSystem => read(questSystemManagerProvider);
}

extension QuestSystemConsumerHelper on ConsumerState {
  QuestSystemManager get questSystem => ref.read(questSystemManagerProvider);
}

extension QuestSystemRefHelper on Ref {
  QuestSystemManager get questSystem => read(questSystemManagerProvider);
}
