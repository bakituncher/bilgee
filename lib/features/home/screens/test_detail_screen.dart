// lib/features/home/screens/test_detail_screen.dart
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class TestDetailScreen extends StatelessWidget {
  final TestModel test;
  const TestDetailScreen({super.key, required this.test});

  // En düşük netli dersi bulan fonksiyon
  MapEntry<String, double> _findWeakestSubject() {
    double minNet = double.maxFinite;
    String weakestSubject = '';

    test.scores.forEach((subject, scores) {
      final net = scores['dogru']! - (scores['yanlis']! * test.penaltyCoefficient);
      if (net < minNet) {
        minNet = net;
        weakestSubject = subject;
      }
    });

    return MapEntry(weakestSubject, minNet);
  }


  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final pieChartSections = _createPieChartSections(context);
    final weakestSubjectEntry = _findWeakestSubject(); // Zayıf dersi bul

    return Scaffold(
      appBar: AppBar(
        title: Text(test.testName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Genel İstatistik Kartı
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('Toplam Net', test.totalNet.toStringAsFixed(2), context, isHeader: true),
                    _buildStatColumn('Doğru', test.totalCorrect.toString(), context),
                    _buildStatColumn('Yanlış', test.totalWrong.toString(), context),
                    _buildStatColumn('Boş', test.totalBlank.toString(), context),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Pasta Grafiği
            Text('Derslerin Net Dağılımı', style: textTheme.titleLarge),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: pieChartSections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Yapay Zeka Analiz Kartı (Şimdilik statik, ileride dinamikleşecek)
            Text('Analiz ve Tavsiye', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              color: colorScheme.primary.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: colorScheme.secondary, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Bu denemede en çok zorlandığın ders '),
                            TextSpan(
                              text: '${weakestSubjectEntry.key} ',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const TextSpan(text: 'görünüyor. Bu derse biraz daha ağırlık vererek netlerini hızla artırabilirsin!'),
                          ],
                        ),
                        style: textTheme.bodyLarge,
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Ders Sonuçları Listesi
            Text('Ders Sonuçları', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            ...test.scores.entries.map((entry) {
              final subject = entry.key;
              final scores = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(subject, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'D: ${scores['dogru']} / Y: ${scores['yanlis']} / B: ${scores['bos']}',
                    style: textTheme.bodyMedium,
                  ),
                  trailing: Text(
                    'Net: ${(scores['dogru']! - (scores['yanlis']! * test.penaltyCoefficient)).toStringAsFixed(2)}',
                    style: textTheme.titleMedium?.copyWith(color: colorScheme.secondary),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // Pasta grafiği dilimlerini oluşturan fonksiyon
  List<PieChartSectionData> _createPieChartSections(BuildContext context) {
    final List<Color> colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red,
      Colors.teal, Colors.pink, Colors.amber, Colors.indigo, Colors.brown
    ];
    int colorIndex = 0;

    return test.scores.entries.map((entry) {
      final subjectNet = entry.value['dogru']! - (entry.value['yanlis']! * test.penaltyCoefficient);
      if (subjectNet <= 0) return null; // Net'i 0 veya daha düşükse grafikte gösterme

      final section = PieChartSectionData(
          value: subjectNet,
          title: '${subjectNet.toStringAsFixed(1)}\n${entry.key}',
          radius: 80,
          color: colors[colorIndex % colors.length],
          titleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white
          )
      );
      colorIndex++;
      return section;
    }).where((section) => section != null).cast<PieChartSectionData>().toList();
  }

  // İstatistik kolonu oluşturan yardımcı widget
  Widget _buildStatColumn(String label, String value, BuildContext context, {bool isHeader = false}) {
    final textTheme = Theme.of(context).textTheme;
    final style = isHeader ? textTheme.titleLarge : textTheme.titleMedium;
    final color = isHeader ? Theme.of(context).colorScheme.secondary : null;

    return Column(
      children: [
        Text(label, style: textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: style?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}