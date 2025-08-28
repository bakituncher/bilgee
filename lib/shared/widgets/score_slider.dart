// lib/shared/widgets/score_slider.dart
import 'package:flutter/material.dart';

class ScoreSlider extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;
  final Function(double) onChanged;

  const ScoreSlider({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$label: ${value.toInt()}", style: Theme.of(context).textTheme.titleLarge),
        Slider(
          value: value,
          max: max < 0 ? 0 : max,
          divisions: max.toInt() > 0 ? max.toInt() : 1,
          label: value.toInt().toString(),
          activeColor: color,
          inactiveColor: color.withValues(alpha: 0.3),
          onChanged: onChanged,
        ),
      ],
    );
  }
}