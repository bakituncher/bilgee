import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taktik/features/coach/models/saved_solution_model.dart';
import 'package:uuid/uuid.dart';

// 1. Provider Tanımı
final savedSolutionsProvider = StateNotifierProvider<SavedSolutionsNotifier, List<SavedSolutionModel>>((ref) {
  return SavedSolutionsNotifier();
});

// 2. Notifier Sınıfı (Logic)
class SavedSolutionsNotifier extends StateNotifier<List<SavedSolutionModel>> {
  SavedSolutionsNotifier() : super([]) {
    _loadSolutions(); // Başlangıçta yükle
  }

  static const String _storageKey = 'saved_ai_solutions';

  // Çözümleri Diskten Yükle
  Future<void> _loadSolutions() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? storedList = prefs.getStringList(_storageKey);

    if (storedList != null) {
      state = storedList
          .map((item) => SavedSolutionModel.fromJson(item))
          .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // En yeni en üstte
    }
  }

  // Yeni Çözüm Kaydet
  Future<void> saveSolution({
    required File imageFile,
    required String solutionText,
    String? subject,
  }) async {
    try {
      // 1. Resmi Kalıcı Dizine Taşı
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = '${const Uuid().v4()}.jpg';
      final savedImage = await imageFile.copy('${appDir.path}/$fileName');

      // 2. Modeli Oluştur
      final newSolution = SavedSolutionModel(
        id: const Uuid().v4(),
        localImagePath: savedImage.path,
        solutionText: solutionText,
        timestamp: DateTime.now(),
        subject: subject,
      );

      // 3. State'i Güncelle
      state = [newSolution, ...state];

      // 4. Veriyi Diske (SharedPrefs) Yaz
      await _saveToPrefs();
    } catch (e) {
      print("Kaydetme hatası: $e");
      rethrow;
    }
  }

  // Çözüm Sil
  Future<void> deleteSolution(String id) async {
    // 1. Silinecek öğeyi bul
    final itemIndex = state.indexWhere((element) => element.id == id);
    if (itemIndex == -1) return;

    final item = state[itemIndex];

    // 2. Dosyayı cihazdan sil (Storage temizliği)
    final file = File(item.localImagePath);
    if (await file.exists()) {
      await file.delete();
    }

    // 3. Listeden çıkar
    state = state.where((element) => element.id != id).toList();

    // 4. Güncel listeyi kaydet
    await _saveToPrefs();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> dataList = state.map((e) => e.toJson()).toList();
    await prefs.setStringList(_storageKey, dataList);
  }
}

