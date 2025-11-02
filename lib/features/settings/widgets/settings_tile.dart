// lib/features/settings/widgets/settings_tile.dart
import 'package:flutter/material.dart';
import 'package:taktik/core/theme/app_theme.dart';

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
      leading: Icon(icon, color: iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(
        title,
        style: TextStyle(
            fontWeight: FontWeight.bold, color: textColor ?? Theme.of(context).colorScheme.onSurface),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: onTap != null
          ? Icon(Icons.arrow_forward_ios_rounded,
          size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}