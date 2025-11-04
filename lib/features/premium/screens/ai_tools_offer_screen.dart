// lib/features/premium/screens/ai_tools_offer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/providers/activity_tracker_provider.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'dart:ui';

/// Mükemmel ötesi AI Tools tanıtım ekranı - Glassmorphism Design
class AIToolsOfferScreen extends ConsumerStatefulWidget {
  const AIToolsOfferScreen({super.key});

  @override
  ConsumerState<AIToolsOfferScreen> createState() => _AIToolsOfferScreenState();
}

class _AIToolsOfferScreenState extends ConsumerState<AIToolsOfferScreen>
    with SingleTickerProviderStateMixin {
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F0A1F),
                    const Color(0xFF1A0B2E),
                    const Color(0xFF2D1B4E),
                  ]
                : [
                    const Color(0xFFF8F9FF),
                    const Color(0xFFEEF1FF),
                    const Color(0xFFE3E8FF),
                  ],
          ),
        ),
        child: Stack(
          children: [
            // Animated background particles
            ...List.generate(20, (index) => _buildParticle(index, size)),

            // Glassmorphism overlay
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: Colors.transparent),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Top bar with close button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildCloseButton(theme, isDark),
                      ],
                    ),
                  ),

                  // Main scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Column(
                        children: [
                          _buildAnimatedHeader(theme, isDark),
                          const SizedBox(height: 40),
                          _buildPremiumFeatures(theme, isDark, isPremium),
                          const SizedBox(height: 40),
                          _buildCTAButtons(theme, isPremium, isDark),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticle(int index, Size size) {
    return Positioned(
      left: (index * 37) % size.width,
      top: (index * 53) % size.height,
      child: Container(
        width: 4 + (index % 3) * 2,
        height: 4 + (index % 3) * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.6),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      )
          .animate(onPlay: (controller) => controller.repeat())
          .fadeIn(duration: (2000 + index * 100).ms)
          .then()
          .fadeOut(duration: (2000 + index * 100).ms),
    );
  }

  Widget _buildCloseButton(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: IconButton(
        icon: Icon(
          Icons.close_rounded,
          color: theme.colorScheme.onSurface,
          size: 20,
        ),
        onPressed: _handleClose,
      ),
    ).animate().scale(delay: 100.ms);
  }

  Widget _buildAnimatedHeader(ThemeData theme, bool isDark) {
    return Column(
      children: [
        // Lottie animation with glow
        Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Lottie.asset(
            'assets/lotties/ana.json',
            fit: BoxFit.contain,
            repeat: true,
          ),
        ).animate().scale(delay: 100.ms, duration: 800.ms, curve: Curves.elasticOut),

        const SizedBox(height: 32),

        // Title with shimmer effect
        ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
                theme.colorScheme.primary,
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: GradientRotation(_shimmerController.value * 2 * 3.14159),
            ).createShader(bounds);
          },
          child: Text(
            'Harika İleriyorsun! 🎯',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: Colors.white,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3, end: 0),

        const SizedBox(height: 16),

        Text(
          'Yapay zeka asistanın seni bekliyor',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildPremiumFeatures(ThemeData theme, bool isDark, bool isPremium) {
    final features = [
      {
        'icon': Icons.psychology_rounded,
        'title': 'AI Koçu',
        'desc': 'Deneme sonuçlarını analiz eden, güçlü ve zayıf yanlarını tespit eden kişisel asistan',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'icon': Icons.insights_rounded,
        'title': 'Akıllı Analiz',
        'desc': 'Her deneme sonrası detaylı raporlar, grafik ve kişiselleştirilmiş öneriler',
        'color': const Color(0xFF3B82F6),
      },
      {
        'icon': Icons.trending_up_rounded,
        'title': 'Strateji Planlama',
        'desc': 'Hedeflerine ulaşman için özel tasarlanmış çalışma stratejileri ve eylem planları',
        'color': const Color(0xFFEF4444),
      },
    ];

    return Column(
      children: features.asMap().entries.map((entry) {
        final index = entry.key;
        final feature = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: index < features.length - 1 ? 16 : 0),
          child: _buildGlassmorphicCard(
            theme,
            isDark,
            feature['icon'] as IconData,
            feature['title'] as String,
            feature['desc'] as String,
            feature['color'] as Color,
            !isPremium,
          ).animate().fadeIn(delay: (500 + index * 100).ms).slideX(begin: -0.3, end: 0),
        );
      }).toList(),
    );
  }

  Widget _buildGlassmorphicCard(
    ThemeData theme,
    bool isDark,
    IconData icon,
    String title,
    String description,
    Color accentColor,
    bool showPro,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.1),
                      Colors.white.withValues(alpha: 0.05),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.9),
                      Colors.white.withValues(alpha: 0.7),
                    ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon with gradient
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accentColor, accentColor.withValues(alpha: 0.6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
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
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
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
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.4,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCTAButtons(ThemeData theme, bool isPremium, bool isDark) {
    return Column(
      children: [
        if (!isPremium)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: double.infinity,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.push('/premium'),
                    borderRadius: BorderRadius.circular(20),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Premium\'a Geç',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
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
            ),
          )
              .animate()
              .fadeIn(delay: 700.ms)
              .slideY(begin: 0.3, end: 0)
              .shimmer(delay: 1000.ms, duration: 2000.ms),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: TextButton(
                onPressed: () {
                  if (isPremium) {
                    context.go(AppRoutes.coach);
                  } else {
                    _handleClose();
                  }
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  isPremium ? '🚀 Koça Git' : 'Daha Sonra',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
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

