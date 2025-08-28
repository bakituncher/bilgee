// lib/features/quests/quest_armory.dart

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

// Tüm olası görev şablonlarını tutan ve uygulama başlangıcında doldurulan
// global görev listesi (cephanelik).
final List<Map<String, dynamic>> questArmory = <Map<String, dynamic>>[];

/// Uygulama başlarken görevleri asset'ten belleğe yükleyen yardımcı sınıf.
class QuestArmoryLoader {
  // Görevlerin daha önce yüklenip yüklenmediğini kontrol eden bayrak.
  static bool _loaded = false;

  /// Görevleri assets/quests/quests.json dosyasından okur ve
  /// [questArmory] listesini doldurur. Bu işlem uygulama ömründe
  /// sadece bir kez yapılır.
  static Future<void> preload() async {
    // Eğer zaten yüklendiyse, tekrar yükleme yapma.
    if (_loaded) return;

    try {
      // 1. JSON dosyasını metin olarak oku.
      final rawJsonString = await rootBundle.loadString('assets/quests/quests.json');

      // 2. Metni bir JSON listesine dönüştür.
      final List<dynamic> decodedList = jsonDecode(rawJsonString) as List<dynamic>;

      // 3. Global listeyi temizle ve yeni görevlerle doldur.
      //    .cast<Map<String, dynamic>>() ile her bir elemanın doğru türde olduğundan emin ol.
      questArmory
        ..clear()
        ..addAll(decodedList.cast<Map<String, dynamic>>());

      // 4. Yüklendi olarak işaretle.
      _loaded = true;

    } catch (e) {
      // Hata durumunda konsola detaylı bir mesaj yazdır.
      // Bu, JSON formatında bir hata varsa veya dosya bulunamazsa çok yardımcı olur.
      print('HATA: assets/quests/quests.json dosyası yüklenemedi. Hata detayı: $e');
    }
  }
}