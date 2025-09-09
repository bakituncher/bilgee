// lib/features/quests/logic/quest_system_health_check.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/quests/logic/optimized_quests_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Görev sistemi sağlık kontrolü ve onarım servisi
class QuestSystemHealthCheck {
  final Ref _ref;
  QuestSystemHealthCheck(this._ref);

  /// Kullanıcının puan durumunu kontrol et ve onar
  Future<Map<String, dynamic>> checkAndRepairUserPoints(String userId) async {
    try {
      final firestoreService = _ref.read(firestoreServiceProvider);
      final report = <String, dynamic>{};

      // 1. Kullanıcı dokümanını kontrol et
      final userDoc = await firestoreService.usersCollection.doc(userId).get();
      if (!userDoc.exists) {
        return {'error': 'Kullanıcı bulunamadı'};
      }

      final userData = userDoc.data()!;
      final currentBP = userData['bilgePoints'] ?? 0;
      final totalEarnedBP = userData['totalEarnedBP'] ?? 0;

      report['current_bp'] = currentBP;
      report['total_earned_bp'] = totalEarnedBP;

      // 2. Tamamlanan görevleri kontrol et
      final completedQuests = await firestoreService
          .questsCollection(userId)
          .where('isCompleted', isEqualTo: true)
          .where('rewardClaimed', isEqualTo: true)
          .get();

      // 3. Reward claims koleksiyonunu kontrol et
      final rewardClaims = await firestoreService.usersCollection
          .doc(userId)
          .collection('reward_claims')
          .get();

      final claimedRewards = rewardClaims.docs
          .map((doc) => (doc.data()['actualReward'] as num?)?.toInt() ?? 0)
          .fold(0, (sum, reward) => sum + reward);

      report['completed_quests'] = completedQuests.size;
      report['claimed_rewards_total'] = claimedRewards;
      report['discrepancy'] = claimedRewards - currentBP;

      // 4. Eğer tutarsızlık varsa onar
      if (claimedRewards != currentBP && claimedRewards > 0) {
        await _repairUserPoints(userId, claimedRewards, report);
      }

      // 5. Eksik alanları kontrol et ve ekle
      await _ensureUserFieldsExist(userId, userData, report);

      return report;

    } catch (e) {
      debugPrint('[HealthCheck] HATA: $e');
      return {'error': e.toString()};
    }
  }

  /// Kullanıcı puanlarını onar
  Future<void> _repairUserPoints(String userId, int correctTotal, Map<String, dynamic> report) async {
    try {
      final firestoreService = _ref.read(firestoreServiceProvider);

      await firestoreService.usersCollection.doc(userId).update({
        'bilgePoints': correctTotal,
        'totalEarnedBP': correctTotal,
        'pointsRepairedAt': FieldValue.serverTimestamp(),
      });

      report['repair_performed'] = true;
      report['new_bp'] = correctTotal;

      debugPrint('[HealthCheck] ✅ Puanlar onarıldı: $correctTotal BP');

    } catch (e) {
      report['repair_error'] = e.toString();
      debugPrint('[HealthCheck] ❌ Onarım hatası: $e');
    }
  }

  /// Eksik kullanıcı alanlarını ekle
  Future<void> _ensureUserFieldsExist(String userId, Map<String, dynamic> userData, Map<String, dynamic> report) async {
    try {
      final firestoreService = _ref.read(firestoreServiceProvider);
      final updates = <String, dynamic>{};

      // Kritik alanların varlığını kontrol et
      final requiredFields = {
        'bilgePoints': 0,
        'totalEarnedBP': 0,
        'totalCompletedQuests': 0,
        'currentQuestStreak': 0,
        'usedFeatures': <String, bool>{},
        'hasCreatedStrategicPlan': false,
        'hasUsedPomodoro': false,
        'hasSubmittedTest': false,
        'completedWorkshopCount': 0,
      };

      for (final entry in requiredFields.entries) {
        if (!userData.containsKey(entry.key)) {
          updates[entry.key] = entry.value;
        }
      }

      if (updates.isNotEmpty) {
        await firestoreService.usersCollection.doc(userId).update(updates);
        report['added_fields'] = updates.keys.toList();
        debugPrint('[HealthCheck] ✅ Eksik alanlar eklendi: ${updates.keys}');
      }

    } catch (e) {
      report['field_addition_error'] = e.toString();
      debugPrint('[HealthCheck] ❌ Alan ekleme hatası: $e');
    }
  }

  /// Görev sisteminin genel sağlığını kontrol et
  Future<Map<String, dynamic>> systemHealthReport(String userId) async {
    final report = <String, dynamic>{};

    try {
      final firestoreService = _ref.read(firestoreServiceProvider);

      // 1. Aktif görevleri kontrol et
      final activeQuests = await firestoreService
          .questsCollection(userId)
          .where('isCompleted', isEqualTo: false)
          .get();

      // 2. Bugün tamamlanan görevleri kontrol et
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayQuests = await firestoreService
          .questsCollection(userId)
          .where('isCompleted', isEqualTo: true)
          .where('completionDate', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .get();

      // 3. Provider durumlarını kontrol et
      final userProvider = _ref.read(userProfileProvider);
      final questsProvider = _ref.read(optimizedQuestsProvider);

      report.addAll({
        'active_quests_count': activeQuests.size,
        'today_completed_count': todayQuests.size,
        'user_provider_loaded': userProvider.hasValue,
        'quests_provider_loaded': questsProvider.isLoaded,
        'system_timestamp': DateTime.now().toIso8601String(),
      });

      return report;

    } catch (e) {
      report['system_health_error'] = e.toString();
      return report;
    }
  }
}

/// Provider
final questSystemHealthCheckProvider = Provider<QuestSystemHealthCheck>((ref) {
  return QuestSystemHealthCheck(ref);
});
