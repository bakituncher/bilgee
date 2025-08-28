// lib/features/quests/quest_armory.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

// Uygulama başlangıcında JSON'dan doldurulacak global cephanelik listesi
final List<Map<String, dynamic>> questArmory = <Map<String, dynamic>>[];

class QuestArmoryLoader {
  static bool _loaded = false;

  static Future<void> preload() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/quests/quests.json');
    final List<dynamic> data = jsonDecode(raw) as List<dynamic>;
    questArmory
      ..clear()
      ..addAll(data.cast<Map<String, dynamic>>());
    _loaded = true;
  }
}
