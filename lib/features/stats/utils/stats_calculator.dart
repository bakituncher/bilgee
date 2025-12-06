// lib/features/stats/utils/stats_calculator.dart
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/models/user_model.dart';

/// İstatistik hesaplama yardımcı sınıfı
class StatsCalculator {
  /// Ortalama net hesapla
  static String calculateAvgNet(UserModel user, List<TestModel> tests) {
    final testCount = user.testCount ?? tests.length;
    final totalNet = user.totalNetSum ??
        tests.fold<double>(0, (sum, t) => sum + t.totalNet);
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

