// lib/features/stats/screens/subject_stats_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:taktik/features/stats/logic/stats_analysis.dart'; // HATA DÜZELTİLDİ: EKSİK IMPORT EKLENDİ

class SubjectStatsScreen extends StatelessWidget {
  final String subjectName;
  final SubjectAnalysis analysis;

  const SubjectStatsScreen({
    super.key,
    required this.subjectName,
    required this.analysis,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('$subjectName Cephesi'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text('Cephe Raporu', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.8,
            children: [
              _StatTile(label: 'Ortalama Net', value: analysis.averageNet.toStringAsFixed(2)),
              _StatTile(label: 'En Yüksek Net', value: analysis.bestNet.toStringAsFixed(2)),
              _StatTile(label: 'En Düşük Net', value: analysis.worstNet.toStringAsFixed(2)),
              _StatTile(label: 'Yükseliş Hızı', value: analysis.trend.toStringAsFixed(2)),
            ],
          ),
          const SizedBox(height: 24),
          Text('Netlerin Evrimi', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildSubjectNetChart(context),
        ],
      ),
    );
  }

  Widget _buildSubjectNetChart(BuildContext context) {
    final spots = analysis.netSpots;
    final testCount = analysis.subjectTests.length;

    // Y ekseni için min/max hesapla
    double minY = 0, maxY = 1;
    if (spots.isNotEmpty) {
      minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
      maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
      final range = maxY - minY;
      final padding = range == 0 ? 5.0 : (range * 0.15);
      minY = (minY - padding).clamp(0, double.infinity);
      maxY = maxY + padding;
    }

    return Container(
      height: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).cardColor,
            Theme.of(context).cardColor.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 12, 12),
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: ((maxY - minY) / 4).abs(),
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(0),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= testCount) return const SizedBox.shrink();

                      bool shouldShow = false;
                      if (testCount <= 6) {
                        shouldShow = true;
                      } else if (testCount <= 15) {
                        final interval = (testCount / 4).floor();
                        shouldShow = i == 0 || i == testCount - 1 || i % interval == 0;
                      } else if (testCount <= 30) {
                        final middle = (testCount / 2).floor();
                        shouldShow = i == 0 || i == testCount - 1 || i == middle;
                      } else {
                        shouldShow = i == 0 || i == testCount - 1;
                      }

                      if (!shouldShow) return const SizedBox.shrink();

                      final date = analysis.subjectTests[i].date;
                      final format = testCount > 50 ? DateFormat.yM('tr') : DateFormat.MMMd('tr');

                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          format.format(date),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: testCount > 50 ? 10 : 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  maxContentWidth: 200,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  getTooltipColor: (spot) => Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
                  getTooltipItems: (spots) => spots.map((spot) {
                    final test = analysis.subjectTests[spot.spotIndex];
                    final scores = test.scores[subjectName]!;
                    final correct = scores['dogru'] ?? 0;
                    final wrong = scores['yanlis'] ?? 0;
                    final net = correct - (wrong * test.penaltyCoefficient);
                    final total = correct + wrong;
                    final accuracy = total > 0 ? (correct / total * 100) : 0.0;
                    final text = '${test.testName}\n${DateFormat.yMd('tr').format(test.date)}\n\nNet: ${net.toStringAsFixed(2)}\nDoğru: $correct | Yanlış: $wrong\nİsabet: %${accuracy.toStringAsFixed(0)}';
                    return LineTooltipItem(
                      text,
                      TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: testCount <= 20,
                  curveSmoothness: 0.35,
                  gradient: LinearGradient(
                    colors: [
                      Colors.green,
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.95),
                    ],
                  ),
                  barWidth: testCount > 50 ? 2.5 : 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: testCount <= 30,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: testCount > 15 ? 3 : 4,
                        color: Colors.green,
                        strokeColor: Theme.of(context).cardColor,
                        strokeWidth: 2,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.20),
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}