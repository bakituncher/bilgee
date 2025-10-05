// lib/features/quests/logic/quest_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/quests/models/quest_model.dart';
import 'package:flutter/foundation.dart';
import 'package:taktik/core/app_check/app_check_helper.dart';
import 'package:taktik/features/quests/logic/quest_session_state.dart';

final questServiceProvider = Provider<QuestService>((ref) {
  return QuestService(ref);
});
final questGenerationIssueProvider = StateProvider<bool>((_) => false);

class QuestService {
  final Ref _ref;
  QuestService(this._ref);

  bool _inProgress = false;

  Future<List<Quest>> refreshDailyQuestsForUser(UserModel user, {bool force = false}) async {
    if (_inProgress) {
      return await _ref.read(firestoreServiceProvider).getDailyQuestsOnce(user.id);
    }
    _inProgress = true;
    try {
      final today = DateTime.now();
      final lastRefresh = user.lastQuestRefreshDate?.toDate();

      // Mevcut görevleri oku
      List<Quest> existingQuests = [];
      try {
        existingQuests = await _ref.read(firestoreServiceProvider).getDailyQuestsOnce(user.id);
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          if (kDebugMode) debugPrint('[QuestService] daily_quests permission-denied');
          _ref.read(questGenerationIssueProvider.notifier).state = true;
          return [];
        }
        rethrow;
      }

      // Bugün zaten üretilmiş ve force değilse direkt dön
      if (!force && lastRefresh != null && lastRefresh.year == today.year && lastRefresh.month == today.month && lastRefresh.day == today.day && existingQuests.isNotEmpty) {
        return existingQuests;
      }

      // Sunucu tarafı yeniden üretim (callable function)
      try {
        // App Check tokenının hazır olduğundan emin ol
        await ensureAppCheckTokenReady();
        final functions = _ref.read(functionsProvider);
        final callable = functions.httpsCallable('quests-regenerateDailyQuests');
        await callable.call(); // No more parameters needed
        // Üretim sonrası tekrar oku
        final refreshed = await _ref.read(firestoreServiceProvider).getDailyQuestsOnce(user.id);

        // ÖNEMLİ: Günlük görevler yenilendiğinde session state'i temizle
        _ref.read(sessionCompletedQuestsProvider.notifier).state = <String>{};

        _ref.read(questGenerationIssueProvider.notifier).state = false;
        return refreshed;
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[QuestService] server generation failed: $e');
          debugPrint(st.toString());
        }
        // Sunucu başarısızsa mevcutu döner (UX bozulmasın)
        _ref.read(questGenerationIssueProvider.notifier).state = true;
        return existingQuests;
      }
    } finally {
      _inProgress = false;
    }
  }

  Future<bool> claimReward(String userId, String questId) async {
    final firestore = _ref.read(firestoreProvider);
    // DÜZELTME: Doğru stats doküman yolu kullanıldı.
    final userStatsRef = firestore.collection('users').doc(userId).collection('state').doc('stats');
    final questRef = firestore.collection('users').doc(userId).collection('daily_quests').doc(questId);

    try {
      await firestore.runTransaction((transaction) async {
        final questDoc = await transaction.get(questRef);

        if (!questDoc.exists) {
          throw Exception("Görev bulunamadı: $questId");
        }
        final quest = Quest.fromMap(questDoc.data()!, questDoc.id);

        if (!quest.isCompleted) {
          throw Exception("Görev tamamlanmamış.");
        }
        if (quest.rewardClaimed) {
          // Zaten alınmışsa işlem yapma, başarılı say.
          return;
        }

        // DÜZELTME: 'bp' yerine 'engagementScore' kullanıldı ve FieldValue.increment ile atomik artış sağlandı.
        // Bu sayede userStats dokümanını okumaya gerek kalmadı, bu da işlemi basitleştirir.
        transaction.update(userStatsRef, {
          'engagementScore': FieldValue.increment(quest.reward),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // DÜZELTME: Ödülün alındığını ve ne kadar alındığını kaydet.
        transaction.update(questRef, {
          'rewardClaimed': true,
          'rewardClaimedAt': FieldValue.serverTimestamp(),
          'actualReward': quest.reward,
        });
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Ödül alınırken hata: $e');
      }
      return false;
    }
  }
}

final dailyQuestsProvider = FutureProvider.autoDispose<List<Quest>>((ref) async {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return [];
  final questService = ref.read(questServiceProvider);
  final result = await questService.refreshDailyQuestsForUser(user).catchError((e) async {
    if (kDebugMode) debugPrint('[dailyQuestsProvider] hata: $e');
    return <Quest>[];
  });
  return result;
});
