// lib/features/stats/screens/stats_premium_offer_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:taktik/core/services/admob_service.dart';
import 'package:taktik/data/providers/temporary_access_provider.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/utils/age_helper.dart';

class StatsPremiumOfferScreen extends ConsumerStatefulWidget {
  final String? source; // 'archive' veya 'stats'

  const StatsPremiumOfferScreen({super.key, this.source});

  @override
  ConsumerState<StatsPremiumOfferScreen> createState() => _StatsPremiumOfferScreenState();
}

class _StatsPremiumOfferScreenState extends ConsumerState<StatsPremiumOfferScreen>
    with TickerProviderStateMixin {
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
        if (mounted) {
          setState(() => _showSplash = false);
          _animController.forward();
        }
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
                    ? [const Color(0xFF0A0E27), const Color(0xFF1A1F3A)]
                    : [colorScheme.surface, colorScheme.primaryContainer.withOpacity(0.05)],
              ),
            ),
          ),

          // Splash Animation
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
                            child: Lottie.asset('assets/lotties/data.json', fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          // Main Content
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
                                  Icon(Icons.workspace_premium_rounded,
                                      color: colorScheme.primary, size: 16),
                                  const SizedBox(width: 4),
                                  Text('PREMIUM',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      )),
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

                      // Content - Kompakt tasarım
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Hero Animation
                              SizedBox(
                                height: 100,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _fadeAnimation,
                                      builder: (context, child) {
                                        return Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: RadialGradient(
                                              colors: [
                                                colorScheme.primary
                                                    .withOpacity(0.1 * _fadeAnimation.value),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    SizedBox(
                                      width: 90,
                                      height: 90,
                                      child: Lottie.asset('assets/lotties/data.json',
                                          fit: BoxFit.contain),
                                    ),
                                  ],
                                ),
                              ),

                              // Title
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.source == 'archive' ? 'Deneme Arşivi' : 'Deneme Gelişimi',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.source == 'archive'
                                        ? 'Detaylı analizlerle performansını keşfet'
                                        : 'Profesyonel analiz ile başarıya ulaş',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),

                              // Stats Comparison
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
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
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: colorScheme.primary.withOpacity(0.3), width: 2),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Text('ÜCRETSİZ',
                                                  style: theme.textTheme.labelSmall?.copyWith(
                                                      color: colorScheme.onSurfaceVariant,
                                                      fontSize: 9)),
                                              const SizedBox(height: 4),
                                              Text('45',
                                                  style: TextStyle(
                                                      fontSize: 28,
                                                      fontWeight: FontWeight.w900,
                                                      color: colorScheme.onSurfaceVariant)),
                                            ],
                                          ),
                                        ),
                                        Container(
                                            width: 2,
                                            height: 40,
                                            color: colorScheme.primary.withOpacity(0.3)),
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Text('PREMIUM',
                                                  style: theme.textTheme.labelSmall?.copyWith(
                                                      color: colorScheme.primary, fontSize: 9)),
                                              const SizedBox(height: 4),
                                              Text('78',
                                                  style: TextStyle(
                                                      fontSize: 32,
                                                      fontWeight: FontWeight.w900,
                                                      color: colorScheme.primary)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text('+73% Performans',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          )),
                                    ),
                                  ],
                                ),
                              ),

                              // Features
                              Row(
                                children: [
                                  _CompactFeature(
                                      icon: Icons.analytics_rounded,
                                      title: 'Detaylı\nAnaliz',
                                      color: colorScheme.tertiary),
                                  const SizedBox(width: 8),
                                  _CompactFeature(
                                      icon: Icons.psychology_rounded,
                                      title: 'AI\nÖnerileri',
                                      color: colorScheme.tertiary),
                                  const SizedBox(width: 8),
                                  _CompactFeature(
                                      icon: Icons.show_chart_rounded,
                                      title: 'Gelişim\nTakibi',
                                      color: colorScheme.tertiary),
                                ],
                              ),

                              // Feature List
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
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
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: colorScheme.primary.withOpacity(0.3), width: 2),
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _FeatureItem(
                                        icon: Icons.all_inclusive_rounded, text: 'Sınırsız analiz'),
                                    SizedBox(height: 6),
                                    _FeatureItem(
                                        icon: Icons.insights_rounded, text: 'AI destekli öneriler'),
                                    SizedBox(height: 6),
                                    _FeatureItem(
                                        icon: Icons.trending_up_rounded, text: 'Gelişim takibi'),
                                  ],
                                ),
                              ),

                              // CTA Buttons
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Reklam İzle Butonu
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final user = ref.read(userProfileProvider).value;

                                        // Rewarded ad'ı önceden yükle
                                        AdMobService().preloadRewardedAd(dateOfBirth: user?.dateOfBirth);

                                        // Loading dialog göster
                                        if (!context.mounted) return;
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (ctx) => Center(
                                            child: Container(
                                              padding: const EdgeInsets.all(24),
                                              decoration: BoxDecoration(
                                                color: theme.scaffoldBackgroundColor,
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const CircularProgressIndicator(),
                                                  const SizedBox(height: 16),
                                                  Text('Reklam yükleniyor...',
                                                      style: theme.textTheme.bodyMedium),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );

                                        // Reklam hazır olana kadar bekle (max 5 saniye)
                                        int waitCount = 0;
                                        while (!AdMobService().isRewardedAdReady && waitCount < 50) {
                                          await Future.delayed(const Duration(milliseconds: 100));
                                          waitCount++;
                                        }

                                        if (!context.mounted) return;
                                        Navigator.of(context).pop(); // Loading dialog'u kapat

                                        if (!AdMobService().isRewardedAdReady) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Reklam yüklenemedi. Lütfen internet bağlantınızı kontrol edin.'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }

                                        // Reklamı göster
                                        final rewardEarned = await AdMobService().showRewardedAd(
                                          dateOfBirth: user?.dateOfBirth,
                                        );

                                        debugPrint('🔍 Reward earned result: $rewardEarned');

                                        if (rewardEarned) {
                                          // Premium features'a geçici erişim ver (Stats + Archive)
                                          final tempAccess = ref.read(temporaryAccessProvider);
                                          await tempAccess.grantPremiumFeaturesAccess();
                                          debugPrint('✅ Premium features access granted (Stats + Archive)');

                                          // Provider'ı invalidate et - state'i yenile
                                          ref.invalidate(hasPremiumFeaturesAccessProvider);

                                          // State güncellenmesini bekle
                                          await Future.delayed(const Duration(milliseconds: 100));

                                          // Erişim kontrolü
                                          final hasAccess = ref.read(hasPremiumFeaturesAccessProvider);
                                          debugPrint('🔍 Access verification after invalidate: $hasAccess');

                                          if (!context.mounted) return;

                                          // Başarı mesajı göster
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text('🎉 Erişim kazandınız!'),
                                              backgroundColor: colorScheme.secondary,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );

                                          // Ekrana yönlendir - context.go direkt olarak kullan (pop'a gerek yok)
                                          if (widget.source == 'archive') {
                                            context.go('/library');
                                          } else {
                                            context.go('/home/stats');
                                          }
                                        } else {
                                          debugPrint('❌ Reward not earned');
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Reklamı tamamlamalısınız'),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.secondary,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                        elevation: 2,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.play_circle_outline_rounded, size: 22),
                                          const SizedBox(width: 8),
                                          Text('Reklam İzle',
                                              style: theme.textTheme.titleSmall?.copyWith(
                                                  color: Colors.black, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Premium'a Geç Butonu
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () => context.go('/premium'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: colorScheme.primary,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                        side: BorderSide(color: colorScheme.primary, width: 2),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.workspace_premium_rounded, size: 20),
                                          const SizedBox(width: 8),
                                          Text('Premium\'a Geç',
                                              style: theme.textTheme.titleSmall?.copyWith(
                                                  color: colorScheme.primary, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Reklamla geçici erişim, Premium ile sınırsız!',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ],
                          ),
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
}

// Kompakt widget'lar
class _CompactFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _CompactFeature({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(title,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.bold, fontSize: 10, height: 1.2),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
        ),
      ],
    );
  }
}

