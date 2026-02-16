// lib/features/home/widgets/summary_widgets/key_stats_row.dart
import 'package:flutter/material.dart';
import 'package:taktik/data/models/test_model.dart';

class KeyStatsRow extends StatelessWidget {
  final TestModel test;
  const KeyStatsRow({super.key, required this.test});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _CompactStat(
            label: "Toplam Net",
            value: test.totalNet.toStringAsFixed(1),
            color: const Color(0xFF2E3192),
            isDark: isDark,
          )),
          _verticalDivider(isDark),
          Expanded(child: _CompactStat(
            label: "Doğru",
            value: test.totalCorrect.toString(),
            color: const Color(0xFF00C853),
            isDark: isDark,
          )),
          _verticalDivider(isDark),
          Expanded(child: _CompactStat(
            label: "Yanlış",
            value: test.totalWrong.toString(),
            color: const Color(0xFFFF5252),
            isDark: isDark,
          )),
          _verticalDivider(isDark),
          Expanded(child: _CompactStat(
            label: "Boş",
            value: test.totalBlank.toString(),
            color: isDark ? Colors.white54 : Colors.grey,
            isDark: isDark,
          )),
        ],
      ),
    );
  }

  Widget _verticalDivider(bool isDark) => Container(
    width: 1,
    height: 36,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
  );
}

class _CompactStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _CompactStat({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }
}