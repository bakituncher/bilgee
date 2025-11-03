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
import 'package:taktik/features/quests/logic/optimized_quests_provider.dart';

final questServiceProvider = Provider<QuestService>((ref) {
  return QuestService(ref);
});
final questGenerationIssueProvider = StateProvider<bool>((_) => false);

class QuestService {
  final Ref _ref;
  QuestService(this._ref);

  bool _inProgress = false;

  /// LAZY LOADING: Kullanıcı uygulamayı açtığında görevlerini kontrol eder.
  /// Eğer bugün için güncel değilse, backend'de otomatik yeniler.
  /// Bu yaklaşım sürdürülebilir ve maliyet-efektiftir.
  Future<List<Quest>> checkAndRefreshQuests(String userId) async {
    if (_inProgress) {
      return await _ref.read(firestoreServiceProvider).getDailyQuestsOnce(userId);
    }
    _inProgress = true;
    try {
      await ensureAppCheckTokenReady();
      final functions = _ref.read(functionsProvider);
      final callable = functions.httpsCallable('quests-checkAndRefreshQuests');

      final result = await callable.call();
      final data = result.data as Map<String, dynamic>;

      if (data['refreshed'] == true) {
        // Görevler yenilendi, session state'i temizle
        _ref.read(sessionCompletedQuestsProvider.notifier).state = <String>{};
        if (kDebugMode) {
          debugPrint('[QuestService] Görevler yenilendi: ${data['questCount']} görev');
        }
      }

      // Her iki durumda da (yenilendi ya da zaten güncel) güncel görevleri döndür
      final quests = await _ref.read(firestoreServiceProvider).getDailyQuestsOnce(userId);
      _ref.read(questGenerationIssueProvider.notifier).state = false;
      return quests;

    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[QuestService] checkAndRefreshQuests failed: $e');
        debugPrint(st.toString());
      }
      _ref.read(questGenerationIssueProvider.notifier).state = true;
      // Hata durumunda mevcut görevleri döndür
      try {
        return await _ref.read(firestoreServiceProvider).getDailyQuestsOnce(userId);
      } catch (_) {
        return [];
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
    try {
      final functions = _ref.read(functionsProvider);
      final callable = functions.httpsCallable('quests-claimQuestReward');

      await ensureAppCheckTokenReady(); // App Check

      await callable.call({'questId': questId});

      // Başarılı olduğunda, puanın ve görev durumunun
      // UI'a yansıması için provider'ları yenile.
      _ref.invalidate(userProfileProvider);
      _ref.invalidate(optimizedQuestsProvider);

      return true;

    } catch (e) {
      if (kDebugMode) {
        debugPrint('Ödül alınırken hata: $e');
      }
      // Hata durumunda bile UI'ın güncel veriyi çekmesi için yenile
      _ref.invalidate(optimizedQuestsProvider);
      return false;
    }
  }
}

final dailyQuestsProvider = FutureProvider.autoDispose<List<Quest>>((ref) async {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return [];
  final questService = ref.read(questServiceProvider);

  // LAZY LOADING: Kullanıcı uygulamayı açtığında görevleri kontrol et
  final result = await questService.checkAndRefreshQuests(user.id).catchError((e) async {
    if (kDebugMode) debugPrint('[dailyQuestsProvider] hata: $e');
    return <Quest>[];
  });
  return result;
});
