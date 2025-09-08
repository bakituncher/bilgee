// lib/features/quests/logic/quest_completion_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilge_ai/features/quests/logic/quest_service.dart';
import 'package:flutter/foundation.dart';

/// Geliştirilmiş Quest Completion Notifier
/// Tüm görev tiplerini destekler ve kaliteli takip sağlar
class QuestCompletionNotifier extends StateNotifier<QuestCompletionState> {
  QuestCompletionNotifier() : super(const QuestCompletionState.empty());

  /// Görev tamamlama bildirimi göster
  void show(Quest completedQuest) {
    if (state.completedQuest?.id == completedQuest.id) {
      return; // Aynı görev zaten gösteriliyorsa tekrar gösterme
    }

    if (state.isVisible) {
      // Mevcut bildirim varsa kuyruğa ekle
      _queueCompletion(completedQuest);
      return;
    }

    _showCompletion(completedQuest);
  }

  /// Çoklu görev tamamlama (zincirleme veya aynı anda)
  void showMultiple(List<Quest> completedQuests) {
    if (completedQuests.isEmpty) return;

    // İlk görev için immediate show
    _showCompletion(completedQuests.first);

    // Diğerleri için kuyruğa ekle
    for (int i = 1; i < completedQuests.length; i++) {
      _queueCompletion(completedQuests[i]);
    }
  }

  /// Ödül toplama - geliştirilmiş
  Future<void> claimReward(Quest quest, Ref ref) async {
    try {
      final firestoreSvc = ref.read(firestoreServiceProvider);
      final user = ref.read(userProfileProvider).value;

      if (user == null) {
        debugPrint('[QuestCompletion] Kullanıcı bulunamadı');
        return;
      }

      // Basit ödül hesaplama (user.level ve currentStreak yoksa)
      final dynamicReward = quest.calculateDynamicReward();

      // Firestore güncellemeleri paralel olarak yap
      await Future.wait([
        // BP güncelleme
        firestoreSvc.usersCollection.doc(user.id).update({
          'bilgePoints': FieldValue.increment(dynamicReward),
        }),
        // Görev reward claimed flag güncelleme
        firestoreSvc.updateQuestFields(user.id, quest.id, {
          'rewardClaimed': true,
          'rewardClaimedAt': FieldValue.serverTimestamp(),
          'actualReward': dynamicReward,
        }),
      ]);

      debugPrint('[QuestCompletion] Ödül toplandı: $dynamicReward BP (base: ${quest.reward})');

      // State güncelle
      state = state.copyWith(
        rewardClaimed: true,
        actualReward: dynamicReward,
      );

      // Providers yenile
      ref.invalidate(dailyQuestsProvider);
      ref.invalidate(userProfileProvider);

      // Özel görev tipleri için ek işlemler
      await _handleSpecialRewardTypes(quest, ref, dynamicReward);

      // 2 saniye sonra otomatik clear
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) clear();
      });

    } catch (e) {
      debugPrint('[QuestCompletion] Ödül toplama hatası: $e');
      // Hata durumunda da clear et
      clear();
    }
  }

  /// Bildirim temizle ve sıradaki görev varsa göster
  void clear() {
    if (!state.isVisible) return;

    final nextInQueue = state.completionQueue.isNotEmpty
        ? state.completionQueue.first
        : null;

    if (nextInQueue != null) {
      // Kuyruktaki sıradaki görevi göster
      final updatedQueue = List<Quest>.from(state.completionQueue)..removeAt(0);
      _showCompletion(nextInQueue, queue: updatedQueue);
    } else {
      // Kuyruk boş, tamamen temizle
      state = const QuestCompletionState.empty();
    }

    debugPrint('[QuestCompletion] Bildirim temizlendi');
  }

  /// Manuel dismiss (kullanıcı kapatırsa)
  void dismiss() {
    clear();
  }

  /// Private methods

  void _showCompletion(Quest quest, {List<Quest>? queue}) {
    state = QuestCompletionState(
      completedQuest: quest,
      isVisible: true,
      rewardClaimed: false,
      completionQueue: queue ?? [],
      completedAt: DateTime.now(),
    );

    debugPrint('[QuestCompletion] Görev tamamlama bildirimi: ${quest.title}');
  }

  void _queueCompletion(Quest quest) {
    if (state.completionQueue.length >= 5) {
      // Kuyruk çok uzunsa eskiyi at
      final updatedQueue = List<Quest>.from(state.completionQueue)
        ..removeAt(0)
        ..add(quest);
      state = state.copyWith(completionQueue: updatedQueue);
    } else {
      final updatedQueue = List<Quest>.from(state.completionQueue)..add(quest);
      state = state.copyWith(completionQueue: updatedQueue);
    }

    debugPrint('[QuestCompletion] Görev kuyruğa eklendi: ${quest.title} (Kuyruk: ${state.completionQueue.length})');
  }

  /// Özel g��rev tiplerinin ödül işlemleri
  Future<void> _handleSpecialRewardTypes(Quest quest, Ref ref, int actualReward) async {
    switch (quest.type) {
      case QuestType.weekly:
        await _handleWeeklyReward(quest, ref, actualReward);
        break;
      case QuestType.monthly:
        await _handleMonthlyReward(quest, ref, actualReward);
        break;
      case QuestType.achievement:
        await _handleAchievementReward(quest, ref, actualReward);
        break;
      default:
        break;
    }
  }

  Future<void> _handleWeeklyReward(Quest quest, Ref ref, int reward) async {
    // Haftalık görev bonusları ve özel ödüller
    debugPrint('[QuestCompletion] Haftalık görev özel ödülü işleniyor');
  }

  Future<void> _handleMonthlyReward(Quest quest, Ref ref, int reward) async {
    // Aylık görev bonusları ve özel ödüller
    debugPrint('[QuestCompletion] Aylık görev özel ödülü işleniyor');
  }

  Future<void> _handleAchievementReward(Quest quest, Ref ref, int reward) async {
    // Başarım rozetleri ve özel ödüller
    debugPrint('[QuestCompletion] Başarım özel ödülü işleniyor');
  }
}

/// Quest Completion State
class QuestCompletionState {
  final Quest? completedQuest;
  final bool isVisible;
  final bool rewardClaimed;
  final List<Quest> completionQueue;
  final DateTime? completedAt;
  final int? actualReward;

  const QuestCompletionState({
    this.completedQuest,
    this.isVisible = false,
    this.rewardClaimed = false,
    this.completionQueue = const [],
    this.completedAt,
    this.actualReward,
  });

  const QuestCompletionState.empty() : this();

  QuestCompletionState copyWith({
    Quest? completedQuest,
    bool? isVisible,
    bool? rewardClaimed,
    List<Quest>? completionQueue,
    DateTime? completedAt,
    int? actualReward,
  }) {
    return QuestCompletionState(
      completedQuest: completedQuest ?? this.completedQuest,
      isVisible: isVisible ?? this.isVisible,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
      completionQueue: completionQueue ?? this.completionQueue,
      completedAt: completedAt ?? this.completedAt,
      actualReward: actualReward ?? this.actualReward,
    );
  }

  /// Kuyruktaki toplam ödül hesapla
  int get totalQueuedReward {
    return completionQueue.fold(0, (sum, quest) => sum + quest.reward);
  }

  /// Birden fazla görev tamamlanmış mı?
  bool get hasQueuedCompletions => completionQueue.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuestCompletionState &&
        other.completedQuest?.id == completedQuest?.id &&
        other.isVisible == isVisible &&
        other.rewardClaimed == rewardClaimed &&
        other.completionQueue.length == completionQueue.length;
  }

  @override
  int get hashCode {
    return Object.hash(
      completedQuest?.id,
      isVisible,
      rewardClaimed,
      completionQueue.length,
    );
  }
}

final questCompletionProvider = StateNotifierProvider<QuestCompletionNotifier, QuestCompletionState>((ref) {
  return QuestCompletionNotifier();
});
