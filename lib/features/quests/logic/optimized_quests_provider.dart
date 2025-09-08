// lib/features/quests/logic/optimized_quests_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'dart:async';

/// Aktif görev listesini user stream değiştikçe günceller.
/// Equatable destekli Quest modeli ile gereksiz manuel diff kaldırıldı.
class OptimizedQuestsNotifier extends StateNotifier<List<Quest>> {
  final Ref _ref;
  StreamSubscription<List<Quest>>? _sub;
  OptimizedQuestsNotifier(this._ref) : super(const []) {
    void subscribe(String userId) {
      _sub?.cancel();
      _sub = _ref.read(firestoreServiceProvider).streamDailyQuests(userId).listen((quests) {
        state = quests;
      });
    }

    final user = _ref.read(userProfileProvider).value;
    if (user != null) {
      subscribe(user.id);
    }
    // Stream dinle ve direkt ata
    _ref.listen(userProfileProvider, (previous, next) {
      final newUser = next.value;
      if (newUser == null) {
        state = const [];
        _sub?.cancel();
        _sub = null;
        return;
      }
      subscribe(newUser.id);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final optimizedDailyQuestsProvider = StateNotifierProvider<OptimizedQuestsNotifier, List<Quest>>((ref) {
  return OptimizedQuestsNotifier(ref);
});

/// YENİ: Tüm görev tiplerini (günlük, haftalık, aylık) içeren provider
class QuestsData {
  final List<Quest> allQuests;
  final Map<String, Quest> allQuestsMap;

  QuestsData({required this.allQuests, required this.allQuestsMap});
}

final optimizedQuestsProvider = FutureProvider<QuestsData>((ref) async {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) {
    return QuestsData(allQuests: [], allQuestsMap: {});
  }

  final firestoreService = ref.read(firestoreServiceProvider);

  try {
    // FirestoreService.getDailyQuestsOnce tüm tipleri (günlük+haftalık+aylık) birlikte döner
    final allQuests = await firestoreService.getDailyQuestsOnce(user.id);
    final questsMap = <String, Quest>{ for (final q in allQuests) q.id: q };
    return QuestsData(allQuests: allQuests, allQuestsMap: questsMap);
  } catch (e) {
    print('[OptimizedQuestsProvider] Error: $e');
    return QuestsData(allQuests: [], allQuestsMap: {});
  }
});
