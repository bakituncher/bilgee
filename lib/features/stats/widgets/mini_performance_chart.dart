// lib/features/stats/widgets/mini_performance_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:taktik/data/models/test_model.dart';

const int maxRecentTests = 8;

/// Mini performans grafiği
class MiniPerformanceChart extends StatelessWidget {
  final List<TestModel> tests;
  final Color color;
  final bool isDark;

  const MiniPerformanceChart({
    super.key,
    required this.tests,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final recentTests = tests.length > maxRecentTests
        ? (tests.toList()..sort((a, b) => b.date.compareTo(a.date)))
        .take(maxRecentTests)
        .toList()
        .reversed
        .toList()
        : (tests.toList()..sort((a, b) => a.date.compareTo(b.date)));

    final nets = recentTests.map((t) => t.totalNet).toList();
    if (nets.isEmpty) return const SizedBox.shrink();

    var minNet = nets[0];
    var maxNet = nets[0];
    for (final net in nets) {
      if (net < minNet) minNet = net;
      if (net > maxNet) maxNet = net;
    }

    final minY = (minNet - 5).clamp(0.0, double.infinity).toDouble();
    final maxY = (maxNet + 5).toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 3,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.03),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (maxY - minY) / 3,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white.withOpacity(0.35)
                          : Colors.black.withOpacity(0.35),
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => color.withOpacity(0.9),
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  spot.y.toStringAsFixed(1),
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (int i = 0; i < nets.length; i++)
                FlSpot(i.toDouble(), nets[i])
            ],
            isCurved: true,
            curveSmoothness: 0.4,
            color: color,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: color,
                  strokeWidth: 2.5,
                  strokeColor: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withOpacity(0.3),
                  color.withOpacity(0.05),
                  color.withOpacity(0.0),
                ],
              ),
            ),
            shadow: Shadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ),
        ],
      ),
    );
  }
}

