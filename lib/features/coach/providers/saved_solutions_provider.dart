import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taktik/features/coach/models/saved_solution_model.dart';
import 'package:uuid/uuid.dart';

final savedSolutionsProvider = StateNotifierProvider<SavedSolutionsNotifier, List<SavedSolutionModel>>((ref) {
  return SavedSolutionsNotifier();
});

class SavedSolutionsNotifier extends StateNotifier<List<SavedSolutionModel>> {
  SavedSolutionsNotifier() : super([]) {
    _loadFromHive();
  }

  // Veritabanı kutusu
  Box<SavedSolutionModel> get _box => Hive.box<SavedSolutionModel>('saved_solutions_box');

  void _loadFromHive() {
    // Verileri tarihe göre sıralı getir (En yeni en üstte)
    final list = _box.values.toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    state = list;
  }

  // PROFESYONEL KAYIT FONKSİYONU
  Future<void> saveSolution({
    required File imageFile,
    required String solutionText,
    String? subject,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final String uuid = const Uuid().v4();

      // 1. Orijinal Resmi Kaydet (Yüksek Kalite)
      final String originalFileName = 'sol_$uuid.jpg';
      final File originalFile = await imageFile.copy('${appDir.path}/$originalFileName');

      // 2. Thumbnail Oluştur ve Kaydet (Düşük Boyut - Liste Hızı İçin)
      final String thumbFileName = 'thumb_$uuid.jpg';
      final String thumbPath = '${appDir.path}/$thumbFileName';

      await FlutterImageCompress.compressAndGetFile(
        originalFile.path,
        thumbPath,
        minWidth: 300,  // Liste görünümü için 300px yeterli
        minHeight: 300,
        quality: 50,    // Kaliteyi düşür, boyutu minicik yap
      );

      // 3. Modeli Oluştur
      final newSolution = SavedSolutionModel(
        id: uuid,
        localImagePath: originalFile.path,
        thumbnailPath: thumbPath, // Thumbnail yolunu kaydet
        solutionText: solutionText,
        timestamp: DateTime.now(),
        subject: subject,
      );

      // 4. Hive'a Ekle
      await _box.add(newSolution);

      // 5. State Güncelle
      _loadFromHive();
    } catch (e) {
      print("Kayıt hatası: $e");
      rethrow;
    }
  }

  // Silme Fonksiyonu
  Future<void> deleteSolution(SavedSolutionModel item) async {
    try {
      // 1. Dosyaları Diskten Sil (Çöp birikmesin)
      final originalFile = File(item.localImagePath);
      final thumbFile = File(item.thumbnailPath);

      if (await originalFile.exists()) await originalFile.delete();
      if (await thumbFile.exists()) await thumbFile.delete();

      // 2. Veritabanından Sil
      await item.delete(); // HiveObject özelliği sayesinde kendini silebilir

      // 3. State Güncelle
      _loadFromHive();
    } catch (e) {
      print("Silme hatası: $e");
    }
  }
}

