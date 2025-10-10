import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:taktik/core/services/revenuecat_service.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:collection/collection.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'dart:ui'; // For BackdropFilter

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> with TickerProviderStateMixin {
  late final AnimationController _headerSlideController;
  late final AnimationController _fadeController;
  late final AnimationController _cardPopController;
  late final AnimationController _gradientController;

  late final Animation<double> _gradientAnimation;

  @override
  void initState() {
    super.initState();
    _headerSlideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _cardPopController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _gradientController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat(reverse: true);

    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _gradientController,
      curve: Curves.easeInOutSine,
    ));

    Future.delayed(const Duration(milliseconds: 100), () {
      _headerSlideController.forward();
      _fadeController.forward();
      _cardPopController.forward();
    });
  }

  @override
  void dispose() {
    _headerSlideController.dispose();
    _fadeController.dispose();
    _cardPopController.dispose();
    _gradientController.dispose();
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
      backgroundColor: AppTheme.primaryColor,
      body: Stack(
        children: [
          _buildAnimatedGradientBackground(),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0), // Hafif bir blur efekti
            child: Container(
              color: Colors.black.withOpacity(0.2), // Blur üzerine hafif bir overlay
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                automaticallyImplyLeading: false,
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 28, color: Colors.white),
                  tooltip: 'Kapat',
                  onPressed: _handleBack,
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await ref.read(premiumStatusProvider.notifier).restorePurchases();
                      if (context.mounted) {
                        final isPremium = ref.read(premiumStatusProvider);
                        final msg = isPremium ? 'Satın alımlar geri yüklendi. Premium aktif.' : 'Aktif satın alım bulunamadı.';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: isPremium ? AppTheme.successColor : AppTheme.accentColor,
                          ),
                        );
                        if (isPremium) _handleBack();
                      }
                    },
                    child: Text(
                      'Geri Yükle',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _AnimatedHeader(
                        slideController: _headerSlideController,
                        fadeController: _fadeController,
                      ),
                      const SizedBox(height: 40),
                      _buildBenefitsList(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset > 0 ? bottomInset + 8 : 24),
                sliver: offeringsAsyncValue.when(
                  data: (offerings) => _buildPurchaseOptions(context, ref, offerings),
                  loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.secondaryColor))),
                  error: (error, stack) => SliverToBoxAdapter(child: Center(child: Text('Hata: $error', style: const TextStyle(color: AppTheme.accentColor)))),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeController,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset > 0 ? bottomInset + 8 : 24),
                    child: const _TrustBadges(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedGradientBackground() {
    return AnimatedBuilder(
      animation: _gradientAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.5 + 0.5 * (1 - _gradientAnimation.value), 0.5 - 0.5 * _gradientAnimation.value),
              radius: 1.2,
              colors: const [
                Color(0xFF282f42), // slightly lighter dark blue
                Color(0xFF1a202c), // primary dark blue
                Color(0xFF0e1218), // even darker
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBenefitsList() {
    const items = [
      ('Sınırsız Yapay Zeka Koçu', 'Tüm TaktikAI özelliklerini limit olmadan kullan, zirveye oyna!', Icons.rocket_launch_rounded, Color(0xFF8A2BE2)), // Violet
      ('Stratejik Yol Haritası', 'Hedeflerine özel, kişiselleştirilmiş haftalık planlama ile her adımın garantide.', Icons.lightbulb_outline_rounded, Color(0xFF1E90FF)), // DodgerBlue
      ('Cevher Atölyesi', 'Zayıf yönlerini parlayan güce dönüştür, benzersiz yeteneklerini keşfet.', Icons.diamond_outlined, Color(0xFFDAA520)), // Goldenrod
      ('Reklamsız Odaklanma', 'Kesintisiz bir deneyimle dikkat dağıtmadan sadece hedefine odaklan.', Icons.self_improvement_rounded, Color(0xFFDC143C)), // Crimson
    ];

    return Column(
      children: items.map((item) {
        final index = items.indexOf(item);
        return _AnimatedBenefitItem(
          slideController: _headerSlideController, // Reusing for coordinated animation
          fadeController: _fadeController,
          icon: item.$3,
          title: item.$1,
          subtitle: item.$2,
          color: item.$4,
          delay: Duration(milliseconds: 250 + 120 * index),
        );
      }).toList(),
    );
  }

  SliverToBoxAdapter _buildPurchaseOptions(BuildContext context, WidgetRef ref, Offerings? offerings) {
    Package? monthly, yearly;
    double? savePercent;

    if (offerings != null) {
      final current = offerings.current ?? offerings.all.values.firstWhereOrNull((o) => o.availablePackages.isNotEmpty);
      if (current != null) {
        monthly = current.monthly ?? current.getPackage('aylik-normal') ?? current.availablePackages.firstWhereOrNull((p) => p.packageType == PackageType.monthly);
        yearly = current.annual ?? current.getPackage('yillik-normal') ?? current.availablePackages.firstWhereOrNull((p) => p.packageType == PackageType.annual);

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
      child: FadeTransition(
        opacity: _fadeController,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              if (yearly != null)
                _PurchaseOptionCard(
                  animationController: _cardPopController,
                  package: yearly,
                  title: 'Yıllık Plan',
                  subtitle: '${yearly.storeProduct.priceString} / yıl',
                  tag: savePercent != null ? '%${savePercent.toStringAsFixed(0)} AVANTAJLI' : 'EN POPÜLER',
                  highlight: true,
                  delay: const Duration(milliseconds: 0),
                  onTap: () => _purchasePackage(context, ref, yearly!),
                ),
              const SizedBox(height: 16),
              if (monthly != null)
                _PurchaseOptionCard(
                  animationController: _cardPopController,
                  package: monthly,
                  title: 'Aylık Plan',
                  subtitle: '${monthly.storeProduct.priceString} / ay',
                  delay: const Duration(milliseconds: 100),
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
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor)),
    );

    try {
      final outcome = await RevenueCatService.makePurchase(package);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (outcome.cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Satın alma iptal edildi.'),
            backgroundColor: AppTheme.accentColor,
          ),
        );
        return;
      }

      if (outcome.success && outcome.info != null) {
        ref.read(premiumStatusProvider.notifier).updateFromCustomerInfo(outcome.info!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Harika! Premium özellikler artık aktif.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _handleBack();
        return;
      }

      final errMsg = outcome.error ?? 'Bilinmeyen bir hata oluştu.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Satın alma başarısız: $errMsg'),
          backgroundColor: AppTheme.accentColor,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Satın alma sırasında bir hata oluştu: $e'),
          backgroundColor: AppTheme.accentColor,
        ),
      );
    }
  }
}

// --- WIDGETS ---

class _AnimatedHeader extends StatelessWidget {
  final AnimationController slideController;
  final AnimationController fadeController;

  const _AnimatedHeader({required this.slideController, required this.fadeController});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
              .animate(CurvedAnimation(parent: slideController, curve: Curves.easeOutCubic)),
          child: FadeTransition(
            opacity: fadeController,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.amberAccent.withOpacity(0.35),
                    blurRadius: 60,
                    spreadRadius: -10,
                  ),
                ],
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFFFFC857),
                    Color(0xFFFFF6D6),
                    Color(0xFFFFC857),
                  ],
                ),
              ),
              child: const Icon(Icons.workspace_premium_rounded, size: 62, color: AppTheme.primaryColor),
            ),
          ),
        ),
        const SizedBox(height: 28),
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
              .animate(CurvedAnimation(parent: slideController, curve: const Interval(0.2, 1, curve: Curves.easeOutCubic))),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: fadeController, curve: const Interval(0.2, 1)),
            child: Text(
              'Limitleri Zorla, Fark Yarat!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
              .animate(CurvedAnimation(parent: slideController, curve: const Interval(0.32, 1, curve: Curves.easeOutCubic))),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: fadeController, curve: const Interval(0.32, 1)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.28),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Yeni nesil Premium deneyimi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
              .animate(CurvedAnimation(parent: slideController, curve: const Interval(0.4, 1, curve: Curves.easeOutCubic))),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: fadeController, curve: const Interval(0.4, 1)),
            child: Text(
              'TaktikAI Premium ile hedeflerine giden yolda sınırları kaldır, rekabette öne geç ve başarı seninle olsun.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        const _HeroHighlights(),
      ],
    );
  }
}

class _AnimatedBenefitItem extends StatefulWidget {
  final AnimationController slideController;
  final AnimationController fadeController;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Duration delay;

  const _AnimatedBenefitItem({
    required this.slideController,
    required this.fadeController,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.delay,
  });

  @override
  State<_AnimatedBenefitItem> createState() => _AnimatedBenefitItemState();
}

class _AnimatedBenefitItemState extends State<_AnimatedBenefitItem> {
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: widget.slideController,
        curve: Interval(widget.delay.inMilliseconds / 1000, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _fadeAnimation = CurvedAnimation(
      parent: widget.fadeController,
      curve: Interval(widget.delay.inMilliseconds / 1000, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.color.withOpacity(0.18),
                  widget.color.withOpacity(0.05),
                ],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.16),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withOpacity(0.25),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
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

class _HeroHighlights extends StatelessWidget {
  const _HeroHighlights();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.auto_graph_rounded,
        '3.4x daha hızlı gelişim',
        'Yapay zeka koçluğuyla başarı grafiğini yukarı taşı.',
      ),
      (
        Icons.shield_moon_rounded,
        '%98 memnuniyet',
        'Profesyonel sporcuların tercih ettiği güvenli destek.',
      ),
      (
        Icons.flash_on_rounded,
        'Anlık strateji güncellemeleri',
        'Her maça özel, gerçek zamanlı tavsiyeler.',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 520;
        final rawWidth = isWide ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth;
        final width = rawWidth.isFinite ? rawWidth : constraints.maxWidth;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: items.map((item) {
            return Container(
              width: width,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.18),
                    Colors.white.withOpacity(0.04),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 25,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.14),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Icon(item.$1, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$2,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.$3,
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}


class _PurchaseOptionCard extends StatefulWidget {
  const _PurchaseOptionCard({
    required this.animationController,
    required this.package,
    required this.title,
    required this.subtitle,
    this.tag,
    this.highlight = false,
    required this.onTap,
    required this.delay,
  });

  final AnimationController animationController;
  final Package package;
  final String title;
  final String subtitle;
  final String? tag;
  final bool highlight;
  final VoidCallback onTap;
  final Duration delay;

  @override
  State<_PurchaseOptionCard> createState() => _PurchaseOptionCardState();
}

class _PurchaseOptionCardState extends State<_PurchaseOptionCard> with SingleTickerProviderStateMixin {
  late final AnimationController _innerController; // For tap animation
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _innerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnimation = Tween(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _innerController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: widget.animationController,
        curve: Interval(widget.delay.inMilliseconds / widget.animationController.duration!.inMilliseconds, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _fadeAnimation = CurvedAnimation(
      parent: widget.animationController,
      curve: Interval(widget.delay.inMilliseconds / widget.animationController.duration!.inMilliseconds, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _innerController.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _innerController.forward();
  void _onTapUp(_) => _innerController.reverse();
  void _onTapCancel() => _innerController.reverse();
  void _onTap() {
    _innerController.forward().then((_) {
      _innerController.reverse();
      widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.highlight ? AppTheme.secondaryColor.withOpacity(0.15) : const Color(0xFF2a3547).withOpacity(0.7);
    final borderColor = widget.highlight ? AppTheme.secondaryColor : const Color(0xFF434f63);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: _onTap,
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: borderColor, width: widget.highlight ? 2.5 : 1.5),
                boxShadow: widget.highlight
                    ? [
                  BoxShadow(
                    color: AppTheme.secondaryColor.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: -8,
                    offset: const Offset(0, 15),
                  )
                ]
                    : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: -5,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.subtitle,
                                style: const TextStyle(fontSize: 16, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 20,
                          color: widget.highlight ? AppTheme.secondaryColor : Colors.white70,
                        ),
                      ],
                    ),
                  ),
                  if (widget.tag != null)
                    Positioned(
                      top: -16,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.secondaryColor, Colors.amber],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.secondaryColor.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.tag!,
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
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
        _TrustRow(icon: Icons.security_rounded, text: 'Güvenli Ödeme'),
        SizedBox(width: 32),
        _TrustRow(icon: Icons.redo_rounded, text: 'Kolay İptal'),
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
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ],
    );
  }
}