import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'package:bilge_ai/core/analytics/analytics_logger.dart';
// YENİ: Geliştirilmiş tracking service
import 'package:bilge_ai/features/quests/logic/quest_tracking_service.dart';

enum PracticeSource { general, workshop }

class QuestProgressController {
  const QuestProgressController();

  /// YENİ: Ana görev güncelleme metodu - yeni tracking service kullanır
  Future<void> updateQuestProgress(
    Ref ref,
    QuestCategory category, {
    int amount = 1,
    QuestRoute? specificRoute,
    Map<String, dynamic>? additionalData,
    Map<String, dynamic>? filters,
  }) async {
    final trackingService = ref.read(questTrackingServiceProvider);
    
    final results = await trackingService.updateQuestsByCategory(
      category: category,
      amount: amount,
      specificRoute: specificRoute,
      filters: filters,
    );

    // Sonuçları analiz et ve gerekirse ek işlemler yap
    for (final result in results) {
      if (result.isCompleted) {
        // Analytics ve haptic feedback
        HapticFeedback.mediumImpact();
        _logQuestCompletion(ref, result.quest!);
        break; // İlk tamamlanan görevde dur
      }
    }
  }

  /// Route bazlı engagement güncellemesi - geliştirilmiş
  Future<void> updateEngagementForRoute(Ref ref, QuestRoute route, {int amount = 1}) async {
    await updateQuestProgress(
      ref,
      QuestCategory.engagement,
      amount: amount,
      specificRoute: route,
    );
  }

  /// Bağlam bazlı practice güncellemesi - geliştirilmiş
  Future<void> updatePracticeWithContext(Ref ref, {
    required int amount,
    String? subject,
    String? topic,
    PracticeSource? source,
  }) async {
    final filters = <String, dynamic>{};
    
    // Source-based filtering
    if (source == PracticeSource.workshop) {
      filters['tags'] = ['workshop'];
    }
    
    // Subject-based filtering
    if (subject != null) {
      filters['tags'] = [subject.toLowerCase()];
    }

    await updateQuestProgress(
      ref,
      QuestCategory.practice,
      amount: amount,
      filters: filters.isNotEmpty ? filters : null,
    );
  }

  /// YENİ: Test submission tracking - geliştirilmiş
  Future<void> updateTestSubmission(Ref ref, {
    required int testCount,
    String? examType,
    int? correctAnswers,
    int? totalQuestions,
  }) async {
    final additionalData = <String, dynamic>{
      if (examType != null) 'examType': examType,
      if (correctAnswers != null) 'correctAnswers': correctAnswers,
      if (totalQuestions != null) 'totalQuestions': totalQuestions,
    };

    await updateQuestProgress(
      ref,
      QuestCategory.test_submission,
      amount: testCount,
      additionalData: additionalData,
    );
  }

  /// YENİ: Study session tracking
  Future<void> updateStudySession(Ref ref, {
    required int minutes,
    String? subject,
    bool isPomodoroSession = false,
  }) async {
    final filters = <String, dynamic>{};
    
    if (isPomodoroSession) {
      filters['tags'] = ['pomodoro'];
    }
    
    if (subject != null) {
      filters['tags'] = [subject.toLowerCase()];
    }

    await updateQuestProgress(
      ref,
      QuestCategory.study,
      amount: minutes,
      filters: filters.isNotEmpty ? filters : null,
    );
  }

  /// YENİ: Consistency tracking
  Future<void> updateConsistency(Ref ref, {
    int streakDays = 1,
    String? activityType,
  }) async {
    final filters = <String, dynamic>{};
    
    if (activityType != null) {
      filters['tags'] = [activityType];
    }

    await updateQuestProgress(
      ref,
      QuestCategory.consistency,
      amount: streakDays,
      filters: filters,
    );
  }

  /// YENİ: Focus session tracking
  Future<void> updateFocusSession(Ref ref, {
    required int minutes,
    bool isDeepWork = false,
    String? technique,
  }) async {
    final filters = <String, dynamic>{};
    
    if (isDeepWork) {
      filters['tags'] = ['deep-work'];
    }
    
    if (technique != null) {
      filters['tags'] = [technique];
    }

    await updateQuestProgress(
      ref,
      QuestCategory.focus,
      amount: minutes,
      filters: filters.isNotEmpty ? filters : null,
    );
  }

  /// Analytics loglama
  void _logQuestCompletion(Ref ref, Quest quest) {
    final user = ref.read(userProfileProvider).value;
    if (user != null) {
      ref.read(analyticsLoggerProvider).logQuestEvent(
        userId: user.id,
        event: 'quest_completed_v2',
        data: {
          'questId': quest.id,
          'category': quest.category.name,
          'type': quest.type.name,
          'reward': quest.reward,
          'difficulty': quest.difficulty.name,
          'route': quest.route.name,
          'completionTime': DateTime.now().toIso8601String(),
        },
      );
    }
  }
}
