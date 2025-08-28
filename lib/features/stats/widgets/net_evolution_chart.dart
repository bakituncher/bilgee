// lib/features/stats/widgets/net_evolution_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/features/stats/logic/stats_analysis.dart';

class NetEvolutionChart extends StatelessWidget {
  final StatsAnalysis analysis;
  const NetEvolutionChart({required this.analysis, super.key});

  @override
  Widget build(BuildContext context) {
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
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => AppTheme.primaryColor.withOpacity(0.9),
                  getTooltipItems: (spots) => spots.map((spot) {
                    final test = analysis.sortedTests[spot.spotIndex];
                    final accuracy = (test.totalCorrect + test.totalWrong) == 0 ? 0.0 : (test.totalCorrect / (test.totalCorrect + test.totalWrong));
                    final text = '${test.testName}\n${DateFormat.yMd('tr').format(test.date)}\n${test.totalNet.toStringAsFixed(2)} Net (%${(accuracy * 100).toStringAsFixed(0)} isabet)';
                    return LineTooltipItem(text, const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: analysis.netSpots,
                  isCurved: true,
                  gradient: const LinearGradient(colors: [AppTheme.successColor, AppTheme.secondaryColor]),
                  barWidth: 5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      final test = analysis.sortedTests[index];
                      final accuracy = (test.totalCorrect + test.totalWrong) == 0 ? 0.0 : (test.totalCorrect / (test.totalCorrect + test.totalWrong));
                      return FlDotCirclePainter(
                        radius: 6,
                        color: Color.lerp(AppTheme.accentColor, AppTheme.successColor, accuracy)!,
                        strokeColor: AppTheme.cardColor,
                        strokeWidth: 2,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [AppTheme.secondaryColor.withOpacity(0.3), AppTheme.secondaryColor.withOpacity(0)],
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