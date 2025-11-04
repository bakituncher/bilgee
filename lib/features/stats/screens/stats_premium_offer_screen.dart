// lib/features/stats/screens/stats_premium_offer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'dart:ui';

class StatsPremiumOfferScreen extends ConsumerStatefulWidget {
  const StatsPremiumOfferScreen({super.key});

  @override
  ConsumerState<StatsPremiumOfferScreen> createState() => _StatsPremiumOfferScreenState();
}

class _StatsPremiumOfferScreenState extends ConsumerState<StatsPremiumOfferScreen> with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _splashController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _splashScale;
  late Animation<double> _splashOpacity;
  late Animation<Offset> _slideAnimation;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();

    // Splash animation - 2 saniye
    _splashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _splashScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.2).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_splashController);

    _splashOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_splashController);

    // Main content animation
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    // Start animations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _splashController.forward().then((_) {
        setState(() => _showSplash = false);
        _animController.forward();
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _splashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E27) : colorScheme.surface,
      body: Stack(
        children: [
          // Premium gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        const Color(0xFF0A0E27),
                        const Color(0xFF1A1F3A),
                      ]
                    : [
                        colorScheme.surface,
                        colorScheme.primaryContainer.withOpacity(0.05),
                      ],
              ),
            ),
          ),

          // Splash Animation (tam ekran)
          if (_showSplash)
            AnimatedBuilder(
              animation: _splashController,
              builder: (context, child) {
                return Opacity(
                  opacity: _splashOpacity.value,
                  child: Center(
                    child: Transform.scale(
                      scale: _splashScale.value,
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              colorScheme.primary.withOpacity(0.2),
                              colorScheme.secondary.withOpacity(0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 220,
                            height: 220,
                            child: Lottie.asset(
                              'assets/lotties/data.json',
                              fit: BoxFit.contain,
                              repeat: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          // Main Content (kayarak gelen)
          if (!_showSplash)
            SafeArea(
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 48),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium_rounded, color: colorScheme.primary, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'PREMIUM',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: colorScheme.onSurface),
                          onPressed: () => context.go('/home'),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Hero Animation
                                  _buildHeroSection(colorScheme),

                                  // Title
                                  _buildTitleSection(theme, colorScheme),

                                  // Stats Comparison
                                  _CompactStatsCard(
                                    animation: _fadeAnimation,
                                    colorScheme: colorScheme,
                                    theme: theme,
                                    isDark: isDark,
                                  ),

                                  // Features Grid
                                  _CompactFeatureGrid(
                                    colorScheme: colorScheme,
                                    theme: theme,
                                    isDark: isDark,
                                  ),

                                  // Premium Features
                                  _CompactFeaturesList(
                                    colorScheme: colorScheme,
                                    theme: theme,
                                    isDark: isDark,
                                  ),

                                  // CTA + Restore
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _ModernCTAButton(
                                        onTap: () => context.go('/premium'),
                                        colorScheme: colorScheme,
                                        theme: theme,
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text('Satın alımlar kontrol ediliyor...'),
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          minimumSize: const Size(0, 28),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          'Satın alımları geri yükle',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      ),

    );
  }

  Widget _buildHeroSection(ColorScheme colorScheme) {
    return SizedBox(
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colorScheme.primary.withOpacity(0.15 * _fadeAnimation.value),
                      colorScheme.secondary.withOpacity(0.08 * _fadeAnimation.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.88 + (_fadeAnimation.value * 0.12),
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: Lottie.asset(
                      'assets/lotties/data.json',
                      fit: BoxFit.contain,
                      repeat: true,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Deneme Gelişimi',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withOpacity(0.15),
                colorScheme.secondary.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_graph_rounded, size: 14, color: colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                'Sektör Lideri Platform',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Stats Card
class _CompactStatsCard extends StatelessWidget {
  final Animation<double> animation;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final bool isDark;

  const _CompactStatsCard({
    required this.animation,
    required this.colorScheme,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        colorScheme.surfaceContainer.withOpacity(0.8),
                        colorScheme.surfaceContainer.withOpacity(0.6),
                      ]
                    : [
                        Colors.white,
                        colorScheme.primaryContainer.withOpacity(0.05),
                      ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.25),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PERFORMANS KARŞILAŞTIRMASI',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        label: 'Ücretsiz',
                        value: (45 * animation.value).toInt().toString(),
                        subtitle: 'Ort. Net',
                        color: colorScheme.onSurfaceVariant,
                        theme: theme,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 45,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colorScheme.primary.withOpacity(0.1),
                            colorScheme.primary.withOpacity(0.5),
                            colorScheme.primary.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    Expanded(
                      child: _StatBox(
                        label: 'Premium',
                        value: (78 * animation.value).toInt().toString(),
                        subtitle: 'Ort. Net',
                        color: colorScheme.primary,
                        theme: theme,
                        isPremium: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary.withOpacity(0.2),
                        colorScheme.secondary.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 10),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '+73% Performans',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final ThemeData theme;
  final bool isPremium;

  const _StatBox({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.theme,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: color.withOpacity(0.7),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            fontSize: 8,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: isPremium ? 32 : 28,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1,
                letterSpacing: -1,
              ),
            ),
            if (isPremium)
              Padding(
                padding: const EdgeInsets.only(left: 2, top: 1),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    size: 8,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color.withOpacity(0.65),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// Feature Grid
class _CompactFeatureGrid extends StatelessWidget {
  final ColorScheme colorScheme;
  final ThemeData theme;
  final bool isDark;

  const _CompactFeatureGrid({
    required this.colorScheme,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final features = [
      {'icon': Icons.analytics_rounded, 'title': 'Detaylı\nAnaliz', 'color': colorScheme.primary},
      {'icon': Icons.show_chart_rounded, 'title': 'Gelişim\nTakibi', 'color': colorScheme.secondary},
      {'icon': Icons.psychology_rounded, 'title': 'AI\nÖnerileri', 'color': Colors.purple},
      {'icon': Icons.compare_arrows_rounded, 'title': 'Karşılaştırma', 'color': Colors.orange},
    ];

    return SizedBox(
      height: 90,
      child: Row(
        children: features.asMap().entries.map((entry) {
          final index = entry.key;
          final feature = entry.value;
          final featureColor = feature['color'] as Color;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : 3,
                right: index == features.length - 1 ? 0 : 3,
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 400 + (index * 80)),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  colorScheme.surfaceContainer.withOpacity(0.6),
                                  colorScheme.surfaceContainer.withOpacity(0.4),
                                ]
                              : [
                                  Colors.white,
                                  featureColor.withOpacity(0.03),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: featureColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  featureColor.withOpacity(0.2),
                                  featureColor.withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              feature['icon'] as IconData,
                              color: featureColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            feature['title'] as String,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 9,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Features List
class _CompactFeaturesList extends StatelessWidget {
  final ColorScheme colorScheme;
  final ThemeData theme;
  final bool isDark;

  const _CompactFeaturesList({
    required this.colorScheme,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final features = [
      {'text': 'Sınırsız deneme analizi', 'icon': Icons.all_inclusive_rounded},
      {'text': 'Konular arası ilerleme', 'icon': Icons.map_rounded},
      {'text': 'AI destekli öneriler', 'icon': Icons.psychology_alt_rounded},
      {'text': 'Akıllı strateji planlama', 'icon': Icons.track_changes_rounded},
      {'text': 'Detaylı performans analizi', 'icon': Icons.insights_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  colorScheme.primary.withOpacity(0.15),
                  colorScheme.secondary.withOpacity(0.10),
                ]
              : [
                  colorScheme.primary.withOpacity(0.12),
                  colorScheme.secondary.withOpacity(0.08),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                'Premium Özellikler',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...features.map((feature) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.secondary],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      feature['icon'] as IconData,
                      color: Colors.white,
                      size: 9,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      feature['text'] as String,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

// CTA Button
class _ModernCTAButton extends StatelessWidget {
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _ModernCTAButton({
    required this.onTap,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
            Colors.amber.shade600,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: -3,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Premium\'a Yükselt',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontSize: 15,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tüm özelliklerin kilidini aç',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

