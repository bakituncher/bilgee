// lib/features/coach/screens/analysis_strategy_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnalysisStrategyScreen extends StatelessWidget {
  const AnalysisStrategyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Analiz & Strateji',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Premium Hero Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            colorScheme.primaryContainer.withOpacity(0.3),
                            colorScheme.secondaryContainer.withOpacity(0.2),
                          ]
                        : [
                            colorScheme.primaryContainer.withOpacity(0.6),
                            colorScheme.secondaryContainer.withOpacity(0.4),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.2),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const CircleAvatar(
                        backgroundColor: Colors.transparent,
                        radius: 48,
                        backgroundImage: AssetImage('assets/images/bunnyy.png'),
                      ),
                    ).animate().fadeIn(duration: 300.ms).scale(delay: 100.ms),
                    const SizedBox(height: 24),
                    Text(
                      'Analiz & Strateji Merkezi',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),
                    const SizedBox(height: 12),
                    Text(
                      'Verilerini eyleme dönüştür. Taktik Tavşan ile eksiklerini bul, başarıyı şansa bırakma! 🚀',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 300.ms),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms).scale(),

              const SizedBox(height: 32),

              // Premium Feature Cards
              _SuiteButton(
                icon: Icons.analytics_rounded,
                title: 'Deneme Analizi',
                subtitle: 'Hatalarını keşfet. Eksiklerini MR gibi tarayalım, netlerini artıralım. 💡',
                onTap: () => context.push('/ai-hub/motivation-chat', extra: 'trial_review'),
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF6B4226), const Color(0xFF8B5A2B)]
                      : [const Color(0xFFFFD54F), const Color(0xFFFFB300)],
                ),
                accentColor: isDark ? const Color(0xFFFFD54F) : const Color(0xFFFF8F00),
              ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.2, curve: Curves.easeOutCubic),

              const SizedBox(height: 16),

              _SuiteButton(
                icon: Icons.rocket_launch_rounded,
                title: 'Strateji Danışma',
                subtitle: 'Stratejik program ve kişiye özel yol haritası. Planla ve kazan! 🔥',
                onTap: () => context.push('/ai-hub/motivation-chat', extra: 'strategy_consult'),
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1A4D6D), const Color(0xFF2563A8)]
                      : [const Color(0xFF42A5F5), const Color(0xFF1E88E5)],
                ),
                accentColor: isDark ? const Color(0xFF64B5F6) : const Color(0xFF0D47A1),
              ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.2, curve: Curves.easeOutCubic),

              const SizedBox(height: 32),

              // Pro Tips Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_rounded,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pro İpucu',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sık sık deneme ekleyerek Taktik Tavşan\'ın seni daha iyi tanımasını sağla! Level atlama zamanı!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuiteButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Gradient gradient;
  final Color accentColor;

  const _SuiteButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.gradient,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(isDark ? 0.15 : 0.25),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isDark ? Colors.white : Colors.white.withOpacity(0.95),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.white,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? Colors.white.withOpacity(0.85)
                            : Colors.white.withOpacity(0.9),
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
