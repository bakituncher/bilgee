import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/data/providers/shared_prefs_provider.dart';

class PreAuthWelcomeScreen extends ConsumerStatefulWidget {
  const PreAuthWelcomeScreen({super.key});

  @override
  ConsumerState<PreAuthWelcomeScreen> createState() => _PreAuthWelcomeScreenState();
}

class _PreAuthWelcomeScreenState extends ConsumerState<PreAuthWelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue(BuildContext context) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool('hasSeenWelcomeScreen', true);

    if (context.mounted) {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              theme.colorScheme.primary.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            // Logo
                            Image.asset(
                              'assets/images/splash.png',
                              height: 120,
                            ),
                            const SizedBox(height: 48),
                            // Title
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.secondary,
                                ],
                              ).createShader(bounds),
                              child: Text(
                                'Taktik\'e Hoş Geldin!',
                                textAlign: TextAlign.center,
                                style: textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  fontSize: 32,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Subtitle
                            Text(
                              'Kişisel koçunla tanışmaya hazır mısın?',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 56),
                            // Features
                            _FeatureCard(
                              icon: Icons.auto_awesome_rounded,
                              title: 'Kişiye Özel Eğitim Koçu',
                              subtitle: 'Seni anlayan, zayıf yönlerini belirleyen ve sana özel stratejiler üreten koçun.',
                            ),
                            const SizedBox(height: 16),
                            _FeatureCard(
                              icon: Icons.bar_chart_rounded,
                              title: 'Detaylı Performans Analizi',
                              subtitle: 'Her deneme sonrası netlerini, konu başarılarını ve gelişimini takip et.',
                            ),
                            const SizedBox(height: 16),
                            _FeatureCard(
                              icon: Icons.checklist_rtl_rounded,
                              title: 'Haftalık Planlama',
                              subtitle: 'Haftalık ve günlük hedeflerini belirle, zamanını en verimli şekilde kullan.',
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                    // Button - sabit pozisyonda
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _continue(context),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Hadi Başlayalım',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

