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

  /// Performans trendini hesapla (son 3 test vs önceki 3 test)
  double get performanceTrend {
    if (tests.length < 2) return 0.0;

    final sortedTests = tests.toList()..sort((a, b) => a.date.compareTo(b.date));
    final halfPoint = (sortedTests.length / 2).floor();

    final firstHalf = sortedTests.take(halfPoint);
    final secondHalf = sortedTests.skip(halfPoint);

    final firstAvg = firstHalf.isEmpty
        ? 0.0
        : firstHalf.fold<double>(0.0, (sum, t) => sum + t.totalNet) / firstHalf.length;
    final secondAvg = secondHalf.isEmpty
        ? 0.0
        : secondHalf.fold<double>(0.0, (sum, t) => sum + t.totalNet) / secondHalf.length;

    return (secondAvg - firstAvg).toDouble();
  }

  /// Ortalama net
  double get averageNet {
    if (tests.isEmpty) return 0.0;
    return (tests.fold<double>(0.0, (sum, t) => sum + t.totalNet) / tests.length).toDouble();
  }
}

