import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:taktik/core/services/revenuecat_service.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'dart:math';
import 'dart:ui';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> with TickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glow;
  late final AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _glowController, curve: Curves.easeInOut);
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200), value: 0);
    _slideController.forward();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final offeringsAsyncValue = ref.watch(offeringsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.primaryColor.withBlue(25),
      body: Stack(
        children: [
          _AnimatedBackground(glow: _glow),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                automaticallyImplyLeading: false,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  tooltip: 'Geri',
                  onPressed: _handleBack,
                ),
                centerTitle: true,
                title: const Text('Zirveye Oyna', style: TextStyle(fontWeight: FontWeight.bold)),
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(color: Colors.black.withOpacity(0.2)),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    children: [
                      const _HeroVisual(),
                      const SizedBox(height: 24),
                      _AnimatedSlide(
                        controller: _slideController,
                        from: const Offset(0, 50),
                        interval: const Interval(0.1, 0.5, curve: Curves.easeOutCubic),
                        child: const _SectionHeader(
                          title: 'Potansiyelini İkiye Katla',
                          subtitle: 'TaktikAI\'ın tüm gücünü serbest bırakarak hedeflerine daha hızlı ulaş.',
                        ),
                      ),
                      const SizedBox(height: 20),
                      _AnimatedSlide(
                        controller: _slideController,
                        from: const Offset(0, 50),
                        interval: const Interval(0.2, 0.6, curve: Curves.easeOutCubic),
                        child: _buildBenefitsList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset > 0 ? bottomInset + 8 : 24),
                sliver: offeringsAsyncValue.when(
                  data: (offerings) => _buildPurchaseOptions(context, ref, offerings),
                  loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                  error: (error, stack) => SliverToBoxAdapter(child: Center(child: Text('Hata: $error'))),
                ),
              ),
              SliverToBoxAdapter(
                child: _AnimatedSlide(
                  controller: _slideController,
                  from: const Offset(0, 50),
                  interval: const Interval(0.5, 0.9, curve: Curves.easeOutCubic),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset > 0 ? bottomInset + 8 : 24),
                    child: _buildFooter(context, ref),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsList() {
    const items = [
      ('Stratejik Planlama', 'Uzun vadeli hedefler ve haftalık yol haritası.', Icons.insights_rounded, AppTheme.secondaryColor),
      ('Cevher Atölyesi', 'Zayıf yönlerini güce dönüştüren kişisel atölye.', Icons.construction_rounded, AppTheme.successColor),
      ('Analiz & Strateji', 'Deneme sonuçlarını ve stratejini tek panelden yönet.', Icons.dashboard_customize_rounded, Colors.amberAccent),
      ('Kesintisiz Odaklanma', 'Reklamsız bir deneyimle dikkat dağıtan her şeyi ortadan kaldır.', Icons.remove_red_eye_outlined, Colors.pinkAccent),
    ];

    return Column(
      children: items.map((item) {
        final index = items.indexOf(item);
        return _AnimatedSlide(
          controller: _slideController,
          from: const Offset(0, 40),
          interval: Interval(0.3 + index * 0.1, 0.7 + index * 0.1, curve: Curves.easeOutCubic),
          child: _BenefitItem(icon: item.$3, title: item.$1, subtitle: item.$2, color: item.$4),
        );
      }).toList(),
    );
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        TextButton.icon(
          onPressed: () async {
            await ref.read(premiumStatusProvider.notifier).restorePurchases();
            if (context.mounted) {
              final isPremium = ref.read(premiumStatusProvider);
              final msg = isPremium ? 'Satın alımlar geri yüklendi. Premium aktif.' : 'Aktif satın alım bulunamadı.';
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              if (isPremium) _handleBack();
            }
          },
          icon: const Icon(Icons.restore_rounded, size: 20),
          label: const Text('Satın alımları geri yükle'),
          style: TextButton.styleFrom(foregroundColor: AppTheme.secondaryTextColor),
        ),
        const SizedBox(height: 12),
        const _TrustBadges(),
      ],
    );
  }

  SliverToBoxAdapter _buildPurchaseOptions(BuildContext context, WidgetRef ref, Offerings? offerings) {
    Package? monthly, yearly;
    double? savePercent;

    if (offerings != null) {
      final current = offerings.current ?? offerings.all.values.firstWhere((o) => o.availablePackages.isNotEmpty, orElse: () => null);
      if (current != null) {
        monthly = current.monthly ?? current.getPackage('aylik-normal') ?? current.availablePackages.firstWhere((p) => p.packageType == PackageType.monthly, orElse: () => null);
        yearly = current.annual ?? current.getPackage('yillik-normal') ?? current.availablePackages.firstWhere((p) => p.packageType == PackageType.annual, orElse: () => null);

        if (monthly == null || yearly == null) {
           final sortedPackages = List.from(current.availablePackages)..sort((a,b) => a.storeProduct.price.compareTo(b.storeProduct.price));
           if (sortedPackages.isNotEmpty) monthly ??= sortedPackages.first;
           if (sortedPackages.length > 1) yearly ??= sortedPackages.last;
        }

        if (monthly != null && yearly != null) {
          final mPrice = monthly.storeProduct.price;
          final yPrice = yearly.storeProduct.price;
          if (mPrice > 0 && yPrice > 0) {
            savePercent = (1 - (yPrice / (mPrice * 12))) * 100;
          }
        }
      }
    }

    return SliverToBoxAdapter(
      child: _AnimatedSlide(
        controller: _slideController,
        from: const Offset(0, 50),
        interval: const Interval(0.4, 0.8, curve: Curves.easeOutCubic),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              if (yearly != null)
                _PurchaseOptionCard(
                  package: yearly,
                  title: 'Yıllık Plan',
                  subtitle: '${yearly.storeProduct.priceString} / yıl',
                  tag: savePercent != null ? 'En İyi Değer • %${savePercent.toStringAsFixed(0)} Tasarruf' : 'En İyi Değer',
                  highlight: true,
                  onTap: () => _purchasePackage(context, ref, yearly!),
                ),
              const SizedBox(height: 12),
              if (monthly != null)
                _PurchaseOptionCard(
                  package: monthly,
                  title: 'Aylık Plan',
                  subtitle: '${monthly.storeProduct.priceString} / ay',
                  onTap: () => _purchasePackage(context, ref, monthly!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _purchasePackage(BuildContext context, WidgetRef ref, Package package) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final outcome = await RevenueCatService.makePurchase(package);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (outcome.cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Satın alma iptal edildi.')),
        );
        return;
      }

      if (outcome.success && outcome.info != null) {
        ref.read(premiumStatusProvider.notifier).updateFromCustomerInfo(outcome.info!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Görev Başarılı! Premium artık aktif.')),
        );
        _handleBack();
        return;
      }

      final errMsg = outcome.error ?? 'Bilinmeyen bir hata oluştu.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Satın alma başarısız: $errMsg')),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Satın alma sırasında bir hata oluştu: $e')),
      );
    }
  }
}

// --- WIDGETS ---

class _AnimatedSlide extends StatelessWidget {
  const _AnimatedSlide({
    required this.controller,
    required this.child,
    required this.from,
    required this.interval,
  });

  final AnimationController controller;
  final Widget child;
  final Offset from;
  final Interval interval;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final animation = CurvedAnimation(parent: controller, curve: interval);
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(from.dx * (1 - animation.value), from.dy * (1 - animation.value)),
            child: child,
          ),
        );
      },
    );
  }
}

class _HeroVisual extends StatelessWidget {
  const _HeroVisual();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 180,
        height: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondaryColor.withOpacity(.25),
                    blurRadius: 60,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.auto_awesome,
              size: 100,
              color: AppTheme.secondaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.secondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.secondaryTextColor,
                    fontSize: 14,
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

class _PurchaseOptionCard extends StatefulWidget {
  const _PurchaseOptionCard({
    required this.package,
    required this.title,
    required this.subtitle,
    this.tag,
    this.highlight = false,
    required this.onTap,
  });

  final Package package;
  final String title;
  final String subtitle;
  final String? tag;
  final bool highlight;
  final VoidCallback onTap;

  @override
  State<_PurchaseOptionCard> createState() => _PurchaseOptionCardState();
}

class _PurchaseOptionCardState extends State<_PurchaseOptionCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = Tween(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _controller.forward();
  void _onTapUp(_) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();
  void _onTap() {
    _controller.forward().then((_) {
      _controller.reverse();
      widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.highlight ? AppTheme.secondaryColor.withOpacity(0.1) : Colors.white.withOpacity(0.05);
    final borderColor = widget.highlight ? AppTheme.secondaryColor : Colors.white.withOpacity(0.2);

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: _onTap,
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: widget.highlight ? 2.5 : 1.5),
            boxShadow: widget.highlight
                ? [
                    BoxShadow(
                      color: AppTheme.secondaryColor.withOpacity(0.2),
                      blurRadius: 25,
                      spreadRadius: -5,
                      offset: const Offset(0, 10),
                    )
                  ]
                : [],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            style: const TextStyle(fontSize: 15, color: AppTheme.secondaryTextColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Misyona Katıl',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.highlight ? AppTheme.secondaryColor : Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: widget.highlight ? AppTheme.secondaryColor : Colors.white,
                    ),
                  ],
                ),
              ),
              if (widget.tag != null)
                Positioned(
                  top: -14,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.tag!,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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
}

class _TrustBadges extends StatelessWidget {
  const _TrustBadges();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _TrustRow(icon: Icons.verified_user_outlined, text: 'Gizli ücret yok'),
        SizedBox(width: 24),
        _TrustRow(icon: Icons.lock_open_rounded, text: 'Güvenli Ödeme'),
      ],
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.secondaryTextColor, size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(color: AppTheme.secondaryTextColor, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _AnimatedBackground extends StatelessWidget {
  const _AnimatedBackground({required this.glow});
  final Animation<double> glow;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glow,
      builder: (context, _) {
        final g = glow.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor.withBlue(30),
                AppTheme.primaryColor.blend(Colors.black, .3 + g * .15),
              ],
            ),
          ),
          child: CustomPaint(
            painter: _ParticlePainter(progress: g),
          ),
        );
      },
    );
  }
}

extension on Color {
  Color blend(Color other, double t) => Color.lerp(this, other, t)!;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.progress});
  final double progress;
  final int count = 25;
  final rnd = Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < count; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final radius = (rnd.nextDouble() * 2.5 + 1.5) * (1 + (sin(progress * pi) * .4));
      final paint = Paint()
        ..color = AppTheme.secondaryColor.withOpacity(.03 + rnd.nextDouble() * .05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => oldDelegate.progress != progress;
}