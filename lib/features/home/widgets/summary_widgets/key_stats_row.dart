// lib/features/home/widgets/summary_widgets/key_stats_row.dart
import 'package:flutter/material.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/models/test_model.dart';

class KeyStatsRow extends StatelessWidget {
  final TestModel test;
  const KeyStatsRow({super.key, required this.test});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatColumn(label: "Toplam Net", value: test.totalNet.toStringAsFixed(2)),
            _StatColumn(label: "Doğru", value: test.totalCorrect.toString(), color: AppTheme.successColor),
            _StatColumn(label: "Yanlış", value: test.totalWrong.toString(), color: AppTheme.accentColor),
            _StatColumn(label: "Boş", value: test.totalBlank.toString(), color: AppTheme.secondaryTextColor),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatColumn({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color ?? Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor)),
      ],
    );
  }
}