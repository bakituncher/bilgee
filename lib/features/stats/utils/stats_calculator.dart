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

  /// Streak (ardışık gün) hesapla
  static int calculateStreak(List<TestModel> tests) {
    if (tests.isEmpty) return 0;

    // Testleri tarihe göre sırala (en yeni en başta)
    final sortedTests = tests.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    int streak = 0;
    DateTime? lastDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final test in sortedTests) {
      final testDate = DateTime(test.date.year, test.date.month, test.date.day);

      if (lastDate == null) {
        // İlk test kontrolü - bugün olmalı, yoksa seri yok
        final daysDiff = today.difference(testDate).inDays;
        if (daysDiff == 0) {
          // Bugün test var, seri başlasın
          streak = 1;
          lastDate = testDate;
        } else if (daysDiff == 1) {
          // En son test dün yapılmış, bugün yapılmamış - seri yok
          return 0;
        } else {
          // Daha eski - seri kesinlikle yok
          return 0;
        }
      } else {
        // Bir önceki günde test var mı?
        final daysDiff = lastDate.difference(testDate).inDays;
        if (daysDiff == 1) {
          // Ardışık gün
          streak++;
          lastDate = testDate;
        } else if (daysDiff == 0) {
          // Aynı gün içinde birden fazla test - sayma
          continue;
        } else {
          // Seri kırılmış
          break;
        }
      }
    }

    return streak;
  }
}
