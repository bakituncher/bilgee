// lib/features/settings/widgets/settings_tile.dart
import 'package:flutter/material.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: iconColor ?? AppTheme.secondaryTextColor),
      title: Text(
        title,
        style: TextStyle(
            fontWeight: FontWeight.bold, color: textColor ?? AppTheme.textColor),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.secondaryTextColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: onTap != null
          ? const Icon(Icons.arrow_forward_ios_rounded,
          size: 16, color: AppTheme.secondaryTextColor)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}