// lib/features/stats/widgets/net_evolution_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/features/stats/logic/stats_analysis.dart';

class NetEvolutionChart extends StatelessWidget {
  final StatsAnalysis analysis;
  const NetEvolutionChart({required this.analysis, super.key});

  @override
  Widget build(BuildContext context) {
    final spots = analysis.netSpots;
    final hasData = spots.isNotEmpty;

    double minY = 0, maxY = 1;
    if (hasData) {
      minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
      maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
      // Y eksenini biraz pad edelim ki çizgi kenarlara yapışmasın
      final padding = ((maxY - minY).abs() * 0.15) + 1;
      minY = (minY - padding);
      maxY = (maxY + padding);
      if (minY == maxY) {
        minY -= 1;
        maxY += 1;
      }
    }

    return SizedBox(
      height: 260,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        child: RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: hasData
                ? LineChart(
                    LineChartData(
                      minY: minY,
                      maxY: maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: AppTheme.lightSurfaceColor.withOpacity(0.25),
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
                                      color: AppTheme.secondaryTextColor,
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
                            reservedSize: 28,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= analysis.sortedTests.length) return const SizedBox.shrink();
                              // İlk, orta ve son için etiket gösterelim
                              final isEdge = i == 0 || i == analysis.sortedTests.length - 1;
                              final isMiddle = i == (analysis.sortedTests.length / 2).floor();
                              if (!(isEdge || isMiddle)) return const SizedBox.shrink();
                              final date = analysis.sortedTests[i].date;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  DateFormat.Md('tr').format(date),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.secondaryTextColor,
                                      ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        handleBuiltInTouches: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (spot) => AppTheme.primaryColor.withOpacity(0.95),
                          getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                            final test = analysis.sortedTests[spot.spotIndex];
                            final total = (test.totalCorrect + test.totalWrong);
                            final accuracy = total == 0 ? 0.0 : (test.totalCorrect / total);
                            final text = '${test.testName}\n${DateFormat.yMd('tr').format(test.date)}\nNet: ${test.totalNet.toStringAsFixed(2)}  |  İsabet: %${(accuracy * 100).toStringAsFixed(0)}';
                            return LineTooltipItem(
                              text,
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            );
                          }).toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          // Daha ince, daha modern çizgi
                          barWidth: 3,
                          isStrokeCapRound: true,
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.successColor,
                              AppTheme.secondaryColor.withOpacity(0.95),
                            ],
                          ),
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              final test = analysis.sortedTests[index];
                              final total = (test.totalCorrect + test.totalWrong);
                              final accuracy = total == 0 ? 0.0 : (test.totalCorrect / total);
                              return FlDotCirclePainter(
                                radius: 4.2,
                                color: Color.lerp(AppTheme.accentColor, AppTheme.successColor, accuracy)!,
                                strokeColor: AppTheme.cardColor,
                                strokeWidth: 1.8,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.secondaryColor.withOpacity(0.20),
                                AppTheme.secondaryColor.withOpacity(0.04),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : _EmptyChartPlaceholder(),
          ),
        ),
      ),
    );
  }
}

class _EmptyChartPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.show_chart_rounded, color: AppTheme.secondaryTextColor.withOpacity(0.6)),
        const SizedBox(height: 8),
        Text(
          'Grafik için yeterli veri yok',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor),
        ),
      ],
    );
  }
}
