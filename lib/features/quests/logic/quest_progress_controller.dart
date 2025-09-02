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

  Future<void> updateQuestProgress(Ref ref, QuestCategory category, {int amount = 1}) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;
    final firestoreSvc = ref.read(firestoreServiceProvider);
    final functions = ref.read(functionsProvider);
    final activeQuests = await firestoreSvc.getDailyQuestsOnce(user.id);
    if (activeQuests.isEmpty) return;
    final sessionCompletedIds = ref.read(sessionCompletedQuestsProvider);
    bool chainAdded = false;
    bool hiddenBonusAwarded = false;
    int engagementDelta = 0;
    final Map<String, Map<String, dynamic>> updates = {};

    for (final quest in activeQuests) {
      if (quest.category != category || quest.isCompleted || sessionCompletedIds.contains(quest.id)) continue;
      int newProgress = quest.currentProgress;
      switch (quest.progressType) {
        case QuestProgressType.increment:
          newProgress += amount; break;
        case QuestProgressType.set_to_value:
          if (quest.id == 'daily_con_01_tri_sync' || quest.id == 'consistency_01') {
            final visits = await firestoreSvc.getVisitsForMonth(user.id, DateTime.now());
            final now = DateTime.now();
            final todays = visits.where((ts){ final d=ts.toDate(); return d.year==now.year && d.month==now.month && d.day==now.day;}).length;
            newProgress = todays;
          } else {
            newProgress = user.streak;
          }
          break;
      }
      final willComplete = newProgress >= quest.goalValue;
      if (willComplete) {
        try {
          // Önce ilerlemeyi sunucuya yaz ki anti-fake kontrolünden geçsin
          await firestoreSvc.updateQuestFields(user.id, quest.id, {
            'currentProgress': newProgress.clamp(quest.currentProgress, quest.goalValue),
          });
          await ensureAppCheckTokenReady();
          await functions.httpsCallable('completeQuest').call({'questId': quest.id});
          ref.read(sessionCompletedQuestsProvider.notifier).update((prev)=>{...prev, quest.id});
          ref.read(questCompletionProvider.notifier).show(quest.copyWith(currentProgress: quest.goalValue, isCompleted: true, completionDate: Timestamp.now()));
          HapticFeedback.mediumImpact();
          ref.read(analyticsLoggerProvider).logQuestEvent(userId: user.id, event: 'quest_completed', data: {
            'questId': quest.id,'category': quest.category.name,'reward': quest.reward,'difficulty': quest.difficulty.name,
          });
          await _maybeAddNextChainQuest(ref, quest, user.id, onAdded: ()=> chainAdded = true);
        } catch (e) {
          // Sunucu hatası durumunda lokal fallback
          updates[quest.id] = { 'currentProgress': quest.goalValue,'isCompleted': true,'completionDate': Timestamp.now(),};
        }
      } else if (newProgress > quest.currentProgress) {
        updates[quest.id] = { 'currentProgress': newProgress };
        ref.read(analyticsLoggerProvider).logQuestEvent(userId: user.id, event: 'quest_progress', data: {
          'questId': quest.id,'progress': newProgress,'goal': quest.goalValue,
        });
      }
    }
    // Gizli sandık ve diğer bonus mantığı aynı kalıyor - tamamlanmış görevler server üzerinden işaretlendiği için onları dahil et.
    Quest? celebration;
    for (final q in activeQuests) { if (q.id == 'celebration_01' && !q.isCompleted) { celebration = q; break; } }
    if (celebration != null) {
      final completedCategories = <QuestCategory>{};
      for (final q in activeQuests) {
        final locallyUpdated = updates.containsKey(q.id) ? (updates[q.id]!['isCompleted'] == true || q.isCompleted) : q.isCompleted;
        final sessionCompleted = ref.read(sessionCompletedQuestsProvider).contains(q.id);
        if (locallyUpdated || sessionCompleted) completedCategories.add(q.category);
      }
      if (completedCategories.length >= 4) {
        try {
          await functions.httpsCallable('completeQuest').call({'questId': celebration.id});
          ref.read(questCompletionProvider.notifier).show(celebration.copyWith(currentProgress: celebration.goalValue, isCompleted: true, completionDate: Timestamp.now()));
          HapticFeedback.mediumImpact();
        } catch(_) {
          updates[celebration.id] = {'currentProgress': celebration.goalValue,'isCompleted': true,'completionDate': Timestamp.now()};
          engagementDelta += celebration.reward;
        }
      }
    }
    if (updates.isNotEmpty || engagementDelta != 0) {
      await firestoreSvc.batchUpdateQuestFields(user.id, updates, engagementDelta: engagementDelta);
      ref.invalidate(dailyQuestsProvider);
    } else {
      // yine de listeyi tazele (sunucu tamamladıysa)
      ref.invalidate(dailyQuestsProvider);
    }
    if (hiddenBonusAwarded || chainAdded) {}
  }

  Future<void> updateQuestProgressById(Ref ref, String questId, {int amount = 1}) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;
    final firestoreSvc = ref.read(firestoreServiceProvider);
    final functions = ref.read(functionsProvider);
    final activeQuests = await firestoreSvc.getDailyQuestsOnce(user.id);
    Quest? quest;
    for (final q in activeQuests) { if (q.id == questId) { quest = q; break; } }
    if (quest == null || quest.isCompleted) return;
    int newProgress = quest.currentProgress + amount;
    final Map<String, Map<String,dynamic>> updates = {};
    if (newProgress >= quest.goalValue) {
      try {
        await firestoreSvc.updateQuestFields(user.id, quest.id, {'currentProgress': newProgress.clamp(quest.currentProgress, quest.goalValue)});
        await ensureAppCheckTokenReady();
        await functions.httpsCallable('completeQuest').call({'questId': quest.id});
        ref.read(sessionCompletedQuestsProvider.notifier).update((prev)=>{...prev, quest!.id});
        ref.read(questCompletionProvider.notifier).show(quest.copyWith(currentProgress: quest.goalValue, isCompleted: true, completionDate: Timestamp.now()));
        HapticFeedback.mediumImpact();
        ref.read(analyticsLoggerProvider).logQuestEvent(userId: user.id, event: 'quest_completed', data: {'questId': quest.id,'category': quest.category.name,'reward': quest.reward,'difficulty': quest.difficulty.name});
        await _maybeAddNextChainQuest(ref, quest, user.id);
      } catch (_) {
        updates[quest.id] = {'currentProgress': quest.goalValue,'isCompleted': true,'completionDate': Timestamp.now()};
      }
    } else {
      updates[quest.id] = {'currentProgress': newProgress};
      ref.read(analyticsLoggerProvider).logQuestEvent(userId: user.id, event: 'quest_progress', data: {'questId': quest.id,'progress': newProgress,'goal': quest.goalValue});
    }
    if (updates.isNotEmpty) await firestoreSvc.batchUpdateQuestFields(user.id, updates);
    ref.invalidate(dailyQuestsProvider);
  }

  Future<void> updateEngagementForRoute(Ref ref, QuestRoute route, {int amount = 1}) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;
    final firestoreSvc = ref.read(firestoreServiceProvider);
    final functions = ref.read(functionsProvider);
    final activeQuests = await firestoreSvc.getDailyQuestsOnce(user.id);
    if (activeQuests.isEmpty) return;
    final sessionCompletedIds = ref.read(sessionCompletedQuestsProvider);
    final Map<String, Map<String, dynamic>> updates = {};
    for (final quest in activeQuests) {
      if (quest.category != QuestCategory.engagement || quest.isCompleted || sessionCompletedIds.contains(quest.id)) continue;
      if (quest.route != route) continue;
      int newProgress = quest.currentProgress + amount;
      final willComplete = newProgress >= quest.goalValue;
      if (willComplete) {
        try {
          await firestoreSvc.updateQuestFields(user.id, quest.id, {'currentProgress': newProgress.clamp(quest.currentProgress, quest.goalValue)});
          await ensureAppCheckTokenReady();
          await functions.httpsCallable('completeQuest').call({'questId': quest.id});
          ref.read(sessionCompletedQuestsProvider.notifier).update((prev)=>{...prev, quest.id});
          ref.read(questCompletionProvider.notifier).show(quest.copyWith(currentProgress: quest.goalValue, isCompleted: true, completionDate: Timestamp.now()));
          HapticFeedback.mediumImpact();
          ref.read(analyticsLoggerProvider).logQuestEvent(userId: user.id, event: 'quest_completed', data: {'questId': quest.id,'category': quest.category.name,'reward': quest.reward,'difficulty': quest.difficulty.name});
        } catch (_) {
          updates[quest.id] = {'currentProgress': quest.goalValue,'isCompleted': true,'completionDate': Timestamp.now()};
        }
      } else if (newProgress > quest.currentProgress) {
        updates[quest.id] = {'currentProgress': newProgress};
        ref.read(analyticsLoggerProvider).logQuestEvent(userId: user.id, event: 'quest_progress', data: {'questId': quest.id,'progress': newProgress,'goal': quest.goalValue});
      }
    }
    if (updates.isNotEmpty) {
      await firestoreSvc.batchUpdateQuestFields(user.id, updates);
    }
    ref.invalidate(dailyQuestsProvider);
  }

  Future<void> updatePracticeWithContext(Ref ref, {required int amount, required String subject, required String topic, PracticeSource source = PracticeSource.general}) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;
    final firestoreSvc = ref.read(firestoreServiceProvider);
    final functions = ref.read(functionsProvider);
    final activeQuests = await firestoreSvc.getDailyQuestsOnce(user.id);
    if (activeQuests.isEmpty) return;
    final t = topic.toLowerCase();
    String? subtype;
    if (t.contains('paragraf')) subtype = 'paragraph';
    else if (t.contains('problem')) subtype = 'problem';
    else if (t.contains('sözel mantık') || t.contains('sozel mantik')) subtype = 'verbal_logic';
    else if (t.contains('sayısal mantık') || t.contains('sayisal mantik')) subtype = 'quant_logic';
    final sessionCompletedIds = ref.read(sessionCompletedQuestsProvider);
    bool chainAdded = false;
    bool hiddenBonusAwarded = false;
    int engagementDelta = 0;
    final Map<String, Map<String, dynamic>> updates = {};
    for (final quest in activeQuests) {
      if (quest.category != QuestCategory.practice || quest.isCompleted || sessionCompletedIds.contains(quest.id)) continue;

      // Workshop zinciri/pratik görevlerinin sadece workshop kaynağından ilerlemesi
      final isWorkshopQuest = quest.id.startsWith('chain_workshop_') || quest.actionRoute.contains('weakness-workshop') || quest.tags.contains('workshop');
      if (source == PracticeSource.general && isWorkshopQuest) continue;
      if (source == PracticeSource.workshop && !isWorkshopQuest) continue;

      int newProgress = quest.currentProgress + amount;
      if (quest.tags.contains('paragraph') && subtype != 'paragraph') continue;
      if (quest.tags.contains('problem') && subtype != 'problem') continue;
      final willComplete = newProgress >= quest.goalValue;
      if (willComplete) {
        try {
          await firestoreSvc.updateQuestFields(user.id, quest.id, {'currentProgress': newProgress.clamp(quest.currentProgress, quest.goalValue)});
          await ensureAppCheckTokenReady();
          await functions.httpsCallable('completeQuest').call({'questId': quest.id});
          ref.read(sessionCompletedQuestsProvider.notifier).update((prev)=>{...prev, quest.id});
          ref.read(questCompletionProvider.notifier).show(quest.copyWith(currentProgress: quest.goalValue, isCompleted: true, completionDate: Timestamp.now()));
          HapticFeedback.mediumImpact();
          ref.read(analyticsLoggerProvider).logQuestEvent(userId: user.id, event: 'quest_completed', data: {'questId': quest.id,'category': quest.category.name,'reward': quest.reward,'difficulty': quest.difficulty.name});
          await _maybeAddNextChainQuest(ref, quest, user.id, onAdded: ()=> chainAdded = true);
        } catch (_) {
          updates[quest.id] = {'currentProgress': quest.goalValue,'isCompleted': true,'completionDate': Timestamp.now()};
        }
      } else if (newProgress > quest.currentProgress) {
        updates[quest.id] = {'currentProgress': newProgress};
        ref.read(analyticsLoggerProvider).logQuestEvent(userId: user.id, event: 'quest_progress', data: {'questId': quest.id,'progress': newProgress,'goal': quest.goalValue});
      }
    }
    if (updates.isNotEmpty || engagementDelta != 0) {
      await firestoreSvc.batchUpdateQuestFields(user.id, updates, engagementDelta: engagementDelta);
      ref.invalidate(dailyQuestsProvider);
    } else {
      ref.invalidate(dailyQuestsProvider);
    }
    if (hiddenBonusAwarded || chainAdded) {}
  }

  Future<void> _maybeAddNextChainQuest(Ref ref, Quest quest, String userId, {VoidCallback? onAdded}) async {
    const Map<String,String> chainNextMap = {
      'chain_focus_1': 'chain_focus_2',
      'chain_focus_2': 'chain_focus_3',
      'chain_workshop_1': 'chain_workshop_2',
      'chain_workshop_2': 'chain_workshop_3',
    };

    // Dinamik: Ustalık Zinciri (subject bazlı)
    if ((quest.chainId ?? '').startsWith('chain_mastery_') && (quest.chainStep ?? 1) < 3) {
      final nextStep = (quest.chainStep ?? 1) + 1;
      // Zaten var mı kontrolü
      final existing = await ref.read(firestoreServiceProvider).getDailyQuestsOnce(userId);
      final nextIdDynamic = '${quest.chainId}_$nextStep';
      if (existing.any((q)=> q.id == nextIdDynamic)) return;
      // Subject tag'inden ders adını çıkar
      String subject = 'Seçili Ders';
      for (final tag in quest.tags) {
        if (tag.toLowerCase().startsWith('subject:')) { subject = tag.split(':').sublist(1).join(':'); break; }
      }
      final titles = {
        2: 'Ustalık Zinciri II: $subject Ritm Pekiştirme',
        3: 'Ustalık Zinciri III: $subject Derin Seri',
      };
      final goals = { 1: 20, 2: 30, 3: 40 };
      final newQuest = Quest(
        id: nextIdDynamic,
        title: titles[nextStep] ?? 'Ustalık Zinciri $nextStep: $subject',
        description: nextStep==2
            ? '$subject kalesinde 30 seçilmiş soruyla ritmi pekiştir. Hata türlerini not et.'
            : '$subject kalesinde 40 soruluk derin seri. Zorlandığın tipleri işaretle.',
        type: QuestType.daily,
        category: QuestCategory.practice,
        progressType: QuestProgressType.increment,
        reward: quest.reward + 10,
        goalValue: goals[nextStep] ?? (quest.goalValue + 10),
        actionRoute: quest.actionRoute,
        route: quest.route,
        tags: {
          ...quest.tags.where((t)=> !t.startsWith('subject:')).toSet(),
          'subject:$subject',
          'chain','strength','mastery_chain'
        }.toList(),
        chainId: quest.chainId,
        chainStep: nextStep,
        chainLength: 3,
      );
      await ref.read(firestoreServiceProvider).upsertQuest(userId, newQuest);
      ref.read(analyticsLoggerProvider).logQuestEvent(userId: userId, event: 'quest_chain_next_added', data: {
        'fromQuestId': quest.id,'nextQuestId': newQuest.id,'chainId': newQuest.chainId,'chainStep': newQuest.chainStep,
      });
      onAdded?.call();
      return;
    }

    if (!chainNextMap.containsKey(quest.id)) return;
    final nextId = chainNextMap[quest.id]!;

    // Zaten var mı kontrolü
    final existing = await ref.read(firestoreServiceProvider).getDailyQuestsOnce(userId);
    if (existing.any((q)=>q.id==nextId)) return;

    final template = questArmory.firstWhere((t)=>t['id']==nextId, orElse: ()=>{});
    if (template.isEmpty) return;
    final newQuest = Quest(
      id: template['id'],
      title: template['title'],
      description: template['description'],
      type: QuestType.values.byName((template['type'] ?? 'daily')),
      category: QuestCategory.values.byName(template['category']),
      progressType: QuestProgressType.values.byName((template['progressType'] ?? 'increment')),
      reward: template['reward'] ?? 10,
      goalValue: template['goalValue'] ?? 1,
      actionRoute: template['actionRoute'] ?? '/home',
      route: questRouteFromPath(template['actionRoute'] ?? '/home'),
      chainId: template['id'].toString().split('_').sublist(0, template['id'].toString().split('_').length -1).join('_'),
      chainStep: int.tryParse(template['id'].toString().split('_').last),
      chainLength: 3,
    );
    await ref.read(firestoreServiceProvider).upsertQuest(userId, newQuest);
    ref.read(analyticsLoggerProvider).logQuestEvent(userId: userId, event: 'quest_chain_next_added', data: {
      'fromQuestId': quest.id,'nextQuestId': newQuest.id,'chainId': newQuest.chainId,'chainStep': newQuest.chainStep,
    });
    onAdded?.call();
  }
}
