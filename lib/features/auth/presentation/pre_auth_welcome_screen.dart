import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/data/providers/shared_prefs_provider.dart';

class PreAuthWelcomeScreen extends ConsumerWidget {
  const PreAuthWelcomeScreen({super.key});

  Future<void> _continue(BuildContext context, WidgetRef ref) async {
    // Set the flag in SharedPreferences
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool('hasSeenWelcomeScreen', true);

    // Navigate to the login screen
    if (context.mounted) {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.primary.withOpacity(0.08),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 120,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Taktik\'e Hoş Geldin!',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Yapay zeka destekli kişisel öğrenme koçunla tanışmaya hazır mısın?',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 48),
                  _FeatureHighlight(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Kişiye Özel Yapay Zeka Koçu',
                    subtitle: 'Seni anlayan, zayıf yönlerini belirleyen ve sana özel stratejiler üreten koçun.',
                  ),
                  const SizedBox(height: 24),
                  _FeatureHighlight(
                    icon: Icons.bar_chart_rounded,
                    title: 'Detaylı Performans Analizi',
                    subtitle: 'Her deneme sonrası netlerini, konu başarılarını ve gelişimini takip et.',
                  ),
                  const SizedBox(height: 24),
                  _FeatureHighlight(
                    icon: Icons.checklist_rtl_rounded,
                    title: 'Stratejik Planlama',
                    subtitle: 'Haftalık ve günlük hedeflerini belirle, zamanını en verimli şekilde kullan.',
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () => _continue(context, ref),
                    style: theme.elevatedButtonTheme.style?.copyWith(
                      minimumSize: MaterialStateProperty.all(const Size(0, 52)),
                    ),
                    child: const Text('Hadi Başlayalım!'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureHighlight extends StatelessWidget {
  const _FeatureHighlight({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 28,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
