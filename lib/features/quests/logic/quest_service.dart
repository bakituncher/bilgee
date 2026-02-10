// lib/features/quests/logic/quest_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/quests/models/quest_model.dart';
import 'package:taktik/core/app_check/app_check_helper.dart';
import 'package:taktik/features/quests/logic/quest_session_state.dart';
import 'package:taktik/features/quests/logic/optimized_quests_provider.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';

final questServiceProvider = Provider<QuestService>((ref) {
  return QuestService(ref);
});
final questGenerationIssueProvider = StateProvider<bool>((_) => false);

class QuestService {
  final Ref _ref;
  QuestService(this._ref);

  bool _inProgress = false;

  /// AKILLI İSTEMCİ: Tarih kontrolünü istemcide yapar, sadece gerekirse sunucuyu çağırır.
  Future<List<Quest>> checkAndRefreshQuests(String userId) async {
    if (_inProgress) {
      return await _ref.read(firestoreServiceProvider).getDailyQuestsOnce(userId);
    }

    _inProgress = true;
    try {
      // 1. Önce mevcut görevleri oku (cache veya firestore'dan)
      List<Quest> currentQuests = [];
      try {
        currentQuests = await _ref.read(firestoreServiceProvider).getDailyQuestsOnce(userId);
      } catch (e) {
        currentQuests = [];
      }

      // 2. Kullanıcı verisini al (lastQuestRefreshDate kontrolü için)
      final user = _ref.read(userProfileProvider).value;
      if (user == null) return currentQuests;

      // 3. Tarih Kontrolü: Görevler bugüne mi ait?
      final now = DateTime.now();
      final lastRefresh = user.lastQuestRefreshDate?.toDate();

      bool isFresh = false;
      if (lastRefresh != null) {
        isFresh = lastRefresh.year == now.year &&
            lastRefresh.month == now.month &&
            lastRefresh.day == now.day;
      }

      // Eğer veri tazeyse ve liste boş değilse, sunucuyu rahatsız etme!
      if (isFresh && currentQuests.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[QuestService] Görevler zaten güncel, sunucu çağrısı atlandı');
        }
        return currentQuests;
      }

      // 4. Veri bayat veya yok: Sunucudan yenileme iste
      if (kDebugMode) {
        debugPrint('[QuestService] Görevler yenileniyor... (isFresh: $isFresh, questCount: ${currentQuests.length})');
      }

      try {
        final functions = _ref.read(functionsProvider);
        final callable = functions.httpsCallable('quests-regenerateDailyQuests');

        // callWithAppCheck wrapper kullanarak çağrı yap
        final result = await callWithAppCheck(callable);

        final data = result.data as Map<String, dynamic>?;

        if (data?['skipped'] != true) {
          _ref.read(sessionCompletedQuestsProvider.notifier).state = <String>{};
          if (kDebugMode) {
            debugPrint('[QuestService] Görevler yenilendi: ${data?['dailyCount']} görev');
          }
        }

        final refreshedQuests = await _ref.read(firestoreServiceProvider).getDailyQuestsOnce(userId);
        _ref.read(questGenerationIssueProvider.notifier).state = false;
        return refreshedQuests;

      } on FirebaseFunctionsException catch (e) {
        if (kDebugMode) {
          debugPrint('[QuestService] Fonksiyon hatası: ${e.message}');
        }
        _ref.read(questGenerationIssueProvider.notifier).state = true;
        return currentQuests;

      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[QuestService] Genel yenileme hatası: $e');
          debugPrint(st.toString());
        }
        _ref.read(questGenerationIssueProvider.notifier).state = true;
        return currentQuests;
      }
    } finally {
      _inProgress = false;
    }
  }

  Future<List<Quest>> refreshDailyQuestsForUser(UserModel user, {bool force = false}) async {
    if (_inProgress) {
      return await _ref.read(firestoreServiceProvider).getDailyQuestsOnce(user.id);
    }
    _inProgress = true;
    try {
      final today = DateTime.now();
      final lastRefresh = user.lastQuestRefreshDate?.toDate();

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

      if (!force && lastRefresh != null && lastRefresh.year == today.year && lastRefresh.month == today.month && lastRefresh.day == today.day && existingQuests.isNotEmpty) {
        return existingQuests;
      }

      try {
        final functions = _ref.read(functionsProvider);
        final callable = functions.httpsCallable('quests-regenerateDailyQuests');

        // callWithAppCheck wrapper kullanarak çağrı yap
        await callWithAppCheck(callable);

        final refreshed = await _ref.read(firestoreServiceProvider).getDailyQuestsOnce(user.id);
        _ref.read(sessionCompletedQuestsProvider.notifier).state = <String>{};
        _ref.read(questGenerationIssueProvider.notifier).state = false;
        return refreshed;

      } on FirebaseFunctionsException catch (e) {
        if (kDebugMode) {
          debugPrint('[QuestService] server generation failed: $e');
        }
        _ref.read(questGenerationIssueProvider.notifier).state = true;
        return existingQuests;
      } catch (e) {
        _ref.read(questGenerationIssueProvider.notifier).state = true;
        return existingQuests;
      }
    } finally {
      _inProgress = false;
    }
  }

  Future<bool> claimReward(String userId, String questId) async {
    try {
      final functions = _ref.read(functionsProvider);
      final callable = functions.httpsCallable('quests-claimQuestReward');

      // callWithAppCheck wrapper kullanarak çağrı yap
      await callWithAppCheck(callable, {'questId': questId});

      _ref.invalidate(optimizedQuestsProvider);
      return true;

    } on FirebaseFunctionsException catch (e) {

      if (kDebugMode) {
        debugPrint('Ödül alınırken hata: $e');
      }
      _ref.invalidate(optimizedQuestsProvider);
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('Ödül alınırken genel hata: $e');
      _ref.invalidate(optimizedQuestsProvider);
      return false;
    }
  }

  String? get currentUserId {
    try {
      return _ref.read(authControllerProvider).value?.uid;
    } catch (_) {
      return null;
    }
  }
}

final dailyQuestsProvider = FutureProvider.autoDispose<List<Quest>>((ref) async {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return [];
  final questService = ref.read(questServiceProvider);

  // LAZY LOADING
  final result = await questService.checkAndRefreshQuests(user.id).catchError((e) async {
    if (kDebugMode) debugPrint('[dailyQuestsProvider] hata: $e');
    return <Quest>[];
  });
  return result;
});