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

class _TrustBadges extends StatelessWidget {
  const _TrustBadges();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          _TrustRow(icon: Icons.lock_rounded, text: 'Güvenli Ödeme'),
          SizedBox(width: 16),
          _TrustRow(icon: Icons.cancel_schedule_send_rounded, text: 'Kolay İptal'),
        ],
      ),
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
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _FooterLink(text: 'Kullanım Şartları', targetRoute: AppRoutes.settings),
          const SizedBox(width: 8),
          const Text('|', style: TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(width: 8),
          _FooterLink(text: 'Gizlilik Politikası', targetRoute: AppRoutes.settings),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String text;
  final String targetRoute;

  const _FooterLink({required this.text, required this.targetRoute});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push(targetRoute).catchError((error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Sayfa açılamadı'),
                action: SnackBarAction(
                  label: 'Tekrar',
                  onPressed: () => context.push(targetRoute),
                ),
              ),
            );
          }
          return Future.error(error);
        });
      },
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white70,
        ),
      ),
    );
  }
}

class _ToolOfferScreenState extends ConsumerState<ToolOfferScreen>
    with TickerProviderStateMixin {
  static const double _kButtonHeight = 56.0;
  static const double _kButtonBorderRadius = 99.0;

  late final AnimationController _fadeController;
  late final AnimationController _cardPopController;

  Package? _selectedPackage;
  bool _isPurchaseInProgress = false;
  bool _hasInitializedPackage = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cardPopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fadeController.forward();
        _cardPopController.forward();
      }
    });

    _initializeDefaultPackage();
  }

  void _initializeDefaultPackage() {
    Future.microtask(() {
      if (!mounted || _hasInitializedPackage) return;

      final offeringsAsyncValue = ref.read(offeringsProvider);
      offeringsAsyncValue.whenData((offerings) {
        if (!mounted || _hasInitializedPackage || _selectedPackage != null) return;

        final current = offerings?.current ??
            offerings?.all.values.firstWhereOrNull(
                  (o) => o.availablePackages.isNotEmpty,
            );

        if (current != null) {
          final yearly = current.annual ??
              current.getPackage('yillik-normal') ??
              current.availablePackages.firstWhereOrNull(
                    (p) => p.packageType == PackageType.annual,
              );

          if (yearly != null && mounted) {
            setState(() {
              _selectedPackage = yearly;
              _hasInitializedPackage = true;
            });
          }
        }
      });
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
            bottom: false,
            child: Column(
              children: [
                _buildCustomHeader(context),
                Expanded(
                  child: SingleChildScrollView(
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
                        const SizedBox(height: 20),
                        _MarketingInfo(
                          fadeController: _fadeController,
                          title: widget.marketingTitle,
                          subtitle: widget.marketingSubtitle,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                _buildPurchaseSection(offeringsAsyncValue, bottomInset),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 28,
              color: Colors.white70,
            ),
            tooltip: 'Kapat',
            onPressed: _handleBack,
          ),
          Text(
            'Özel Teklif',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 48),
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

  Widget _buildPurchaseSection(
      AsyncValue<Offerings?> offeringsAsyncValue,
      double bottomInset,
      ) {
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
        data: (offerings) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: bottomInset > 0 ? bottomInset + 8 : 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPurchaseOptions(context, ref, offerings),
                const SizedBox(height: 12),
                _buildPurchaseButton(),
                const SizedBox(height: 10),
                const _TrustBadges(),
                const SizedBox(height: 4),
                const _LegalFooter(),
                const SizedBox(height: 4),
              ],
            ),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(40.0),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppTheme.secondaryColor,
            ),
          ),
        ),
        error: (error, stack) => Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppTheme.accentColor,
                size: 40,
              ),
              const SizedBox(height: 12),
              const Text(
                'Paketler yüklenemedi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'İnternet bağlantınızı kontrol edin',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseOptions(
      BuildContext context,
      WidgetRef ref,
      Offerings? offerings,
      ) {
    final current = offerings?.current ??
        offerings?.all.values.firstWhereOrNull(
              (o) => o.availablePackages.isNotEmpty,
        );

    if (current == null) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(
          child: Text(
            'Şu anda müsait paket bulunmuyor',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      );
    }

    Package? monthly, yearly;
    double? savePercent;

    monthly = current.monthly ??
        current.getPackage('aylik-normal') ??
        current.availablePackages.firstWhereOrNull(
              (p) => p.packageType == PackageType.monthly,
        );

    yearly = current.annual ??
        current.getPackage('yillik-normal') ??
        current.availablePackages.firstWhereOrNull(
              (p) => p.packageType == PackageType.annual,
        );

    if (monthly == null || yearly == null) {
      final sortedPackages = List.from(current.availablePackages)
        ..sort((a, b) => a.storeProduct.price.compareTo(b.storeProduct.price));
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

    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Devrime Katıl',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Potansiyelinin zirvesine ulaş',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.secondaryTextColor,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            if (yearly != null)
              _PurchaseOptionCard(
                animationController: _cardPopController,
                package: yearly,
                title: 'Yıllık Plan',
                price: yearly.storeProduct.priceString,
                billingPeriod: '/ yıl',
                tag: savePercent != null
                    ? '%${savePercent.toStringAsFixed(0)} AVANTAJ'
                    : 'EN İYİ DEĞER',
                isSelected: _selectedPackage == yearly,
                delay: const Duration(milliseconds: 0),
                onSelected: (pkg) => setState(() => _selectedPackage = pkg),
                color: widget.color,
                trialSubtitle:
                'Sonra ${yearly.storeProduct.priceString}/yıl',
              ),
            if (yearly != null && monthly != null) const SizedBox(height: 10),
            if (monthly != null)
              _PurchaseOptionCard(
                animationController: _cardPopController,
                package: monthly,
                title: 'Aylık Plan',
                price: monthly.storeProduct.priceString,
                billingPeriod: '/ ay',
                isSelected: _selectedPackage == monthly,
                delay: const Duration(milliseconds: 100),
                onSelected: (pkg) => setState(() => _selectedPackage = pkg),
                color: widget.color,
                trialSubtitle: '7 gün ücretsiz',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseButton() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.5),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _selectedPackage == null
          ? const SizedBox.shrink()
          : Padding(
        key: ValueKey(_selectedPackage),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: _isPurchaseInProgress ? null : _purchasePackage,
          child: AnimatedOpacity(
            opacity: _isPurchaseInProgress ? 0.7 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              height: _kButtonHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.color,
                    widget.color.withOpacity(0.7),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(_kButtonBorderRadius),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Center(
                child: _isPurchaseInProgress
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'İşleniyor...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
                    : const Text(
                  'Abone Ol ve Başla',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _purchasePackage() async {
    if (_selectedPackage == null || _isPurchaseInProgress) return;

    setState(() => _isPurchaseInProgress = true);

    try {
      final outcome = await ref.read(revenueCatServiceProvider).makePurchase(_selectedPackage!);
      if (!context.mounted) return;

      if (outcome.cancelled) {
        setState(() => _isPurchaseInProgress = false);
        return;
      }

      if (outcome.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Harika! Premium özellikler kısa süre içinde aktif olacak.'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _handleBack();
        return;
      }

      final errMsg = outcome.error ?? 'Bilinmeyen hata';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Başarısız: $errMsg'),
            backgroundColor: AppTheme.accentColor,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Tekrar',
              textColor: Colors.white,
              onPressed: _purchasePackage,
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppTheme.accentColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPurchaseInProgress = false);
      }
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
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.8),
                border: Border.all(color: color, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(icon, size: 42, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 20,
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
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
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.secondaryTextColor,
                height: 1.4,
                fontSize: 13,
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
    this.isSelected = false,
    required this.onSelected,
    required this.delay,
    required this.color,
    this.trialSubtitle,
  });

  final AnimationController animationController;
  final Package package;
  final String title;
  final String price;
  final String billingPeriod;
  final String? tag;
  final bool isSelected;
  final ValueChanged<Package> onSelected;
  final Duration delay;
  final Color color;
  final String? trialSubtitle;

  @override
  State<_PurchaseOptionCard> createState() => _PurchaseOptionCardState();
}

class _PurchaseOptionCardState extends State<_PurchaseOptionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _innerController;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _innerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _innerController, curve: Curves.easeOut),
    );

    final delayFraction = widget.delay.inMilliseconds /
        (widget.animationController.duration?.inMilliseconds ?? 1);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: widget.animationController,
        curve: Interval(delayFraction, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAnimation = CurvedAnimation(
      parent: widget.animationController,
      curve: Interval(delayFraction, 1.0, curve: Curves.easeOut),
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
    widget.onSelected(widget.package);
    _innerController.forward().then((_) {
      if (mounted) {
        _innerController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final introPrice = widget.package.storeProduct.introductoryPrice;
    final hasFreeTrial = introPrice != null && introPrice.price == 0;

    final borderColor = widget.isSelected
        ? widget.color
        : AppTheme.cardColor.withOpacity(0.5);
    final backgroundColor = widget.isSelected
        ? widget.color.withOpacity(0.15)
        : Colors.white.withOpacity(0.05);

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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: borderColor,
                  width: widget.isSelected ? 2.5 : 1.5,
                ),
                boxShadow: widget.isSelected
                    ? [
                  BoxShadow(
                    color: widget.color.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
                    : [],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
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
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    widget.price,
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                      color: widget.isSelected
                                          ? widget.color
                                          : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    widget.billingPeriod,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              if (hasFreeTrial)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.successColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppTheme.successColor.withOpacity(0.5),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'İLK 7 GÜN ÜCRETSİZ',
                                          style: TextStyle(
                                            color: AppTheme.successColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                        if (widget.trialSubtitle != null) ...[
                                          const SizedBox(height: 1),
                                          Text(
                                            widget.trialSubtitle!,
                                            style: TextStyle(
                                              color: AppTheme.successColor.withOpacity(0.8),
                                              fontWeight: FontWeight.w500,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ]
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: animation,
                              child: child,
                            );
                          },
                          child: Icon(
                            widget.isSelected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            key: ValueKey(widget.isSelected),
                            color: widget.isSelected
                                ? widget.color
                                : Colors.white38,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.tag != null)
                    Positioned(
                      top: -12,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isSelected
                              ? widget.color
                              : AppTheme.goldColor,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.8),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Text(
                          widget.tag!,
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
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