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
    final weakestSubjectEntry = _findWeakestSubject(); // Zayıf dersi bul

    return Scaffold(
      appBar: AppBar(
        title: Text(test.testName),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.scaffoldBackgroundColor,
              theme.cardColor.withOpacity(0.3),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Genel İstatistik Kartı - daha şık
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: theme.cardColor,
                  border: Border.all(
                    color: isDark 
                      ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                      : colorScheme.onSurface.withOpacity(0.08),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark 
                        ? Colors.black.withOpacity(0.2)
                        : colorScheme.primary.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('Toplam Net', test.totalNet.toStringAsFixed(1), context, isHeader: true),
                    _buildStatColumn('Doğru', test.totalCorrect.toString(), context, color: colorScheme.secondary),
                    _buildStatColumn('Yanlış', test.totalWrong.toString(), context, color: colorScheme.error),
                    _buildStatColumn('Boş', test.totalBlank.toString(), context),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Pasta Grafiği Başlığı
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.pie_chart_rounded, color: colorScheme.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Net Dağılımı',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Pasta Grafiği - iyileştirilmiş
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: theme.cardColor,
                  border: Border.all(
                    color: isDark 
                      ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                      : colorScheme.onSurface.withOpacity(0.08),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark 
                        ? Colors.black.withOpacity(0.15)
                        : colorScheme.primary.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  height: 260,
                  child: pieChartSections.isEmpty
                    ? Center(
                        child: Text(
                          'Net değeri olan ders yok',
                          style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    : PieChart(
                        PieChartData(
                          sections: pieChartSections,
                          centerSpaceRadius: 50,
                          sectionsSpace: 3,
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                ),
              ),
              const SizedBox(height: 20),

              // Yapay Zeka Analiz Kartı
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.lightbulb_outline, color: colorScheme.secondary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Analiz ve Tavsiye',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withOpacity(isDark ? 0.15 : 0.08),
                      colorScheme.secondary.withOpacity(isDark ? 0.1 : 0.06),
                    ],
                  ),
                  border: Border.all(
                    color: isDark
                      ? colorScheme.primary.withOpacity(0.2)
                      : colorScheme.onSurface.withOpacity(0.08),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(18.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.psychology_rounded, color: colorScheme.secondary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'En çok zorlandığın ders '),
                            TextSpan(
                              text: '${weakestSubjectEntry.key} ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            const TextSpan(text: 'görünüyor. Bu derse odaklanarak netlerini artırabilirsin!'),
                          ],
                        ),
                        style: textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Ders Sonuçları Listesi Başlığı
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.subject_rounded, color: colorScheme.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Ders Sonuçları',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Ders kartları
              ...test.scores.entries.map((entry) {
                final subject = entry.key;
                final scores = entry.value;
                final net = scores['dogru']! - (scores['yanlis']! * test.penaltyCoefficient);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: theme.cardColor,
                    border: Border.all(
                      color: isDark 
                        ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                        : colorScheme.onSurface.withOpacity(0.08),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark 
                          ? Colors.black.withOpacity(0.1)
                          : colorScheme.primary.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                subject,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: (net >= 0 ? colorScheme.secondary : colorScheme.error).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (net >= 0 ? colorScheme.secondary : colorScheme.error).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Net: ${net.toStringAsFixed(1)}',
                                style: textTheme.titleSmall?.copyWith(
                                  color: net >= 0 ? colorScheme.secondary : colorScheme.error,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _resultChip(context, 'D', scores['dogru'].toString(), colorScheme.secondary),
                            _resultChip(context, 'Y', scores['yanlis'].toString(), colorScheme.error),
                            _resultChip(context, 'B', scores['bos'].toString(), colorScheme.onSurfaceVariant),
                          ],
                        ),
                      ],
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
  
  Widget _resultChip(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // Pasta grafiği dilimlerini oluşturan fonksiyon - geliştirilmiş
  List<PieChartSectionData> _createPieChartSections(BuildContext context) {
    final List<Color> colors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF10B981), // Green
      const Color(0xFFF59E0B), // Orange
      const Color(0xFFA855F7), // Purple
      const Color(0xFFEF4444), // Red
      const Color(0xFF14B8A6), // Teal
      const Color(0xFFEC4899), // Pink
      const Color(0xFFFBBF24), // Amber
      const Color(0xFF6366F1), // Indigo
      const Color(0xFFA16207), // Brown
    ];
    int colorIndex = 0;

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    // Pozitif net değeri olan dersleri al ve sırala
    final validEntries = test.scores.entries
      .where((entry) {
        final net = entry.value['dogru']! - (entry.value['yanlis']! * test.penaltyCoefficient);
        return net > 0;
      })
      .toList()
      ..sort((a, b) {
        final netA = a.value['dogru']! - (a.value['yanlis']! * test.penaltyCoefficient);
        final netB = b.value['dogru']! - (b.value['yanlis']! * test.penaltyCoefficient);
        return netB.compareTo(netA);
      });

    return validEntries.map((entry) {
      final subjectNet = entry.value['dogru']! - (entry.value['yanlis']! * test.penaltyCoefficient);
      final color = colors[colorIndex % colors.length];
      
      // Sadece net değerini göster, ders adını gösterme (çakışmayı önlemek için)
      final section = PieChartSectionData(
        value: subjectNet,
        title: subjectNet.toStringAsFixed(1),
        radius: 90,
        color: color,
        titleStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: Colors.white,
          fontSize: 13,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.5),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
        badgeWidget: null,
        titlePositionPercentageOffset: 0.55,
      );
      colorIndex++;
      return section;
    }).toList();
  }

  // İstatistik kolonu oluşturan yardımcı widget - geliştirilmiş
  Widget _buildStatColumn(String label, String value, BuildContext context, {bool isHeader = false, Color? color}) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final statColor = color ?? (isHeader ? colorScheme.primary : colorScheme.onSurface);

    return Column(
      children: [
        Text(
          value,
          style: (isHeader ? textTheme.headlineMedium : textTheme.titleLarge)?.copyWith(
            color: statColor,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}