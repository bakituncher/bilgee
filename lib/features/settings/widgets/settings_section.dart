// lib/features/settings/widgets/settings_section.dart
import 'package:flutter/material.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  const SettingsSection({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0, left: 16.0),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.secondaryTextColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}