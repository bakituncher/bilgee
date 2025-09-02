// lib/features/quests/logic/quest_session_state.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Oturum boyunca tamamlanan görevlere tekrar progres yazmayı engeller.
/// Günlük görevler yeniden üretildiğinde (yeni gün ya da manuel yenileme), TEMİZLENMELİ.
final sessionCompletedQuestsProvider = StateProvider<Set<String>>((ref) => <String>{});

