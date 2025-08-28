// lib/features/home/widgets/dashboard_widgets/motivational_quote_card.dart
import 'package:flutter/material.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';

class MotivationalQuoteCard extends StatelessWidget {
  final String quote;
  const MotivationalQuoteCard({super.key, required this.quote});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.format_quote, color: AppTheme.secondaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                quote,
                style: const TextStyle(color: AppTheme.secondaryTextColor, fontStyle: FontStyle.italic, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}