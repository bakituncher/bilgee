// lib/features/stats/models/chart_data.dart
import 'package:flutter/material.dart';
import 'package:taktik/data/models/test_model.dart';

/// Grafik verisi için model
class ChartData {
  final List<TestModel> tests;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color baseColor;

  ChartData({
    required this.tests,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.baseColor,
  });

  /// Performans trendini hesapla (son testler vs önceki testler)
  /// Yeterli veri yoksa 0 döndürür (stabil kabul edilir)
  double get performanceTrend {
    // En az 3 test olmalı ki anlamlı bir trend hesaplanabilsin
    if (tests.length < 3) return 0.0;

    final sortedTests = tests.toList()..sort((a, b) => a.date.compareTo(b.date));

    // Son 3 test ile önceki testleri karşılaştır
    final recentCount = (sortedTests.length / 3).ceil().clamp(1, 5);
    final olderCount = (sortedTests.length - recentCount).clamp(1, sortedTests.length - 1);

    final olderTests = sortedTests.take(olderCount);
    final recentTests = sortedTests.skip(sortedTests.length - recentCount);

    if (olderTests.isEmpty || recentTests.isEmpty) return 0.0;

    final olderAvg = olderTests.fold<double>(0.0, (sum, t) => sum + t.totalNet) / olderTests.length;
    final recentAvg = recentTests.fold<double>(0.0, (sum, t) => sum + t.totalNet) / recentTests.length;

    // Yüzdelik değişim hesapla (daha dengeli)
    if (olderAvg == 0) return recentAvg > 0 ? 5.0 : 0.0;

    final percentChange = ((recentAvg - olderAvg) / olderAvg) * 100;

    // Makul bir aralığa sınırla (-10 ile +10 arası)
    return percentChange.clamp(-10.0, 10.0);
  }

  /// Ortalama net
  double get averageNet {
    if (tests.isEmpty) return 0.0;
    return (tests.fold<double>(0.0, (sum, t) => sum + t.totalNet) / tests.length).toDouble();
  }
}

