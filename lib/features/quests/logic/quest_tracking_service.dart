// lib/features/quests/logic/quest_tracking_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'package:bilge_ai/features/quests/logic/quest_completion_notifier.dart';
import 'package:bilge_ai/features/quests/logic/quest_session_state.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

/// Tüm görev tiplerinin ilerlemesini kaliteli şekilde takip eden servis
class QuestTrackingService {
  final Ref _ref;
  QuestTrackingService(this._ref);

  /// Ana görev güncelleme metodu - tüm görev tipleri için
  Future<QuestUpdateResult> updateQuestProgress({
    required String questId,
    required int amount,
    QuestProgressType? progressType,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final user = _ref.read(userProfileProvider).value;
      if (user == null) {
        return QuestUpdateResult.error('Kullanıcı bulunamadı');
      }

      final firestoreService = _ref.read(firestoreServiceProvider);

      // Mevcut görev bilgisini al
      final questDoc = await firestoreService.questsCollection(user.id).doc(questId).get();
      if (!questDoc.exists) {
        return QuestUpdateResult.error('Görev bulunamadı');
      }

      final quest = Quest.fromMap(questDoc.data()!, questId);

      // Eğer görev zaten tamamlanmışsa güncelleme yapma
      if (quest.isCompleted) {
        return QuestUpdateResult.alreadyCompleted(quest);
      }

      // Session içinde zaten tamamlanmış görevleri kontrol et
      final sessionCompleted = _ref.read(sessionCompletedQuestsProvider);
      if (sessionCompleted.contains(questId)) {
        return QuestUpdateResult.sessionCompleted(quest);
      }

      // İlerleme hesaplama
      final newProgress = _calculateNewProgress(quest, amount, progressType);
      final isNowCompleted = newProgress >= quest.goalValue;

      // Güncelleme verileri hazırla
      final updateData = {
        'currentProgress': newProgress,
        'updatedAt': FieldValue.serverTimestamp(), // was lastUpdated - rules ile uyumlu
        if (isNowCompleted) ...{
          'isCompleted': true,
          'completionDate': FieldValue.serverTimestamp(),
        },
        ...?additionalData,
      };

      // Firestore güncellemesi
      await firestoreService.questsCollection(user.id).doc(questId).update(updateData);

      // Güncellenmiş görev nesnesini oluştur
      final updatedQuest = quest.copyWith(
        currentProgress: newProgress,
        isCompleted: isNowCompleted,
        completionDate: isNowCompleted ? Timestamp.now() : null,
      );

      // Tamamlanma işlemleri
      if (isNowCompleted) {
        await _handleQuestCompletion(updatedQuest);
      }

      // Analytics kaydı
      _logQuestProgress(updatedQuest, amount, isNowCompleted);

      return QuestUpdateResult.success(updatedQuest, isNowCompleted);

    } catch (e) {
      debugPrint('[QuestTracking] Güncelleme hatası: $e');
      return QuestUpdateResult.error('Güncelleme başarısız: $e');
    }
  }

  /// Kategori bazlı toplu güncelleme
  Future<List<QuestUpdateResult>> updateQuestsByCategory({
    required QuestCategory category,
    required int amount,
    QuestRoute? specificRoute,
    Map<String, dynamic>? filters,
  }) async {
    try {
      final user = _ref.read(userProfileProvider).value;
      if (user == null) return [];

      final firestoreService = _ref.read(firestoreServiceProvider);

      // İlgili görevleri getir
      final quests = await _getQuestsByCategory(category, specificRoute, filters);
      final results = <QuestUpdateResult>[];

      for (final quest in quests) {
        final result = await updateQuestProgress(
          questId: quest.id,
          amount: amount,
        );
        results.add(result);

        // İlk tamamlanan görev için dur (aynı kategoride birden fazla tamamlanmasın)
        if (result.isCompleted) break;
      }

      return results;

    } catch (e) {
      debugPrint('[QuestTracking] Kategori güncellemesi hatası: $e');
      return [];
    }
  }

  /// Görev tamamlanma işlemleri
  Future<void> _handleQuestCompletion(Quest completedQuest) async {
    try {
      // Session state güncelle
      final currentCompleted = _ref.read(sessionCompletedQuestsProvider);
      _ref.read(sessionCompletedQuestsProvider.notifier).state = {
        ...currentCompleted,
        completedQuest.id,
      };

      // Completion notifier'ı tetikle
      _ref.read(questCompletionProvider.notifier).show(completedQuest);

      // Zincir görevler için sonraki görevi aktifleştir
      if (completedQuest.chainId != null) {
        await _activateNextChainQuest(completedQuest);
      }

      // Haftalık/aylık görevlerin özel işlemleri
      await _handleSpecialQuestTypes(completedQuest);

      debugPrint('[QuestTracking] Görev tamamlandı: ${completedQuest.title}');

    } catch (e) {
      debugPrint('[QuestTracking] Tamamlama işlemi hatası: $e');
    }
  }

  /// Zincir görevler için sonraki aktivasyon
  Future<void> _activateNextChainQuest(Quest completedQuest) async {
    if (completedQuest.chainStep == null || completedQuest.chainLength == null) return;

    final nextStep = completedQuest.chainStep! + 1;
    if (nextStep > completedQuest.chainLength!) return;

    final user = _ref.read(userProfileProvider).value;
    if (user == null) return;

    try {
      final firestoreService = _ref.read(firestoreServiceProvider);
      final nextQuestId = '${completedQuest.chainId}_$nextStep';

      // Sonraki görevin var olup olmadığını kontrol et
      final nextQuestDoc = await firestoreService.questsCollection(user.id).doc(nextQuestId).get();

      if (nextQuestDoc.exists) {
        // Görev varsa aktifleştir (isActive = true)
        await firestoreService.questsCollection(user.id).doc(nextQuestId).update({
          'isActive': true,
          'activatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('[QuestTracking] Zincir görev aktifleştirildi: $nextQuestId');
      }

    } catch (e) {
      debugPrint('[QuestTracking] Zincir aktivasyon hatası: $e');
    }
  }

  /// Özel görev tiplerinin işlemleri
  Future<void> _handleSpecialQuestTypes(Quest quest) async {
    switch (quest.type) {
      case QuestType.weekly:
        await _handleWeeklyQuestCompletion(quest);
        break;
      case QuestType.monthly:
        await _handleMonthlyQuestCompletion(quest);
        break;
      case QuestType.achievement:
        await _handleAchievementCompletion(quest);
        break;
      default:
        break;
    }
  }

  /// Haftalık görev tamamlama
  Future<void> _handleWeeklyQuestCompletion(Quest quest) async {
    // Haftalık streak kontrolü ve bonus hesaplama
    // İleride implement edilecek
  }

  /// Aylık görev tamamlama
  Future<void> _handleMonthlyQuestCompletion(Quest quest) async {
    // Aylık başarım ve özel ödül sistemi
    // İleride implement edilecek
  }

  /// Başarım tamamlama
  Future<void> _handleAchievementCompletion(Quest quest) async {
    // Özel başarım rozeti ve sosyal paylaşım
    // İleride implement edilecek
  }

  /// İlerleme hesaplama
  int _calculateNewProgress(Quest quest, int amount, QuestProgressType? progressType) {
    final type = progressType ?? quest.progressType;

    switch (type) {
      case QuestProgressType.increment:
        return quest.currentProgress + amount;
      case QuestProgressType.set_to_value:
        return amount;
    }
  }

  /// Kategori bazlı görev getirme
  Future<List<Quest>> _getQuestsByCategory(
    QuestCategory category,
    QuestRoute? specificRoute,
    Map<String, dynamic>? filters,
  ) async {
    final user = _ref.read(userProfileProvider).value;
    if (user == null) return [];

    final firestoreService = _ref.read(firestoreServiceProvider);
    final sessionCompleted = _ref.read(sessionCompletedQuestsProvider);

    try {
      final querySnapshot = await firestoreService.questsCollection(user.id)
          .where('category', isEqualTo: category.name)
          .where('isCompleted', isEqualTo: false)
          .get();

      final quests = querySnapshot.docs
          .map((doc) => Quest.fromMap(doc.data(), doc.id))
          .where((quest) => !sessionCompleted.contains(quest.id))
          .toList();

      // Route filtresi
      if (specificRoute != null) {
        return quests.where((q) => q.route == specificRoute).toList();
      }

      // Diğer filtreler
      if (filters != null) {
        return quests.where((quest) => _matchesFilters(quest, filters)).toList();
      }

      return quests;

    } catch (e) {
      debugPrint('[QuestTracking] Kategori sorgusu hatası: $e');
      return [];
    }
  }

  /// Filtre eşleştirme
  bool _matchesFilters(Quest quest, Map<String, dynamic> filters) {
    for (final entry in filters.entries) {
      switch (entry.key) {
        case 'difficulty':
          if (quest.difficulty.name != entry.value) return false;
          break;
        case 'tags':
          final requiredTags = entry.value as List<String>;
          if (!requiredTags.any((tag) => quest.tags.contains(tag))) return false;
          break;
        case 'type':
          if (quest.type.name != entry.value) return false;
          break;
      }
    }
    return true;
  }

  /// Analytics loglama
  void _logQuestProgress(Quest quest, int amount, bool completed) {
    // Analytics servisine log gönder
    final eventData = {
      'quest_id': quest.id,
      'quest_type': quest.type.name,
      'category': quest.category.name,
      'progress_amount': amount,
      'new_progress': quest.currentProgress,
      'goal_value': quest.goalValue,
      'completed': completed,
      'route': quest.route.name,
    };

    // Analytics provider'ı kullan
    // _ref.read(analyticsServiceProvider).logEvent('quest_progress', eventData);
  }
}

/// Görev güncelleme sonucu
class QuestUpdateResult {
  final Quest? quest;
  final bool isCompleted;
  final bool isSuccess;
  final String? errorMessage;
  final QuestUpdateStatus status;

  const QuestUpdateResult._({
    this.quest,
    this.isCompleted = false,
    this.isSuccess = false,
    this.errorMessage,
    required this.status,
  });

  factory QuestUpdateResult.success(Quest quest, bool completed) {
    return QuestUpdateResult._(
      quest: quest,
      isCompleted: completed,
      isSuccess: true,
      status: completed ? QuestUpdateStatus.completed : QuestUpdateStatus.updated,
    );
  }

  factory QuestUpdateResult.error(String message) {
    return QuestUpdateResult._(
      errorMessage: message,
      status: QuestUpdateStatus.error,
    );
  }

  factory QuestUpdateResult.alreadyCompleted(Quest quest) {
    return QuestUpdateResult._(
      quest: quest,
      isCompleted: true,
      status: QuestUpdateStatus.alreadyCompleted,
    );
  }

  factory QuestUpdateResult.sessionCompleted(Quest quest) {
    return QuestUpdateResult._(
      quest: quest,
      status: QuestUpdateStatus.sessionCompleted,
    );
  }
}

enum QuestUpdateStatus {
  updated,
  completed,
  alreadyCompleted,
  sessionCompleted,
  error,
}

/// Extension methods for Quest model
extension QuestExtensions on Quest {
  Quest copyWith({
    String? id,
    String? title,
    String? description,
    QuestType? type,
    QuestCategory? category,
    QuestProgressType? progressType,
    int? reward,
    int? goalValue,
    int? currentProgress,
    bool? isCompleted,
    String? actionRoute,
    Timestamp? completionDate,
    List<String>? tags,
    QuestDifficulty? difficulty,
    int? estimatedMinutes,
    List<String>? prerequisiteIds,
    List<String>? conceptTags,
    String? learningObjectiveId,
    String? chainId,
    int? chainStep,
    int? chainLength,
    QuestRoute? route,
    bool? rewardClaimed,
    String? weekKey,
    String? monthKey,
  }) {
    return Quest(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      category: category ?? this.category,
      progressType: progressType ?? this.progressType,
      reward: reward ?? this.reward,
      goalValue: goalValue ?? this.goalValue,
      currentProgress: currentProgress ?? this.currentProgress,
      isCompleted: isCompleted ?? this.isCompleted,
      actionRoute: actionRoute ?? this.actionRoute,
      completionDate: completionDate ?? this.completionDate,
      tags: tags ?? this.tags,
      difficulty: difficulty ?? this.difficulty,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      prerequisiteIds: prerequisiteIds ?? this.prerequisiteIds,
      conceptTags: conceptTags ?? this.conceptTags,
      learningObjectiveId: learningObjectiveId ?? this.learningObjectiveId,
      chainId: chainId ?? this.chainId,
      chainStep: chainStep ?? this.chainStep,
      chainLength: chainLength ?? this.chainLength,
      route: route ?? this.route,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
      weekKey: weekKey ?? this.weekKey,
      monthKey: monthKey ?? this.monthKey,
    );
  }

  /// Görev tamamlanma yüzdesini hesapla
  double get completionPercentage {
    if (goalValue == 0) return 0.0;
    return (currentProgress / goalValue).clamp(0.0, 1.0);
  }

  /// Görevin kalan süresini hesapla
  Duration? get timeRemaining {
    if (estimatedMinutes == null) return null;
    final remainingProgress = goalValue - currentProgress;
    final progressRatio = currentProgress / goalValue;
    if (progressRatio == 0) return Duration(minutes: estimatedMinutes!);

    final remainingMinutes = (estimatedMinutes! * (remainingProgress / goalValue)).ceil();
    return Duration(minutes: remainingMinutes);
  }

  /// Dinamik ödül hesaplama
  int calculateDynamicReward({int? userLevel, int? streak}) {
    var baseReward = reward;

    // Zorluk çarpanı
    switch (difficulty) {
      case QuestDifficulty.trivial:
        baseReward = (baseReward * 0.8).round();
        break;
      case QuestDifficulty.medium:
        baseReward = (baseReward * 1.3).round();
        break;
      case QuestDifficulty.hard:
        baseReward = (baseReward * 1.6).round();
        break;
      case QuestDifficulty.epic:
        baseReward = (baseReward * 2.0).round();
        break;
      default:
        break;
    }

    // Streak bonusu
    if (streak != null && streak > 1) {
      final streakMultiplier = 1 + (streak * 0.1).clamp(0, 0.5);
      baseReward = (baseReward * streakMultiplier).round();
    }

    return baseReward;
  }
}

/// Provider
final questTrackingServiceProvider = Provider<QuestTrackingService>((ref) {
  return QuestTrackingService(ref);
});
