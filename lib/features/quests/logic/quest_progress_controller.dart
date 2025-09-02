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

    // Yalnızca tek hedef seç: aynı kategoride en yakın tamamlanacak olan
    final eligible = activeQuests.where((q) => q.category == category && !q.isCompleted && !sessionCompletedIds.contains(q.id)).toList();
    if (eligible.isEmpty) { return; }

    Quest? target;
    int? targetNewProgress;

    for (final quest in eligible) {
      int newProgress = quest.currentProgress;
      switch (quest.progressType) {
        case QuestProgressType.increment:
          newProgress += amount; break;
        case QuestProgressType.set_to_value:
          // Sadece tri-sync görevinde gün içi ziyaret sayısına set edilir.
          if (quest.id == 'daily_con_01_tri_sync') {
            final visits = await firestoreSvc.getVisitsForMonth(user.id, DateTime.now());
            final now = DateTime.now();
            final todays = visits.where((ts){ final d=ts.toDate(); return d.year==now.year && d.month==now.month && d.day==now.day;}).length;
            newProgress = todays;
          } else {
            // Diğer set_to_value görevler için güvenli artış uygula
            newProgress = quest.currentProgress + amount;
          }
          break;
      }
      // Aday seçimi: kalan hedefe en yakın olan (en küçük kalan)
      final remaining = (quest.goalValue - newProgress).clamp(-1, quest.goalValue);
      if (target == null) { target = quest; targetNewProgress = newProgress; }
      else {
        final currentRemaining = (target!.goalValue - (targetNewProgress ?? target!.currentProgress));
        if (remaining < currentRemaining) { target = quest; targetNewProgress = newProgress; }
      }
    }

    if (target == null) return;
    final quest = target!;
    final newProgress = (targetNewProgress ?? quest.currentProgress);
    final willComplete = newProgress >= quest.goalValue;

    try {
      // Önce ilerlemeyi yaz (hedefi aşsa bile clamp'leriz)
      await firestoreSvc.updateQuestFields(user.id, quest.id, {
        'currentProgress': newProgress.clamp(quest.currentProgress, quest.goalValue),
      });
      if (willComplete) {
        await ensureAppCheckTokenReady();
        await functions.httpsCallable('completeQuest').call({'questId': quest.id});
        ref.read(sessionCompletedQuestsProvider.notifier).update((prev)=>{...prev, quest.id});
        ref.read(questCompletionProvider.notifier).show(quest.copyWith(currentProgress: quest.goalValue, isCompleted: true, completionDate: Timestamp.now()));
        HapticFeedback.mediumImpact();
        ref.read(analyticsLoggerProvider).logQuestEvent(userId: user.id, event: 'quest_completed', data: {
          'questId': quest.id,'category': quest.category.name,'reward': quest.reward,'difficulty': quest.difficulty.name,
        });
      } else {
        ref.read(analyticsLoggerProvider).logQuestEvent(userId: user.id, event: 'quest_progress', data: {
          'questId': quest.id,'progress': newProgress,'goal': quest.goalValue,
        });
      }
    } catch (e) {
      // Sunucu reddederse sadece ilerlemeyi güvenli şekilde güncelle, tamamlandı işaretleme yok
      await firestoreSvc.updateQuestFields(user.id, quest.id, {
        'currentProgress': newProgress.clamp(quest.currentProgress, quest.goalValue),
      });
    }

    // Zincir/bonus mantığı server tamamlama sonrası ayrı çalışır
    ref.invalidate(dailyQuestsProvider);
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
    try {
      await firestoreSvc.updateQuestFields(user.id, quest.id, {'currentProgress': newProgress.clamp(quest.currentProgress, quest.goalValue)});
      if (newProgress >= quest.goalValue) {
        await ensureAppCheckTokenReady();
        await functions.httpsCallable('completeQuest').call({'questId': quest.id});
        ref.read(sessionCompletedQuestsProvider.notifier).update((prev)=>{...prev, quest!.id});
        ref.read(questCompletionProvider.notifier).show(quest.copyWith(currentProgress: quest.goalValue, isCompleted: true, completionDate: Timestamp.now()));
        HapticFeedback.mediumImpact();
        ref.read(analyticsLoggerProvider).logQuestEvent(userId: user.id, event: 'quest_completed', data: {'questId': quest.id,'category': quest.category.name,'reward': quest.reward,'difficulty': quest.difficulty.name});
      } else {
        ref.read(analyticsLoggerProvider).logQuestEvent(userId: user.id, event: 'quest_progress', data: {'questId': quest.id,'progress': newProgress,'goal': quest.goalValue});
      }
    } catch (_) {
      // Tamamlama başarısızsa sadece ilerleme güncelle (tamamlandı işaretleme yok)
      await firestoreSvc.updateQuestFields(user.id, quest.id, {'currentProgress': newProgress.clamp(quest.currentProgress, quest.goalValue)});
    }
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

    // Sadece ilgili route eşleşen bir görev hedefle (ilk uygun)
    final quest = activeQuests.firstWhere(
      (q) => q.category == QuestCategory.engagement && q.route == route && !q.isCompleted && !sessionCompletedIds.contains(q.id),
      orElse: () => null as Quest,
    );
    if (quest == null) return;

    final newProgress = quest.currentProgress + amount;
    try {
      await firestoreSvc.updateQuestFields(user.id, quest.id, {'currentProgress': newProgress.clamp(quest.currentProgress, quest.goalValue)});
      if (newProgress >= quest.goalValue) {
        await ensureAppCheckTokenReady();
        await functions.httpsCallable('completeQuest').call({'questId': quest.id});
        ref.read(sessionCompletedQuestsProvider.notifier).update((prev)=>{...prev, quest.id});
        ref.read(questCompletionProvider.notifier).show(quest.copyWith(currentProgress: quest.goalValue, isCompleted: true, completionDate: Timestamp.now()));
        HapticFeedback.mediumImpact();
        ref.read(analyticsLoggerProvider).logQuestEvent(userId: user.id, event: 'quest_completed', data: {'questId': quest.id,'category': quest.category.name,'reward': quest.reward,'difficulty': quest.difficulty.name});
      } else {
        ref.read(analyticsLoggerProvider).logQuestEvent(userId: user.id, event: 'quest_progress', data: {'questId': quest.id,'progress': newProgress,'goal': quest.goalValue});
      }
    } catch (_) {
      await firestoreSvc.updateQuestFields(user.id, quest.id, {'currentProgress': newProgress.clamp(quest.currentProgress, quest.goalValue)});
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

    // Kaynak eşleşmeyen veya alt-tip tutmayanları ele; tek uygun görevi hedefle
    final quest = activeQuests.firstWhere(
      (q) {
        if (q.category != QuestCategory.practice || q.isCompleted || sessionCompletedIds.contains(q.id)) return false;
        final isWorkshopQuest = q.id.startsWith('chain_workshop_') || q.actionRoute.contains('weakness-workshop') || q.tags.contains('workshop');
        if (source == PracticeSource.general && isWorkshopQuest) return false;
        if (source == PracticeSource.workshop && !isWorkshopQuest) return false;
        if (q.tags.contains('paragraph') && subtype != 'paragraph') return false;
        if (q.tags.contains('problem') && subtype != 'problem') return false;
        return true;
      },
      orElse: () => null as Quest,
    );
    if (quest == null) return;

    final newProgress = quest.currentProgress + amount;
    try {
      await firestoreSvc.updateQuestFields(user.id, quest.id, {'currentProgress': newProgress.clamp(quest.currentProgress, quest.goalValue)});
      if (newProgress >= quest.goalValue) {
        await ensureAppCheckTokenReady();
        await functions.httpsCallable('completeQuest').call({'questId': quest.id});
        ref.read(sessionCompletedQuestsProvider.notifier).update((prev)=>{...prev, quest.id});
        ref.read(questCompletionProvider.notifier).show(quest.copyWith(currentProgress: quest.goalValue, isCompleted: true, completionDate: Timestamp.now()));
        HapticFeedback.mediumImpact();
        ref.read(analyticsLoggerProvider).logQuestEvent(userId: user.id, event: 'quest_completed', data: {'questId': quest.id,'category': quest.category.name,'reward': quest.reward,'difficulty': quest.difficulty.name});
      } else {
        ref.read(analyticsLoggerProvider).logQuestEvent(userId: user.id, event: 'quest_progress', data: {'questId': quest.id,'progress': newProgress,'goal': quest.goalValue});
      }
    } catch (_) {
      await firestoreSvc.updateQuestFields(user.id, quest.id, {'currentProgress': newProgress.clamp(quest.currentProgress, quest.goalValue)});
    }
    ref.invalidate(dailyQuestsProvider);
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
