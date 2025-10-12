import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:taktik/core/services/revenuecat_service.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:collection/collection.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'dart:ui';
import 'dart:async';
import 'package:taktik/core/navigation/app_routes.dart';

// --- THEME CONSTANTS ---
const Color _cardBackgroundColor = AppTheme.cardColor; // 0xFF1E293B
const Color _cardBorderColor = Color(0xFF3A445C); // Temayla uyumlu, belirgin bir sınır rengi
const Color _fixedBottomBarColor = Color(0xFF141D34); // Sabit alt bar rengi

// --- PREMIUM SCREEN (Mükemmeliyetçi Son Versiyon) ---

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
  late final PageController _pageController;

  late final Animation<double> _gradientAnimation;
  Timer? _timer;

  // Pazarlama Slaytları (İçerik değişmedi, sadece widget'lar güçlendirildi)
  final List<({String title, String subtitle, IconData icon, Color color})> marketingSlides = const [
    (
    title: 'Sınırsız TaktikAI Koçu Erişimi',
    subtitle: 'Sadece limitleri kaldırmakla kalmayın, Yapay Zeka Koçunuzla sınırsız strateji, motivasyon ve ders desteği alın. Daima bir adım öndesiniz.',
    icon: Icons.rocket_launch_rounded,
    color: Color(0xFF5b3d88)
    ),
    (
    title: 'Dinamik, Kişiselleştirilmiş Yol Haritası',
    subtitle: 'Hedeflerinize göre otomatik ayarlanan haftalık planlama. Eksiklerinize ve sınav tarihlerinize göre rotanızı yeniden çiziyoruz.',
    icon: Icons.lightbulb_outline_rounded,
    color: AppTheme.secondaryColor
    ),
    (
    title: 'Cevher Atölyesi Full Erişim',
    subtitle: 'Derinlemesine hata analizi, zayıf konulara özel ders notları ve testler. Her yanlış cevabınızı bir öğrenme zaferine dönüştürün.',
    icon: Icons.diamond_outlined,
    color: AppTheme.goldColor
    ),
    (
    title: 'Kapsamlı Test Analizi Raporları',
    subtitle: 'Gelişmiş metrikler ve yapay zeka yorumlarıyla test sonuçlarınızı en ince detayına kadar inceleyin. Performansınızı şansa bırakmayın.',
    icon: Icons.analytics_rounded,
    color: AppTheme.successColor
    ),
  ];

  // --- INITIALIZATION & DISPOSAL ---

  @override
  void initState() {
    super.initState();
    _headerSlideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _cardPopController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _gradientController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat(reverse: true);
    _pageController = PageController();

    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _gradientController,
      curve: Curves.easeInOutSine,
    ));

    Future.delayed(const Duration(milliseconds: 100), () {
      _headerSlideController.forward();
      _fadeController.forward();
      _cardPopController.forward();
      _startAutoSlide();
    });
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (!_pageController.hasClients) return;

      int nextPage = _pageController.page!.round() + 1;
      if (nextPage >= marketingSlides.length) {
        nextPage = 0;
      }
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _headerSlideController.dispose();
    _fadeController.dispose();
    _cardPopController.dispose();
    _gradientController.dispose();
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // --- NAVIGATION & RESTORE LOGIC ---

  Future<void> _handleBack() async {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _restorePurchases() async {
    await ref.read(revenueCatServiceProvider).restorePurchases();
    if (context.mounted) {
      // It might take a moment for the webhook to update the status,
      // so we read the local SDK status for immediate feedback.
      final customerInfo = await Purchases.getCustomerInfo();
      final isPremium = customerInfo.entitlements.active.isNotEmpty;
      final msg = isPremium ? 'Satın alımlar geri yüklendi. Premium aktif.' : 'Aktif satın alım bulunamadı.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isPremium ? AppTheme.successColor : AppTheme.accentColor,
        ),
      );
      if (isPremium) _handleBack();
    }
  }

  // --- BUILD METHOD (Sabit/Dinamik Yapı) ---

  @override
  Widget build(BuildContext context) {
    final offeringsAsyncValue = ref.watch(offeringsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Stack(
        children: [
          // Arka Plan (Gradient + Blur)
          _buildAnimatedGradientBackground(),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),

          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // 1. ÜST KISIM (Artık kaydırılabilir)
                _buildCustomHeader(context),

                // 2. PAZARLAMA ALANI
                // Başlıklar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: _AnimatedHeader(
                    slideController: _headerSlideController,
                    fadeController: _fadeController,
                  ),
                ),
                const SizedBox(height: 15),
                // PageView (Özellik Carousel - DYNAMIC)
                _buildMarketingCarousel(),
                const SizedBox(height: 15),
                // Page Indicator
                _buildPageIndicator(),
                const SizedBox(height: 20),

                // 3. FİYATLANDIRMA ALANI (Artık kaydırılabilir)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _fixedBottomBarColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        spreadRadius: 5,
                        blurRadius: 15,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: offeringsAsyncValue.when(
                    data: (offerings) => Column(
                      children: [
                        _buildPurchaseOptions(context, ref, offerings),
                        // Güven Rozetleri ve Yasal Metin
                        FadeTransition(
                          opacity: _fadeController,
                          child: Column(
                            children: [
                              const _TrustBadges(),
                              Padding(
                                padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset + 4 : 10),
                                child: const _LegalFooter(isCompact: true),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.secondaryColor),
                    ),
                    error: (error, stack) => Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text('Hata: $error', style: const TextStyle(color: AppTheme.accentColor)),
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

  // --- SUB-WIDGET BUILDERS ---

  Widget _buildCustomHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 16, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 30, color: Colors.white70),
            tooltip: 'Kapat',
            onPressed: _handleBack,
          ),
          TextButton(
            onPressed: _restorePurchases,
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
              radius: 1.5,
              colors: const [
                Color(0xFF282f42),
                Color(0xFF1a202c),
                Color(0xFF0e1218),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMarketingCarousel() {
    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        height: 180,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        child: PageView.builder(
          controller: _pageController,
          itemCount: marketingSlides.length,
          itemBuilder: (context, index) {
            final slide = marketingSlides[index];
            return _MarketingSlideCard(
              title: slide.title,
              subtitle: slide.subtitle,
              icon: slide.icon,
              color: slide.color,
            );
          },
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double currentPage = _pageController.hasClients ? _pageController.page ?? 0 : 0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(marketingSlides.length, (index) {
            final double scale = 1.0 - (index - currentPage).abs().clamp(0.0, 1.0) * 0.4;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 8.0 * scale.clamp(0.6, 1.0),
                height: 8.0 * scale.clamp(0.6, 1.0),
                decoration: BoxDecoration(
                  color: index == currentPage.round()
                      ? AppTheme.secondaryColor
                      : Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildPurchaseOptions(BuildContext context, WidgetRef ref, Offerings? offerings) {
    Package? monthly, yearly;
    double? savePercent;

    // --- REVENUECAT PACKAGE EXTRACTION (logic unchanged) ---
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
    // --- END OF PACKAGE EXTRACTION ---

    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        child: Column(
          children: [
            if (yearly != null)
              _PurchaseOptionCard(
                animationController: _cardPopController,
                package: yearly,
                title: 'Yıllık Premium Plan',
                price: yearly.storeProduct.priceString,
                billingPeriod: '/ yıl',
                tag: savePercent != null ? '%${savePercent.toStringAsFixed(0)} İNDİRİM' : 'EN POPÜLER',
                highlight: true,
                delay: const Duration(milliseconds: 0),
                onTap: () => _purchasePackage(context, ref, yearly!),
              ),
            if (yearly != null && monthly != null)
              const SizedBox(height: 12),
            if (monthly != null)
              _PurchaseOptionCard(
                animationController: _cardPopController,
                package: monthly,
                title: 'Aylık Premium Plan',
                price: monthly.storeProduct.priceString,
                billingPeriod: '/ ay',
                tag: 'Sana Özel',
                highlight: false,
                delay: const Duration(milliseconds: 100),
                onTap: () => _purchasePackage(context, ref, monthly!),
              ),
          ],
        ),
      ),
    );
  }

  // --- PURCHASE LOGIC (KEPT AS IS) ---

  Future<void> _purchasePackage(BuildContext context, WidgetRef ref, Package package) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor)),
    );

    try {
      final outcome = await ref.read(revenueCatServiceProvider).makePurchase(package);
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

      // The server will update the status via webhook. We just show a success message.
      if (outcome.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Harika! Premium özellikler kısa süre içinde aktif olacak.'),
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

// ====================================================================
// --- WIDGETS ---
// ====================================================================

// --- 1. ANIMATED HEADER (No Change) ---

class _AnimatedHeader extends StatelessWidget {
  final AnimationController slideController;
  final AnimationController fadeController;

  const _AnimatedHeader({required this.slideController, required this.fadeController});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
              .animate(CurvedAnimation(parent: slideController, curve: Curves.easeOutCubic)),
          child: FadeTransition(
            opacity: fadeController,
            child: const Icon(Icons.workspace_premium_rounded, size: 55, color: AppTheme.goldColor),
          ),
        ),
        const SizedBox(height: 10),
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
              .animate(CurvedAnimation(parent: slideController, curve: const Interval(0.2, 1, curve: Curves.easeOutCubic))),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: fadeController, curve: const Interval(0.2, 1)),
            child: Text(
              'TaktikAI Premium',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
              .animate(CurvedAnimation(parent: slideController, curve: const Interval(0.4, 1, curve: Curves.easeOutCubic))),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: fadeController, curve: const Interval(0.4, 1)),
            child: Text(
              'Sınırları kaldır, rekabette öne geç.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- 2. MARKETING SLIDE CARD (Geniş ve Etkileyici) ---

class _MarketingSlideCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MarketingSlideCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
          color: _cardBackgroundColor,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: AppTheme.lightSurfaceColor.withOpacity(0.5), width: 1.5),
          // Pazarlamayı kuvvetlendirmek için hafif bir iç gölge efekti (Inner Glow Simulation)
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.18),
                ),
                child: Icon(icon, color: color, size: 25),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: Colors.white70,
              height: 1.3,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// --- 3. PURCHASE OPTION CARD (Yıllık Plan için Glow Efekti Eklendi) ---

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

    final borderColor = widget.highlight ? AppTheme.secondaryColor : _cardBorderColor;
    final backgroundColor = widget.highlight ? AppTheme.secondaryColor.withOpacity(0.2) : _cardBackgroundColor;

    // --- SEKTÖR STANDARDI TASARIM İYİLEŞTİRMELERİ ---
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
                border: Border.all(color: borderColor, width: widget.highlight ? 3.0 : 1.5),
                boxShadow: widget.highlight
                    ? [
                  BoxShadow(
                    color: AppTheme.secondaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: AppTheme.goldColor.withOpacity(0.15),
                    blurRadius: 15,
                    spreadRadius: 2,
                  )
                ]
                    : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: Colors.white,
                          ),
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
                          )
                        else
                          const SizedBox(height: 5), // Eğer deneme yoksa boşluk ekle

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              widget.price,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: widget.highlight ? AppTheme.secondaryColor : Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.billingPeriod,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: widget.highlight ? AppTheme.secondaryColor : Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              widget.highlight ? 'Fırsatı Yakala' : 'AYLIK ABONE OL',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: widget.highlight ? AppTheme.primaryColor : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // TASARRUF ETiketinin Konumlandırılması
                  if (widget.tag != null)
                    Positioned(
                      top: -15, // Dikeyde hizalama
                      right: -5, // Yatayda hizalama
                      child: Transform.rotate(
                        angle: 0.0, // Açı (istersen hafif bir açı verebilirsin)
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.highlight ? AppTheme.secondaryColor : AppTheme.goldColor,
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
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w900,
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


// --- 4. TRUST BADGES and FOOTER (Unchanged) ---

class _TrustBadges extends StatelessWidget {
  const _TrustBadges();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          _TrustRow(icon: Icons.lock_rounded, text: 'Google ile Güvenli Ödeme'),
          SizedBox(width: 20),
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
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ],
    );
  }
}

class _LegalFooter extends StatelessWidget {
  final bool isCompact;
  const _LegalFooter({this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FooterLink(text: 'Kullanım Şartları', targetRoute: AppRoutes.settings),
              const SizedBox(width: 10),
              const Text('|', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 10),
              _FooterLink(text: 'Gizlilik Politikası', targetRoute: AppRoutes.settings),
            ],
          ),
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
        // Gerçekte URL Launcher veya Webview kullanılmalıdır.
        context.push(targetRoute).catchError((_) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$text: Navigasyon başarısız oldu. Rota: $targetRoute')));
        });
      },
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white70,
        ),
      ),
    );
  }
}