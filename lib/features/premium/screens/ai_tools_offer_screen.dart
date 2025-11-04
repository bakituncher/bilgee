// lib/features/premium/screens/ai_tools_offer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/providers/activity_tracker_provider.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Ultra-kompakt AI Tools tanıtım ekranı
class AIToolsOfferScreen extends ConsumerStatefulWidget {
  const AIToolsOfferScreen({super.key});

  @override
  ConsumerState<AIToolsOfferScreen> createState() => _AIToolsOfferScreenState();
}

class _AIToolsOfferScreenState extends ConsumerState<AIToolsOfferScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activityTrackerProvider).markToolOfferShown();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(premiumStatusProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A14) : const Color(0xFFFAFBFF),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF1A1A2E), const Color(0xFF0A0A14)]
                    : [Colors.white, const Color(0xFFF5F7FF)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildHeader(theme),
                  _buildFeatures(theme, isDark, isPremium),
                  _buildActions(theme, isPremium),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              onPressed: _handleClose,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome_rounded, size: 40, color: Colors.white),
        ).animate().scale(delay: 100.ms, duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 32),
        Text(
          'Harika İleriyorsun! 🎯',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 12),
        Text(
          'Yapay zeka asistanın seni bekliyor',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 300.ms),
      ],
    );
  }

  Widget _buildFeatures(ThemeData theme, bool isDark, bool isPremium) {
    return Column(
      children: [
        _buildFeatureCard(theme, isDark, Icons.psychology_rounded, 'AI Koçu',
            'Kişisel analiz & öneriler', Colors.purple, !isPremium)
            .animate().fadeIn(delay: 400.ms).slideX(begin: -0.2, end: 0),
        const SizedBox(height: 12),
        _buildFeatureCard(theme, isDark, Icons.insights_rounded, 'Akıllı Analiz',
            'Detaylı performans raporları', Colors.blue, !isPremium)
            .animate().fadeIn(delay: 500.ms).slideX(begin: -0.2, end: 0),
        const SizedBox(height: 12),
        _buildFeatureCard(theme, isDark, Icons.trending_up_rounded, 'Strateji Planlama',
            'Hedef odaklı çalışma programı', Colors.orange, !isPremium)
            .animate().fadeIn(delay: 600.ms).slideX(begin: -0.2, end: 0),
      ],
    );
  }

  Widget _buildFeatureCard(ThemeData theme, bool isDark, IconData icon,
      String title, String subtitle, Color color, bool showPro) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.08) : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (showPro)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ThemeData theme, bool isPremium) {
    return Column(
      children: [
        if (!isPremium)
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push('/premium'),
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Premium\'a Geç',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.3, end: 0),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            if (isPremium) {
              context.go(AppRoutes.coach);
            } else {
              _handleClose();
            }
          },
          style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          child: Text(
            isPremium ? '🚀 Koça Git' : 'Daha Sonra',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ).animate().fadeIn(delay: 800.ms),
      ],
    );
  }

  void _handleClose() {
    if (context.mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
    }
  }
}

