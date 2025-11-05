// lib/features/premium/screens/ai_tools_offer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/providers/activity_tracker_provider.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Ultra-şık AI Tools tanıtım ekranı
class AIToolsOfferScreen extends ConsumerStatefulWidget {
  const AIToolsOfferScreen({super.key});

  @override
  ConsumerState<AIToolsOfferScreen> createState() => _AIToolsOfferScreenState();
}

class _AIToolsOfferScreenState extends ConsumerState<AIToolsOfferScreen> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activityTrackerProvider).markToolOfferShown();
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(premiumStatusProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1E) : const Color(0xFFFAFBFF),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1A1A2E),
                    const Color(0xFF16213E),
                    const Color(0xFF0F0F1E),
                  ]
                : [
                    const Color(0xFFFFFFFF),
                    const Color(0xFFF8F9FF),
                    const Color(0xFFF0F4FF),
                  ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Dekoratif arka plan elementleri
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.15),
                        theme.colorScheme.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -80,
                left: -80,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.secondary.withValues(alpha: 0.12),
                        theme.colorScheme.secondary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // Ana içerik
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: size.height * 0.05,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHeader(theme, isDark),
                    _buildFeatures(theme, isDark, isPremium),
                    _buildActions(theme, isDark, isPremium),
                  ],
                ),
              ),

              // Kapat butonu
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleClose,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        size: 20,
                      ),
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

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Column(
      children: [
        // Ana ikon
        Stack(
          alignment: Alignment.center,
          children: [
            // Parlama efekti
            AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, child) {
                return Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.3 * _shimmerController.value),
                        theme.colorScheme.secondary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                );
              },
            ),
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 42,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        )
            .animate()
            .scale(
              delay: 100.ms,
              duration: 700.ms,
              curve: Curves.elasticOut,
            )
            .then()
            .shimmer(
              delay: 800.ms,
              duration: 1500.ms,
            ),

        const SizedBox(height: 28),

        // Başlık
        Text(
          'Harika İlerliyorsun!',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.3, end: 0),

        const SizedBox(height: 8),

        // Emoji
        const Text(
          '🎯',
          style: TextStyle(fontSize: 32),
        ).animate().scale(delay: 400.ms, duration: 600.ms, curve: Curves.elasticOut),

        const SizedBox(height: 16),

        // Alt başlık
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Text(
            '✨ AI Asistanın hazır bekliyor',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
        ).animate().fadeIn(delay: 500.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0)),
      ],
    );
  }

  Widget _buildFeatures(ThemeData theme, bool isDark, bool isPremium) {
    final features = [
      _FeatureData(
        icon: Icons.psychology_rounded,
        title: 'AI Koçu',
        subtitle: 'Kişisel analiz & öneriler',
        color: const Color(0xFF9C27B0),
        delay: 600,
      ),
      _FeatureData(
        icon: Icons.insights_rounded,
        title: 'Akıllı Analiz',
        subtitle: 'Detaylı performans raporları',
        color: const Color(0xFF2196F3),
        delay: 700,
      ),
      _FeatureData(
        icon: Icons.trending_up_rounded,
        title: 'Strateji Planlama',
        subtitle: 'Hedef odaklı çalışma programı',
        color: const Color(0xFFFF9800),
        delay: 800,
      ),
    ];

    return Column(
      children: features
          .map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildFeatureCard(theme, isDark, feature, !isPremium),
              ))
          .toList(),
    );
  }

  Widget _buildFeatureCard(ThemeData theme, bool isDark, _FeatureData data, bool showPro) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? data.color.withValues(alpha: 0.12)
            : data.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: data.color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: showPro ? () => context.push('/premium') : null,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  // İkon
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          data.color,
                          data.color.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: data.color.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(data.icon, color: Colors.white, size: 28),
                  ),

                  const SizedBox(width: 16),

                  // Metin içeriği
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                            if (showPro)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFD700),
                                      Color(0xFFFFB300),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'PRO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Ok ikonu
                  if (showPro)
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: data.color.withValues(alpha: 0.6),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: data.delay), duration: 500.ms)
        .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildActions(ThemeData theme, bool isDark, bool isPremium) {
    return Column(
      children: [
        if (!isPremium)
          Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push('/premium'),
                borderRadius: BorderRadius.circular(18),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Premium\'a Geç',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
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
          )
              .animate()
              .fadeIn(delay: 900.ms, duration: 600.ms)
              .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic)
              .then()
              .shimmer(delay: 500.ms, duration: 1500.ms),

        const SizedBox(height: 14),

        // Daha sonra butonu
        TextButton(
          onPressed: () {
            if (isPremium) {
              context.go(AppRoutes.coach);
            } else {
              _handleClose();
            }
          },
          style: TextButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            isPremium ? '🚀 Koça Git' : 'Daha Sonra',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              letterSpacing: 0.2,
            ),
          ),
        ).animate().fadeIn(delay: 1000.ms),
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

class _FeatureData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final int delay;

  _FeatureData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.delay,
  });
}

