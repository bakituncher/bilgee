// lib/features/stats/models/chart_data.dart
import 'package:flutter/material.dart';
import 'package:taktik/data/models/test_model.dart';
import 'dart:math' as math;

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

  /// Performans trendini hesapla (Lineer Regresyon Eğim Yöntemi)
  /// Son denemelerdeki düşüş/yükseliş eğimini yüzdesel skora çevirir.
  double get performanceTrend {
    // En az 2 test olmalı ki eğim hesaplanabilsin
    if (tests.length < 2) return 0.0;

    final sortedTests = tests.toList()..sort((a, b) => a.date.compareTo(b.date));

    // GÜNCELLEME: Grafikte 8 deneme gösterildiği için trend analizini de
    // son 8 denemeye (recentTests) göre yapıyoruz.
    final recentTests = sortedTests.length > 8
        ? sortedTests.sublist(sortedTests.length - 8)
        : sortedTests;

    // Linear Regression (En Küçük Kareler Yöntemi)
    // y = mx + c (m: eğim, trendin yönü ve şiddeti)

    int n = recentTests.length;
    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumX2 = 0;

    for (int i = 0; i < n; i++) {
      double x = i.toDouble(); // Zaman (deneme sırası)
      double y = recentTests[i].totalNet; // Net değeri

      sumX += x;
      sumY += y;
      sumXY += (x * y);
      sumX2 += (x * x);
    }

    double denominator = (n * sumX2) - (sumX * sumX);
    if (denominator == 0) return 0.0;

    // Slope (Eğim): Negatif ise düşüş, Pozitif ise yükseliş
    double slope = ((n * sumXY) - (sumX * sumY)) / denominator;

    double avgNet = sumY / n;

    // Ortalama net çok düşükse (0'a yakınsa), bölme işlemi yüzünden
    // sonuçlar anlamsız şekilde büyür. Bu durumda direkt eğim baz alınır.
    // Eşik değeri 5 net olarak belirlendi.
    if (avgNet.abs() < 5) {
      return slope * 10;
    }

    // Trend yüzdesini hesapla.
    // DÜZELTME: İşareti (yönü) sadece slope belirler.
    // avgNet'in sadece büyüklüğünü (abs) alarak ölçekleme yapıyoruz.
    double percentTrend = (slope / avgNet.abs()) * 100;

    // Sonucu -100 ile +100 arasında sınırla
    return percentTrend.clamp(-100.0, 100.0);
  }

  /// Ortalama net (Tüm zamanlar)
  double get averageNet {
    if (tests.isEmpty) return 0.0;
    return (tests.fold<double>(0.0, (sum, t) => sum + t.totalNet) / tests.length).toDouble();
  }
}