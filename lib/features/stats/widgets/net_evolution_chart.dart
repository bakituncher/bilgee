// lib/features/stats/widgets/net_evolution_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/features/stats/logic/stats_analysis.dart';

class NetEvolutionChart extends StatefulWidget {
  final StatsAnalysis analysis;
  const NetEvolutionChart({required this.analysis, super.key});

  @override
  State<NetEvolutionChart> createState() => _NetEvolutionChartState();
}

class _NetEvolutionChartState extends State<NetEvolutionChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final spots = widget.analysis.netSpots;
    final hasData = spots.isNotEmpty;

    double minY = 0, maxY = 1;
    if (hasData) {
      minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
      maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
      // Y eksenini biraz pad edelim ki çizgi kenarlara yapışmasın
      final padding = ((maxY - minY).abs() * 0.20) + 1;
      minY = (minY - padding).clamp(0, double.infinity);
      maxY = (maxY + padding);
      if (minY == maxY) {
        minY -= 1;
        maxY += 1;
      }
    }

    return Container(
      height: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.cardColor,
            AppTheme.cardColor.withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.secondaryColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 12, 12),
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
                            reservedSize: 32,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= widget.analysis.sortedTests.length) return const SizedBox.shrink();

                              // Veri sayısına göre etiket stratejisi
                              final totalTests = widget.analysis.sortedTests.length;
                              bool shouldShow = false;

                              if (totalTests <= 5) {
                                // Az veri varsa hepsini göster
                                shouldShow = true;
                              } else if (totalTests <= 10) {
                                // Orta seviye: ilk, orta ve son
                                final isEdge = i == 0 || i == totalTests - 1;
                                final isMiddle = i == (totalTests / 2).floor();
                                shouldShow = isEdge || isMiddle;
                              } else {
                                // Çok veri: sadece ilk ve son
                                shouldShow = i == 0 || i == totalTests - 1;
                              }

                              if (!shouldShow) return const SizedBox.shrink();

                              final date = widget.analysis.sortedTests[i].date;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  DateFormat.MMMd('tr').format(date),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.secondaryTextColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        handleBuiltInTouches: true,
                        touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                          setState(() {
                            if (touchResponse?.lineBarSpots != null && touchResponse!.lineBarSpots!.isNotEmpty) {
                              _touchedIndex = touchResponse.lineBarSpots!.first.spotIndex;
                            } else {
                              _touchedIndex = null;
                            }
                          });
                        },
                        touchTooltipData: LineTouchTooltipData(
                          maxContentWidth: 200,
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          tooltipRoundedRadius: 12,
                          tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          tooltipMargin: 8,
                          getTooltipColor: (spot) => AppTheme.primaryColor.withOpacity(0.96),
                          getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                            final test = widget.analysis.sortedTests[spot.spotIndex];
                            final total = (test.totalCorrect + test.totalWrong);
                            final accuracy = total == 0 ? 0.0 : (test.totalCorrect / total);
                            final text = '${test.testName}\n${DateFormat.yMd('tr').format(test.date)}\n\nNet: ${test.totalNet.toStringAsFixed(2)}\nİsabet: %${(accuracy * 100).toStringAsFixed(0)}';
                            return LineTooltipItem(
                              text,
                              const TextStyle(
                                color: Colors.white,
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
                              final test = widget.analysis.sortedTests[index];
                              final total = (test.totalCorrect + test.totalWrong);
                              final accuracy = total == 0 ? 0.0 : (test.totalCorrect / total);
                              final isTouched = _touchedIndex == index;
                              return FlDotCirclePainter(
                                radius: isTouched ? 6.5 : 4.5,
                                color: Color.lerp(AppTheme.accentColor, AppTheme.successColor, accuracy)!,
                                strokeColor: isTouched ? Colors.white : AppTheme.cardColor,
                                strokeWidth: isTouched ? 3 : 2,
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.secondaryColor.withOpacity(0.15),
                AppTheme.secondaryColor.withOpacity(0.05),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.show_chart_rounded,
            color: AppTheme.secondaryColor,
            size: 32,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Grafik için yeterli veri yok',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.secondaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
