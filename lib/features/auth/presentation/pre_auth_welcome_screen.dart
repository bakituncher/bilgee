import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surface,
              colorScheme.primary.withOpacity(0.05),
              colorScheme.secondary.withOpacity(0.08),
            ],
            stops: const [0.0, 0.5, 1.0],
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
                  // Logo with animation
                  Hero(
                    tag: 'app_logo',
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 120,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .scale(begin: const Offset(0.8, 0.8), duration: 600.ms, curve: Curves.easeOutBack)
                      .then()
                      .shimmer(delay: 200.ms, duration: 1200.ms),
                  
                  const SizedBox(height: 32),
                  
                  // Main title with gradient
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.secondary,
                      ],
                    ).createShader(bounds),
                    child: Text(
                      'Başarıya Giden\nYolda Yanındayız! 🚀',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 300.ms, duration: 600.ms)
                      .slideY(begin: 0.3, delay: 300.ms, duration: 600.ms),
                  
                  const SizedBox(height: 16),
                  
                  // Subtitle
                  Text(
                    'Yapay zeka destekli kişisel koçunla\nsınavlarda fark yarat!',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 500.ms, duration: 600.ms)
                      .slideY(begin: 0.3, delay: 500.ms, duration: 600.ms),
                  
                  const SizedBox(height: 48),
                  
                  // Feature cards with enhanced design
                  const _FeatureCard(
                    icon: Icons.psychology_rounded,
                    gradient: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    title: 'Akıllı AI Koç 🤖',
                    subtitle: 'Seni anlayan, zayıf yönlerini analiz eden ve özel stratejiler geliştiren yapay zeka koçun.',
                    delay: 700,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  const _FeatureCard(
                    icon: Icons.trending_up_rounded,
                    gradient: [Color(0xFFEC4899), Color(0xFFF97316)],
                    title: 'Gelişim Takibi 📊',
                    subtitle: 'Her deneme sonrası detaylı analiz, konu bazlı performans takibi ve ilerleme raporları.',
                    delay: 850,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  const _FeatureCard(
                    icon: Icons.calendar_today_rounded,
                    gradient: [Color(0xFF10B981), Color(0xFF14B8A6)],
                    title: 'Kişisel Plan 📅',
                    subtitle: 'Haftalık ve günlük özel çalışma programın, akıllı hatırlatıcılar ve hedef takibi.',
                    delay: 1000,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  const _FeatureCard(
                    icon: Icons.emoji_events_rounded,
                    gradient: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                    title: 'Rekabet & Motivasyon 🏆',
                    subtitle: 'Lider tablosu, rozet sistemi ve günlük görevlerle motivasyonunu her zaman yüksek tut!',
                    delay: 1150,
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // CTA Button with enhanced styling
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.secondary,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => _continue(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Hemen Başla',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 24),
                        ],
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 1300.ms, duration: 600.ms)
                      .slideY(begin: 0.3, delay: 1300.ms, duration: 600.ms)
                      .then()
                      .shimmer(delay: 500.ms, duration: 1500.ms),
                  
                  const SizedBox(height: 24),
                  
                  // Trust badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Binlerce öğrenci başarıya ulaştı',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(delay: 1500.ms, duration: 600.ms),
                ],
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
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.delay,
  });

  final IconData icon;
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark 
            ? theme.cardColor.withOpacity(0.5)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? theme.colorScheme.primary.withOpacity(0.2)
              : theme.colorScheme.primary.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon with gradient background
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
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
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: delay.ms, duration: 600.ms)
        .slideX(begin: 0.2, delay: delay.ms, duration: 600.ms, curve: Curves.easeOutCubic);
  }
}
