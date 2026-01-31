// lib/shared/screens/force_update_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:taktik/core/services/version_check_service.dart';

/// Zorunlu güncelleme ekranı - Kullanıcı uygulamayı güncellemeden devam edemez
class ForceUpdateScreen extends StatelessWidget {
  final VersionCheckResult versionInfo;

  const ForceUpdateScreen({
    super.key,
    required this.versionInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animation
              Lottie.asset(
                'assets/lotties/Data Analysis.json',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Güncelleme Gerekli',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Message
              Text(
                versionInfo.updateMessage ??
                'Uygulamayı kullanmaya devam etmek için lütfen en son sürüme güncelleyin.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Update button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _openStore(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.system_update_alt, size: 24),
                  label: Text(
                    'Şimdi Güncelle',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _openStore(BuildContext context) async {
    try {
      Uri? storeUrl;

      if (Platform.isAndroid) {
        // Google Play Store
        storeUrl = Uri.parse('https://play.google.com/store/apps/details?id=com.codenzi.taktik');
      } else if (Platform.isIOS) {
        // App Store - ID'nizi buraya ekleyin
        storeUrl = Uri.parse('https://apps.apple.com/app/id6739040808');
      }

      if (storeUrl != null && await canLaunchUrl(storeUrl)) {
        await launchUrl(storeUrl, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mağaza açılamadı. Lütfen manuel olarak güncelleyin.'),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString()}'),
          ),
        );
      }
    }
  }
}

