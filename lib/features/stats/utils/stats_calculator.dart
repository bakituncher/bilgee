// lib/features/stats/utils/stats_calculator.dart
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/models/user_model.dart';

/// İstatistik hesaplama yardımcı sınıfı
class StatsCalculator {
  /// Ortalama net hesapla
  static String calculateAvgNet(UserModel user, List<TestModel> tests) {
    // Önemli: Bu fonksiyon bazı yerlerde filtrelenmiş test listesiyle (örn. ana sınavlar)
    // çağrılıyor. User modelindeki testCount/totalNetSum alanları branş denemelerini de
    // içerebileceği için, liste verildiyse öncelik her zaman bu liste olmalı.

    final int testCount;
    final double totalNet;

    if (tests.isNotEmpty) {
      testCount = tests.length;
      totalNet = tests.fold<double>(0, (sum, t) => sum + t.totalNet);
    } else {
      // Fallback: elde test listesi yoksa user aggregate değerlerini kullan.
      testCount = user.testCount;
      totalNet = user.totalNetSum;
    }

    final avgNet = testCount > 0 ? (totalNet / testCount) : 0.0;
    return avgNet.toStringAsFixed(1);
  }

  /// Streak (ardışık gün) değerini döndür
  ///
  /// MERKEZİ SİSTEM: Streak artık Firebase'de server-side hesaplanıyor ve
  /// public_profiles koleksiyonunda tutuluyor. Bu fonksiyon sadece UserModel'deki
  /// streak değerini döndürür.
  ///
  /// Not: Streak güncellemeleri test ekleme/silme işlemlerinde Cloud Functions
  /// tarafından otomatik olarak yapılır.
  static int getStreak(UserModel user) {
    return user.streak;
  }
}
