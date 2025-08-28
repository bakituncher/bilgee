// lib/features/quests/logic/quest_completion_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';

/// Bu Notifier, tamamlanan bir görevin bilgisini geçici olarak tutar
/// ve UI'ın bu bilgiyi alıp bir bildirim göstermesini sağlar.
class QuestCompletionNotifier extends StateNotifier<Quest?> {
  QuestCompletionNotifier() : super(null);

  /// UI'ın göstermesi için tamamlanan görevi ayarlar.
  void show(Quest completedQuest) {
    // Sadece ekranda başka bir bildirim yoksa yenisini göster.
    if (state == null) {
      state = completedQuest;
    }
  }

  /// Bildirim gösterildikten sonra durumu temizler.
  void clear() {
    state = null;
  }
}

final questCompletionProvider = StateNotifierProvider<QuestCompletionNotifier, Quest?>((ref) {
  return QuestCompletionNotifier();
});