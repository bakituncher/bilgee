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
  ///
  /// Kural: Kullanıcı bir gün içinde en az bir deneme/test eklediyse o gün "aktif" sayılır.
  /// Streak, en son aktif gün (bugün veya dün) baz alınarak geriye doğru kesintisiz aktif günlerin sayısıdır.
  ///
  /// Not: Aynı gün içinde birden fazla test streak'i artırmaz.
  static int calculateStreak(List<TestModel> tests) {
    if (tests.isEmpty) return 0;

    final sortedTests = tests.toList()..sort((a, b) => b.date.compareTo(a.date));

    // Tekilleştir: sadece gün bazında unique set
    final uniqueDays = <DateTime>{};
    for (final t in sortedTests) {
      uniqueDays.add(DateTime(t.date.year, t.date.month, t.date.day));
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // En son aktif gün
    final lastActiveDay = uniqueDays.reduce((a, b) => a.isAfter(b) ? a : b);
    final diffFromToday = today.difference(lastActiveDay).inDays;

    // Bugün de aktif değilse ve dün de aktif değilse streak yok.
    if (diffFromToday > 1) return 0;

    // Sayım başlangıcı: bugün aktifse bugün, değilse dün.
    DateTime cursor = diffFromToday == 0 ? today : today.subtract(const Duration(days: 1));

    int streak = 0;
    while (uniqueDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }
}
