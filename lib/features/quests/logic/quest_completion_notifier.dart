// lib/features/quests/logic/quest_completion_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilge_ai/features/quests/logic/quest_service.dart';

/// Bu Notifier, tamamlanan bir görevin bilgisini geçici olarak tutar
/// ve UI'ın bu bilgiyi alıp bir bildirim göstermesini sağlar.
class QuestCompletionNotifier extends StateNotifier<Quest?> {
  QuestCompletionNotifier() : super(null);

  /// UI'ın göstermesi için tamamlanan görevi ayarlar.
  void show(Quest completedQuest) {
    // ÖNEMLİ: Eğer aynı görev zaten gösteriliyorsa tekrar gösterme
    if (state?.id == completedQuest.id) {
      return;
    }

    // Sadece ekranda başka bir bildirim yoksa yenisini göster.
    if (state == null) {
      state = completedQuest;
      print('[QuestCompletion] Görev tamamlama bildirimi gösteriliyor: ${completedQuest.title}');
    }
  }

  /// Ödül claim edildiğinde çağrılacak - BP güncelleme yapılacak
  Future<void> claimReward(Quest quest, Ref ref) async {
    try {
      // Kullanıcının BP'sini artır
      final firestoreSvc = ref.read(firestoreServiceProvider);
      final user = ref.read(userProfileProvider).value;

      if (user != null) {
        // Firestore'da user dokümanını güncelle - bilgePoints alanını artır
        await firestoreSvc.usersCollection.doc(user.id).update({
          'bilgePoints': FieldValue.increment(quest.reward),
        });

        // Görevin reward claimed flag'ini güncelle
        await firestoreSvc.updateQuestFields(user.id, quest.id, {
          'rewardClaimed': true,
        });

        print('[QuestCompletion] Ödül toplandı: ${quest.reward} BP');

        // UI'dan bildirimi kaldır
        clear();

        // Quest listesini yenile
        ref.invalidate(dailyQuestsProvider);
        ref.invalidate(userProfileProvider);
      }
    } catch (e) {
      print('[QuestCompletion] Ödül toplama hatası: $e');
    }
  }

  /// Bildirim gösterildikten sonra durumu temizler.
  void clear() {
    if (state != null) {
      print('[QuestCompletion] Bildirim temizlendi');
    }
    state = null;
  }
}

final questCompletionProvider = StateNotifierProvider<QuestCompletionNotifier, Quest?>((ref) {
  return QuestCompletionNotifier();
});
