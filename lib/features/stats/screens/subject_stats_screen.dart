// lib/features/stats/screens/subject_stats_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/features/stats/logic/stats_analysis.dart'; // HATA DÜZELTİLDİ: EKSİK IMPORT EKLENDİ

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
            childAspectRatio: 2.5,
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
    return SizedBox(
      height: 250,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(color: AppTheme.lightSurfaceColor.withOpacity(0.3), strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => AppTheme.primaryColor.withOpacity(0.9),
                  getTooltipItems: (spots) => spots.map((spot) {
                    final test = analysis.subjectTests[spot.spotIndex];
                    final scores = test.scores[subjectName]!;
                    final net = (scores['dogru'] ?? 0) - ((scores['yanlis'] ?? 0) * test.penaltyCoefficient);
                    final text = '${test.testName}\n${DateFormat.yMd('tr').format(test.date)}\n${net.toStringAsFixed(2)} Net';
                    return LineTooltipItem(text, const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: analysis.netSpots,
                  isCurved: true,
                  color: AppTheme.successColor,
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [AppTheme.successColor.withOpacity(0.3), AppTheme.successColor.withOpacity(0)],
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
      color: AppTheme.lightSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}