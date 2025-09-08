import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'package:bilge_ai/features/quests/quest_armory.dart';
import 'package:bilge_ai/features/quests/logic/quest_completion_notifier.dart';
import 'package:bilge_ai/features/quests/logic/quest_service.dart';
import 'package:bilge_ai/core/analytics/analytics_logger.dart';
import 'dart:async';
import 'package:bilge_ai/core/app_check/app_check_helper.dart';
import 'package:bilge_ai/features/quests/logic/quest_session_state.dart';

enum PracticeSource { general, workshop }

class QuestProgressController {
  const QuestProgressController();

  /// YENİ: Route bazlı engagement güncellemesi - spesifik görevleri hedefler
  Future<void> updateEngagementForRoute(Ref ref, QuestRoute route, {int amount = 1}) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    final firestoreSvc = ref.read(firestoreServiceProvider);
    final functions = ref.read(functionsProvider);

    // Tüm aktif görevleri çek (günlük, haftalık, aylık)
    final allActiveQuests = await _getAllActiveQuests(firestoreSvc, user.id);
    if (allActiveQuests.isEmpty) return;

    final sessionCompletedIds = ref.read(sessionCompletedQuestsProvider);

    // Route eşleşmesi olan engagement görevlerini bul
    final routeMatchingQuests = allActiveQuests.where((q) =>
      q.category == QuestCategory.engagement &&
      !q.isCompleted &&
      !sessionCompletedIds.contains(q.id) &&
      q.route == route
    ).toList();

    if (routeMatchingQuests.isNotEmpty) {
      // Route eşleşen görev varsa, onu öncelikle güncelle
      await _updateSpecificQuest(ref, routeMatchingQuests.first, amount, firestoreSvc, functions, user.id);
    } else {
      // Route eşleşen görev yoksa, genel engagement güncellemesi yap
      await updateQuestProgress(ref, QuestCategory.engagement, amount: amount);
    }
  }

  /// YENİ: Bağlam bazlı practice güncellemesi - konu/kaynak eşleşmesi
  Future<void> updatePracticeWithContext(Ref ref, {
    required int amount,
    String? subject,
    String? topic,
    PracticeSource? source,
  }) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    final firestoreSvc = ref.read(firestoreServiceProvider);
    final functions = ref.read(functionsProvider);

    final allActiveQuests = await _getAllActiveQuests(firestoreSvc, user.id);
    if (allActiveQuests.isEmpty) return;

    final sessionCompletedIds = ref.read(sessionCompletedQuestsProvider);

    // Practice kategorisindeki uygun görevleri bul
    final practiceQuests = allActiveQuests.where((q) =>
      q.category == QuestCategory.practice &&
      !q.isCompleted &&
      !sessionCompletedIds.contains(q.id)
    ).toList();

    if (practiceQuests.isEmpty) return;

    Quest? bestMatch;

    // 1. Öncelik: Kaynak eşleşmesi (workshop vs general)
    if (source == PracticeSource.workshop) {
      bestMatch = practiceQuests.firstWhere(
        (q) => q.route == QuestRoute.workshop || q.tags.contains('workshop'),
        orElse: () => practiceQuests.first,
      );
    }

    // 2. Öncelik: Konu eşleşmesi
    if (bestMatch == null && subject != null) {
      bestMatch = practiceQuests.firstWhere(
        (q) => q.tags.any((tag) => tag.contains(subject.toLowerCase())),
        orElse: () => practiceQuests.first,
      );
    }

    // 3. Fallback: İlk uygun görevi seç
    bestMatch ??= practiceQuests.first;

    await _updateSpecificQuest(ref, bestMatch, amount, firestoreSvc, functions, user.id);
  }

  /// Tüm aktif görevleri getir (günlük, haftalık, aylık)
  Future<List<Quest>> _getAllActiveQuests(dynamic firestoreSvc, String userId) async {
    try {
      final results = await Future.wait<List<Quest>>([
        firestoreSvc.getDailyQuestsOnce(userId),
        firestoreSvc.getWeeklyQuestsOnce(userId),
        firestoreSvc.getMonthlyQuestsOnce(userId),
      ]);

      return [...results[0], ...results[1], ...results[2]];
    } catch (e) {
      print('[QuestProgressController] Error fetching quests: $e');
      // Fallback olarak sadece günlük görevleri dön
      try {
        return await firestoreSvc.getDailyQuestsOnce(userId);
      } catch (fallbackError) {
        print('[QuestProgressController] Fallback also failed: $fallbackError');
        return <Quest>[];
      }
    }
  }

  /// Spesifik bir görevi güncelle
  Future<void> _updateSpecificQuest(
    Ref ref,
    Quest quest,
    int amount,
    dynamic firestoreSvc,
    dynamic functions,
    String userId
  ) async {
    int newProgress = quest.currentProgress;

    switch (quest.progressType) {
      case QuestProgressType.increment:
        newProgress += amount;
        break;
      case QuestProgressType.set_to_value:
        if (quest.id == 'daily_con_01_tri_sync') {
          final visits = await firestoreSvc.getVisitsForMonth(userId, DateTime.now());
          final now = DateTime.now();
          final todaysVisits = visits.where((ts) {
            final d = ts.toDate();
            return d.year == now.year && d.month == now.month && d.day == now.day;
          }).length;
          newProgress = todaysVisits;
        } else {
          newProgress = quest.currentProgress + amount;
        }
        break;
    }

    final willComplete = newProgress >= quest.goalValue;

    try {
      await firestoreSvc.updateQuestProgressAtomic(userId, quest.id, newProgress);

      if (willComplete) {
        try {
          await ensureAppCheckTokenReady();
          await functions.httpsCallable('completeQuest').call({'questId': quest.id});

          ref.read(sessionCompletedQuestsProvider.notifier).update((prev) => {...prev, quest.id});
          ref.read(questCompletionProvider.notifier).show(quest.copyWith(
            currentProgress: quest.goalValue,
            isCompleted: true,
            completionDate: Timestamp.now()
          ));
          HapticFeedback.mediumImpact();

          final user = ref.read(userProfileProvider).value;
          if (user != null) {
            ref.read(analyticsLoggerProvider).logQuestEvent(
              userId: user.id,
              event: 'quest_completed',
              data: {
                'questId': quest.id,
                'category': quest.category.name,
                'reward': quest.reward,
                'difficulty': quest.difficulty.name,
              }
            );
          }
        } catch (completionError) {
          print('Quest completion failed, retrying: $completionError');
          await Future.delayed(Duration(milliseconds: 500));
          try {
            await functions.httpsCallable('completeQuest').call({'questId': quest.id});
            ref.read(sessionCompletedQuestsProvider.notifier).update((prev) => {...prev, quest.id});
            ref.read(questCompletionProvider.notifier).show(quest.copyWith(
              currentProgress: quest.goalValue,
              isCompleted: true,
              completionDate: Timestamp.now()
            ));
            HapticFeedback.mediumImpact();
          } catch (retryError) {
            print('Quest completion retry also failed: $retryError');
          }
        }
      }
    } catch (e) {
      print('Quest progress update failed: $e');
      try {
        await Future.delayed(Duration(milliseconds: 300));
        await firestoreSvc.updateQuestProgressAtomic(userId, quest.id, newProgress);
      } catch (retryError) {
        print('Quest progress retry failed: $retryError');
      }
    }

    ref.invalidate(dailyQuestsProvider);
  }

  /// GÜNCELLENMIŞ: Genel kategori bazlı güncelleme - artık tüm görev tiplerini destekler
  Future<void> updateQuestProgress(Ref ref, QuestCategory category, {int amount = 1}) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    final firestoreSvc = ref.read(firestoreServiceProvider);
    final functions = ref.read(functionsProvider);

    // Tüm aktif görevleri çek
    final allActiveQuests = await _getAllActiveQuests(firestoreSvc, user.id);
    if (allActiveQuests.isEmpty) return;

    final sessionCompletedIds = ref.read(sessionCompletedQuestsProvider);

    // Kategori eşleşen görevleri bul
    final eligibleQuests = allActiveQuests.where((q) =>
      q.category == category &&
      !q.isCompleted &&
      !sessionCompletedIds.contains(q.id)
    ).toList();

    if (eligibleQuests.isEmpty) {
      print('[QuestProgress] Kategori $category için uygun görev bulunamadı');
      return;
    }

    // En yakın tamamlanacak görevi seç
    Quest? targetQuest;
    int minRemaining = 999999;

    for (final quest in eligibleQuests) {
      int newProgress = quest.currentProgress + amount;
      int remaining = (quest.goalValue - newProgress).clamp(0, quest.goalValue);

      if (remaining < minRemaining) {
        minRemaining = remaining;
        targetQuest = quest;
      }
    }

    if (targetQuest != null) {
      await _updateSpecificQuest(ref, targetQuest, amount, firestoreSvc, functions, user.id);
    }
  }
}
