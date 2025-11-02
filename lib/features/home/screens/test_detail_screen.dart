// lib/features/home/screens/test_detail_screen.dart
import 'package:taktik/data/models/test_model.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pieChartSections = _createPieChartSections(context);
    final weakestSubjectEntry = _findWeakestSubject();

    return Scaffold(
      appBar: AppBar(
        title: Text(test.testName),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    theme.scaffoldBackgroundColor,
                    theme.cardColor.withOpacity(0.3),
                  ]
                : [
                    theme.scaffoldBackgroundColor,
                    colorScheme.surfaceContainerHighest.withOpacity(0.2),
                  ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Compact stats card
              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                        : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    width: 1,
                  ),
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                padding: const EdgeInsets.all(14.0),
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
              const SizedBox(height: 16),

              // Pie Chart with Legend - Fixed overlapping text
              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                        : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    width: 1,
                  ),
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Derslerin Net Dağılımı', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 220,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: PieChart(
                              PieChartData(
                                sections: pieChartSections,
                                centerSpaceRadius: 35,
                                sectionsSpace: 2,
                                pieTouchData: PieTouchData(
                                  touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _buildLegend(context, pieChartSections),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Compact AI Analysis Card
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, color: colorScheme.secondary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Analiz ve Tavsiye',
                            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'En çok zorlandığın ders '),
                                TextSpan(
                                  text: '${weakestSubjectEntry.key} ',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const TextSpan(text: 'görünüyor. Bu derse ağırlık vererek netlerini artırabilirsin!'),
                              ],
                            ),
                            style: textTheme.bodyMedium?.copyWith(height: 1.4),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Compact subject results list
              Text('Ders Sonuçları', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...test.scores.entries.map((entry) {
                final subject = entry.key;
                final scores = entry.value;
                final net = scores['dogru']! - (scores['yanlis']! * test.penaltyCoefficient);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                          : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    title: Text(
                      subject,
                      style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: Text(
                      'D: ${scores['dogru']} / Y: ${scores['yanlis']} / B: ${scores['bos']}',
                      style: textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.secondary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        net.toStringAsFixed(2),
                        style: textTheme.titleSmall?.copyWith(
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // Pasta grafiği dilimlerini oluşturan fonksiyon - TEXT REMOVED to prevent overlap
  List<PieChartSectionData> _createPieChartSections(BuildContext context) {
    final List<Color> colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red,
      Colors.teal, Colors.pink, Colors.amber, Colors.indigo, Colors.brown
    ];
    int colorIndex = 0;

    return test.scores.entries.map((entry) {
      final subjectNet = entry.value['dogru']! - (entry.value['yanlis']! * test.penaltyCoefficient);
      if (subjectNet <= 0) return null;

      final section = PieChartSectionData(
        value: subjectNet,
        title: '', // Remove text to prevent overlapping
        radius: 70,
        color: colors[colorIndex % colors.length],
        titleStyle: const TextStyle(fontSize: 0), // Hide any potential text
        badgeWidget: null,
      );
      colorIndex++;
      return section;
    }).where((section) => section != null).cast<PieChartSectionData>().toList();
  }

  // Build legend for pie chart to show subject names without overlap
  Widget _buildLegend(BuildContext context, List<PieChartSectionData> sections) {
    final textTheme = Theme.of(context).textTheme;
    final List<Color> colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red,
      Colors.teal, Colors.pink, Colors.amber, Colors.indigo, Colors.brown
    ];

    final entries = test.scores.entries.toList();
    final legendItems = <Widget>[];
    int colorIndex = 0;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final subjectNet = entry.value['dogru']! - (entry.value['yanlis']! * test.penaltyCoefficient);
      if (subjectNet <= 0) continue;

      legendItems.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colors[colorIndex % colors.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${entry.key}: ${subjectNet.toStringAsFixed(1)}',
                  style: textTheme.bodySmall?.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
      colorIndex++;
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: legendItems,
      ),
    );
  }

  // İstatistik kolonu oluşturan yardımcı widget - compact
  Widget _buildStatColumn(String label, String value, BuildContext context, {bool isHeader = false}) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final style = isHeader ? textTheme.titleMedium : textTheme.titleSmall;
    final color = isHeader ? colorScheme.secondary : colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(fontSize: 10),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: style?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: isHeader ? 16 : 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}