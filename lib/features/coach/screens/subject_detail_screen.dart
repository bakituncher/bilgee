// lib/features/coach/screens/subject_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bilge_ai/data/models/test_model.dart';

class SubjectDetailScreen extends ConsumerWidget {
  final String subject;
  const SubjectDetailScreen({super.key, required this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testsAsync = ref.watch(testsProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('$subject Dersi Analizi'),
      ),
      body: testsAsync.when(
        data: (tests) {
          final List<TestModel> relevantTests = tests
              .where((t) => t.scores.containsKey(subject))
              .toList()
              .reversed.toList();

          if (relevantTests.isEmpty) {
            return const Center(child: Text('Bu derse ait deneme bulunamadı.'));
          }

          final List<FlSpot> spots = [];
          for (int i = 0; i < relevantTests.length; i++) {
            final test = relevantTests[i];
            final net = test.scores[subject]!['dogru']! - (test.scores[subject]!['yanlis']! * test.penaltyCoefficient);
            spots.add(FlSpot(i.toDouble(), net));
          }

          final nets = spots.map((s) => s.y).toList();
          final avgNet = nets.reduce((a, b) => a + b) / nets.length;
          final maxNet = nets.reduce((a, b) => a > b ? a : b);


          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Net Değişim Grafiği', style: textTheme.titleLarge),
              const SizedBox(height: 16),
              SizedBox(
                height: 250,
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Theme.of(context).colorScheme.secondary,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Theme.of(context).colorScheme.secondary.withAlpha(51), // ~0.2 opacity
                          )
                      )
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: (spots.length / 5).ceilToDouble(),
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < relevantTests.length) {
                              final date = relevantTests[index].date;
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(DateFormat('d MMM').format(date)),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                  ),
                ).animate().fadeIn(duration: 500.ms),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildStatCard('Ortalama Net', avgNet.toStringAsFixed(2), Icons.track_changes, context)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('En Yüksek Net', maxNet.toStringAsFixed(2), Icons.emoji_events, context)),
                ],
              )
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Veri yüklenirken hata oluştu: $e')),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.secondary),
            const SizedBox(height: 8),
            Text(label, style: textTheme.bodyMedium),
            Text(value, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    ).animate().scale(delay: 200.ms);
  }
}