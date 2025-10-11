import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:taktik/core/services/revenuecat_service.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:collection/collection.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'dart:ui';
import 'package:taktik/core/navigation/app_routes.dart';

class ToolOfferScreen extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String heroTag;
  final String marketingTitle;
  final String marketingSubtitle;

  const ToolOfferScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.heroTag,
    required this.marketingTitle,
    required this.marketingSubtitle,
  });

  @override
  ConsumerState<ToolOfferScreen> createState() => _ToolOfferScreenState();
}

class _ToolOfferScreenState extends ConsumerState<ToolOfferScreen> with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _cardPopController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _cardPopController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeController.forward();
      _cardPopController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _cardPopController.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.aiHub);
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
            filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildCustomHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 20),
                              _ToolFeatureHeader(
                                heroTag: widget.heroTag,
                                icon: widget.icon,
                                color: widget.color,
                                title: widget.title,
                              ),
                              const SizedBox(height: 24),
                              _MarketingInfo(
                                fadeController: _fadeController,
                                title: widget.marketingTitle,
                                subtitle: widget.marketingSubtitle,
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                        _buildPurchaseSection(offeringsAsyncValue, bottomInset),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 30, color: Colors.white70),
            tooltip: 'Kapat',
            onPressed: _handleBack,
          ),
          Text(
            'Özel Teklif',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 48), // For spacing
        ],
      ),
    );
  }

  Widget _buildAnimatedGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.5,
          colors: [
            widget.color.withOpacity(0.3),
            AppTheme.primaryColor.withOpacity(0.2),
            AppTheme.primaryColor,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
    );
  }

  Widget _buildPurchaseSection(AsyncValue<Offerings?> offeringsAsyncValue, double bottomInset) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.8),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            spreadRadius: 5,
            blurRadius: 25,
          ),
        ],
      ),
      child: offeringsAsyncValue.when(
        data: (offerings) => Padding(
          padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 16),
          child: _buildPurchaseOptions(context, ref, offerings),
        ),
        loading: () => const Padding(
          padding: EdgeInsets.all(48.0),
          child: Center(child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.secondaryColor)),
        ),
        error: (error, stack) => Padding(
          padding: const EdgeInsets.all(48.0),
          child: Center(child: Text('Hata: $error', style: const TextStyle(color: AppTheme.accentColor))),
        ),
      ),
    );
  }

  Widget _buildPurchaseOptions(BuildContext context, WidgetRef ref, Offerings? offerings) {
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

    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Devrime Katıl',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Potansiyelinin zirvesine ulaşmak için TaktikAI Premium\'a geç.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor),
            ),
            const SizedBox(height: 24),
            if (yearly != null)
              _PurchaseOptionCard(
                animationController: _cardPopController,
                package: yearly,
                title: 'Yıllık Plan',
                price: yearly.storeProduct.priceString,
                billingPeriod: '/ yıl',
                tag: savePercent != null ? '%${savePercent.toStringAsFixed(0)} AVANTAJ' : 'EN İYİ DEĞER',
                highlight: true,
                delay: const Duration(milliseconds: 0),
                onTap: () => _purchasePackage(context, ref, yearly!),
                color: widget.color,
              ),
            if (yearly != null && monthly != null) const SizedBox(height: 12),
            if (monthly != null)
              _PurchaseOptionCard(
                animationController: _cardPopController,
                package: monthly,
                title: 'Aylık Plan',
                price: monthly.storeProduct.priceString,
                billingPeriod: '/ ay',
                highlight: false,
                delay: const Duration(milliseconds: 100),
                onTap: () => _purchasePackage(context, ref, monthly!),
                color: widget.color,
              ),
          ],
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

      if (outcome.cancelled) return;

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

class _ToolFeatureHeader extends StatelessWidget {
  const _ToolFeatureHeader({
    required this.heroTag,
    required this.icon,
    required this.color,
    required this.title,
  });

  final String heroTag;
  final IconData icon;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      flightShuttleBuilder: (
          BuildContext flightContext,
          Animation<double> animation,
          HeroFlightDirection flightDirection,
          BuildContext fromHeroContext,
          BuildContext toHeroContext,
          ) {
        return Material(
          color: Colors.transparent,
          child: toHeroContext.widget,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.8),
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.4), blurRadius: 20, spreadRadius: 2),
                ],
              ),
              child: Icon(icon, size: 50, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketingInfo extends StatelessWidget {
  const _MarketingInfo({
    required this.fadeController,
    required this.title,
    required this.subtitle,
  });

  final AnimationController fadeController;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeController,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.secondaryTextColor,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseOptionCard extends StatefulWidget {
  const _PurchaseOptionCard({
    required this.animationController,
    required this.package,
    required this.title,
    required this.price,
    required this.billingPeriod,
    this.tag,
    this.highlight = false,
    required this.onTap,
    required this.delay,
    required this.color,
  });

  final AnimationController animationController;
  final Package package;
  final String title;
  final String price;
  final String billingPeriod;
  final String? tag;
  final bool highlight;
  final VoidCallback onTap;
  final Duration delay;
  final Color color;

  @override
  State<_PurchaseOptionCard> createState() => _PurchaseOptionCardState();
}

class _PurchaseOptionCardState extends State<_PurchaseOptionCard> with SingleTickerProviderStateMixin {
  late final AnimationController _innerController;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _innerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnimation = Tween(begin: 1.0, end: 0.98).animate(
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
    final introPrice = widget.package.storeProduct.introductoryPrice;
    final hasFreeTrial = introPrice != null && introPrice.price == 0;

    final borderColor = widget.highlight ? widget.color : AppTheme.cardColor.withOpacity(0.5);
    final backgroundColor = widget.highlight ? widget.color.withOpacity(0.15) : Colors.white.withOpacity(0.05);

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
                color: backgroundColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: widget.highlight ? 2.5 : 1.5),
                boxShadow: widget.highlight
                    ? [
                  BoxShadow(
                    color: widget.color.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ]
                    : [],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    child: Row(
                      children: [
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
                              const SizedBox(height: 5),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    widget.price,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: widget.highlight ? widget.color : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.billingPeriod,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              // ÜCRETSİZ DENEME VURGUSU
                              if (hasFreeTrial && !widget.highlight)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                        color: AppTheme.successColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.successColor.withOpacity(0.5))
                                    ),
                                    child: const Text(
                                      'İLK 7 GÜN ÜCRETSİZ DENE',
                                      style: TextStyle(
                                        color: AppTheme.successColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          widget.highlight ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: widget.highlight ? widget.color : Colors.white38,
                          size: 32,
                        )
                      ],
                    ),
                  ),
                  if (widget.tag != null)
                    Positioned(
                      top: -15, // Dikeyde hizalama
                      right: -5, // Yatayda hizalama
                      child: Transform.rotate(
                        angle: 0.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.highlight ? widget.color : AppTheme.goldColor,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Text(
                            widget.tag!,
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
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
    );
  }
}
