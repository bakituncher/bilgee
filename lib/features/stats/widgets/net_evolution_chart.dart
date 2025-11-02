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

  // Büyük veri setleri için akıllı örnekleme
  List<FlSpot> _getSampledSpots(List<FlSpot> originalSpots) {
    if (originalSpots.length <= 50) return originalSpots;

    // 100+ test varsa, akıllı örnekleme yap
    final sampledSpots = <FlSpot>[];
    final step = originalSpots.length / 50;

    for (int i = 0; i < originalSpots.length; i++) {
      // İlk, son ve her step'te bir nokta ekle
      if (i == 0 || i == originalSpots.length - 1 || i % step.ceil() == 0) {
        sampledSpots.add(FlSpot(i.toDouble(), originalSpots[i].y));
      }
    }

    return sampledSpots;
  }

  @override
  Widget build(BuildContext context) {
    final originalSpots = widget.analysis.netSpots;
    final spots = _getSampledSpots(originalSpots);
    final hasData = spots.isNotEmpty;

    double minY = 0, maxY = 1;
    if (hasData) {
      minY = originalSpots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
      maxY = originalSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b);

      // Dinamik padding - veri aralığına göre ayarla
      final range = maxY - minY;
      final padding = range == 0 ? 5.0 : (range * 0.15);
      minY = (minY - padding).clamp(0, double.infinity);
      maxY = maxY + padding;

      if (minY == maxY) {
        minY = (minY - 5).clamp(0, double.infinity);
        maxY = maxY + 5;
      }
    }

    return Container(
      height: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).cardColor,
            Theme.of(context).cardColor.withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
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
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.25),
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
                        if (i < 0 || i >= widget.analysis.sortedTests.length) return const SizedBox.shrink();

                        final totalTests = widget.analysis.sortedTests.length;
                        bool shouldShow = false;

                        if (totalTests <= 6) {
                          // 6 ve altı: hepsini göster
                          shouldShow = true;
                        } else if (totalTests <= 15) {
                          // 7-15: ilk, son ve 2 ara nokta
                          final interval = (totalTests / 4).floor();
                          shouldShow = i == 0 || i == totalTests - 1 || i % interval == 0;
                        } else if (totalTests <= 30) {
                          // 16-30: ilk, son ve 1 orta nokta
                          final middle = (totalTests / 2).floor();
                          shouldShow = i == 0 || i == totalTests - 1 || i == middle;
                        } else {
                          // 31+: sadece ilk ve son
                          shouldShow = i == 0 || i == totalTests - 1;
                        }

                        if (!shouldShow) return const SizedBox.shrink();

                        final date = widget.analysis.sortedTests[i].date;
                        // 50+ test varsa sadece ay/yıl göster
                        final format = totalTests > 50 ? DateFormat.yM('tr') : DateFormat.MMMd('tr');

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            format.format(date),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: totalTests > 50 ? 10 : 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                    getTooltipColor: (spot) => Theme.of(context).colorScheme.primary.withOpacity(0.96),
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
                    isCurved: originalSpots.length <= 20, // 20+ testte düz çizgi daha okunabilir
                    curveSmoothness: 0.35,
                    barWidth: originalSpots.length > 50 ? 2.5 : 3,
                    isStrokeCapRound: true,
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.secondary,
                        Theme.of(context).colorScheme.secondary.withOpacity(0.95),
                      ],
                    ),
                    dotData: FlDotData(
                      show: originalSpots.length <= 30, // 30+ testte noktaları gizle
                      getDotPainter: (spot, percent, barData, index) {
                        if (index >= widget.analysis.sortedTests.length) {
                          return FlDotCirclePainter(
                            radius: 0,
                            color: Colors.transparent,
                          );
                        }

                        final test = widget.analysis.sortedTests[index];
                        final total = (test.totalCorrect + test.totalWrong);
                        final accuracy = total == 0 ? 0.0 : (test.totalCorrect / total);
                        final isTouched = _touchedIndex == index;

                        // Büyük veri setlerinde sadece dokunulan noktayı vurgula
                        if (originalSpots.length > 15 && !isTouched) {
                          return FlDotCirclePainter(
                            radius: 2.5,
                            color: Color.lerp(Theme.of(context).colorScheme.error, Theme.of(context).colorScheme.secondary, accuracy)!,
                            strokeWidth: 0,
                          );
                        }

                        return FlDotCirclePainter(
                          radius: isTouched ? 6.5 : 4,
                          color: Color.lerp(Theme.of(context).colorScheme.error, Theme.of(context).colorScheme.secondary, accuracy)!,
                          strokeColor: isTouched ? Colors.white : Theme.of(context).cardColor,
                          strokeWidth: isTouched ? 3 : 2,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.secondary.withOpacity(0.20),
                          Theme.of(context).colorScheme.secondary.withOpacity(0.04),
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
                Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                Theme.of(context).colorScheme.secondary.withOpacity(0.05),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.show_chart_rounded,
            color: Theme.of(context).colorScheme.secondary,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Henüz Veri Yok',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Deneme ekledikçe grafiğin oluşacak',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

