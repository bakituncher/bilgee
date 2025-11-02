import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:taktik/core/services/revenuecat_service.dart';
import 'package:collection/collection.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'dart:ui';
import 'dart:async';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:cloud_functions/cloud_functions.dart';

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

  // State to prevent multiple purchase clicks
  bool _isPurchasing = false;

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
      if (nextPage >= 4) {
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
    if (_isPurchasing) return; // Zaten bir işlem varsa tekrar tetikleme
    setState(() => _isPurchasing = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Satın alımlar kontrol ediliyor ve sunucuyla eşitleniyor...'),
        backgroundColor: Colors.blueGrey,
      ),
    );

    try {
      // Önce RevenueCat'in kendi restore'unu çağır, bu lokal SDK'yı günceller.
      await RevenueCatService.restorePurchases();

      // Ardından, GÜVENİLİR KAYNAK olan sunucumuzu senkronize etmesi için tetikle.
      // UI kararları bu adıma göre değil, Firestore'dan gelen stream'e göre verilmeli.
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('premium-syncRevenueCatPremiumCallable');
      await callable.call();

      // Başarılı senkronizasyon sonrası kullanıcıya genel bir bilgi ver.
      // Ekranı kapatma kararı, `premiumStatusProvider` güncellendiğinde
      // bu ekranı dinleyen bir üst widget tarafından verilebilir veya kullanıcı kendi kapatır.
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kontrol tamamlandı. Premium durumunuz güncellendi.'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
        // NOT: `_handleBack()` çağrısını buradan kaldırdık. Arayüzün tepkisi
        // artık tamamen `premiumStatusProvider`'a bağlı olmalıdır.
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bir hata oluştu: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isPurchasing = false);
    }
  }

  // --- BUILD METHOD (Sabit/Dinamik Yapı) ---

  @override
  Widget build(BuildContext context) {
    final offeringsAsyncValue = ref.watch(offeringsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final colorScheme = Theme.of(context).colorScheme;
    final marketingSlides = [
      (
      title: 'Sınırsız TaktikAI Koçu Erişimi',
      subtitle: 'Sadece limitleri kaldırmakla kalmayın, Yapay Zeka Koçunuzla sınırsız strateji, motivasyon ve ders desteği alın. Daima bir adım öndesiniz.',
      icon: Icons.rocket_launch_rounded,
      color: const Color(0xFF5b3d88)
      ),
      (
      title: 'Dinamik, Kişiselleştirilmiş Yol Haritası',
      subtitle: 'Hedeflerinize göre otomatik ayarlanan haftalık planlama. Eksiklerinize ve sınav tarihlerinize göre rotanızı yeniden çiziyoruz.',
      icon: Icons.lightbulb_outline_rounded,
      color: Theme.of(context).colorScheme.secondary
      ),
      (
      title: 'Cevher Atölyesi Full Erişim',
      subtitle: 'Derinlemesine hata analizi, zayıf konulara özel ders notları ve testler. Her yanlış cevabınızı bir öğrenme zaferine dönüştürün.',
      icon: Icons.diamond_outlined,
      color: const Color(0xFFFFB020)
      ),
      (
      title: 'Kapsamlı Test Analizi Raporları',
      subtitle: 'Gelişmiş metrikler ve yapay zeka yorumlarıyla test sonuçlarınızı en ince detayına kadar inceleyin. Performansınızı şansa bırakmayın.',
      icon: Icons.analytics_rounded,
      color: Theme.of(context).colorScheme.secondary
      ),
    ];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Arka Plan (Gradient + Blur)
          _buildAnimatedGradientBackground(),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Container(color: colorScheme.surface.withOpacity(0.3)),
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
                _buildMarketingCarousel(marketingSlides),
                const SizedBox(height: 15),
                // Page Indicator
                _buildPageIndicator(marketingSlides),
                const SizedBox(height: 20),

                // 3. FİYATLANDIRMA ALANI (Artık kaydırılabilir)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withOpacity(0.5)
                            : Colors.black.withOpacity(0.15),
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
                    loading: () => Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(strokeWidth: 3, color: Theme.of(context).colorScheme.secondary),
                    ),
                    error: (error, stack) => Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text('Hata: $error', style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
            icon: Icon(Icons.close_rounded, size: 30, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
            tooltip: 'Kapat',
            onPressed: _handleBack,
          ),
          TextButton(
            onPressed: _restorePurchases,
            child: Text(
              'Geri Yükle',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
        final colorScheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.5 + 0.5 * (1 - _gradientAnimation.value), 0.5 - 0.5 * _gradientAnimation.value),
              radius: 1.5,
              colors: isDark
                  ? [
                      colorScheme.surface,
                      colorScheme.surface,
                      Color.lerp(colorScheme.surface, Colors.black, 0.5)!,
                    ]
                  : [
                      colorScheme.surface,
                      Color.lerp(colorScheme.surface, colorScheme.primary, 0.05)!,
                      Color.lerp(colorScheme.surface, colorScheme.secondary, 0.08)!,
                    ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMarketingCarousel(List<({String title, String subtitle, IconData icon, Color color})> marketingSlides) {
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

  Widget _buildPageIndicator(List<({String title, String subtitle, IconData icon, Color color})> marketingSlides) {
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
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
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
        yearly = current.annual ?? current.getPackage('yillik-normal-yeni') ?? current.availablePackages.firstWhereOrNull((p) => p.packageType == PackageType.annual);

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
    if (_isPurchasing) return;

    setState(() {
      _isPurchasing = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.secondary)),
    );

    try {
      final outcome = await RevenueCatService.makePurchase(package);

      // Dialog'u kapattıktan sonra context'in hala geçerli olup olmadığını kontrol et.
      if (!context.mounted) return;

      if (outcome.cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Satın alma iptal edildi.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      if (outcome.success) {
        // Satın alma başarılı -> premium durumunu anında senkronize et (optimistic update)
        try {
          final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
          final callable = functions.httpsCallable('premium-syncRevenueCatPremiumCallable');
          await callable.call();
        } catch (e) {
          // Bu hatayı loglayabiliriz ama kullanıcıya göstermek şart değil.
          // Webhook zaten eninde sonunda durumu düzeltecektir.
          print("Callable function for premium sync failed (safe to ignore): $e");
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Harika! Premium özellikler aktif ediliyor...'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
        _handleBack();
        return;
      }

      // Hata durumu
      final errMsg = outcome.error ?? 'Bilinmeyen bir hata oluştu.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Satın alma başarısız: $errMsg'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Satın alma sırasında bir hata oluştu: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      // İşlem ne olursa olsun (başarı, hata, iptal) dialog'u kapat ve state'i sıfırla.
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      setState(() {
        _isPurchasing = false;
      });
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
            child: Icon(Icons.workspace_premium_rounded, size: 55, color: Theme.of(context).colorScheme.tertiary),
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
                color: Theme.of(context).colorScheme.onSurface,
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(25),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: colorScheme.surfaceContainerHighest.withOpacity(0.5), width: 1.5),
          // Pazarlamayı kuvvetlendirmek için hafif bir iç gölge efekti (Inner Glow Simulation)
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ]),
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
                    color: colorScheme.onSurface,
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
              color: colorScheme.onSurface.withOpacity(0.7),
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
    final colorScheme = Theme.of(context).colorScheme;

    final borderColor = widget.highlight ? colorScheme.secondary : colorScheme.surfaceContainerHighest;
    final backgroundColor = widget.highlight ? colorScheme.secondary.withOpacity(0.2) : colorScheme.surface;

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
                    color: colorScheme.secondary.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: colorScheme.tertiary.withOpacity(0.15),
                    blurRadius: 15,
                    spreadRadius: 2,
                  )
                ]
                    : [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.2)
                        : Colors.black.withOpacity(0.08),
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
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        // ÜCRETSİZ DENEME VURGUSU
                        if (hasFreeTrial && !widget.highlight)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: colorScheme.primary.withOpacity(0.5))),
                              child: Text(
                                'İLK 7 GÜN ÜCRETSİZ DENE',
                                style: TextStyle(
                                  color: colorScheme.primary,
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
                                color: widget.highlight ? colorScheme.secondary : colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.billingPeriod,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color:
                            widget.highlight ? colorScheme.secondary : colorScheme.onSurface.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              widget.highlight ? 'Fırsatı Yakala' : 'AYLIK ABONE OL',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: widget.highlight ? colorScheme.onSecondary : colorScheme.onSurface,
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
                            color: widget.highlight ? colorScheme.secondary : colorScheme.tertiary,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: colorScheme.onSurface.withOpacity(0.8), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withOpacity(0.3)
                                    : Colors.black.withOpacity(0.15),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Text(
                            widget.tag!,
                            style: TextStyle(
                              color: widget.highlight ? colorScheme.onSecondary : colorScheme.onTertiary,
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
    final color = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 13),
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
              const _FooterLink(text: 'Kullanım Şartları', targetRoute: AppRoutes.settings),
              const SizedBox(width: 10),
              Text('|', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38), fontSize: 11)),
              const SizedBox(width: 10),
              const _FooterLink(text: 'Gizlilik Politikası', targetRoute: AppRoutes.settings),
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
    final color = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    return GestureDetector(
      onTap: () {
        // Gerçekte URL Launcher veya Webview kullanılmalıdır.
        context.push(targetRoute).catchError((_) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$text: Navigasyon başarısız oldu. Rota: $targetRoute')));
        });
      },
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
      ),
    );
  }
}

