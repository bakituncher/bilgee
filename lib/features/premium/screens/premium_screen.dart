import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:taktik/core/services/revenuecat_service.dart';
import 'package:collection/collection.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:taktik/data/providers/shared_prefs_provider.dart';
import 'dart:ui';
import 'dart:async';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // State to track selected package
  Package? _selectedPackage;

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
    // Premium ekranı kapatılırken bugünün tarihini kaydet
    // Böylece kullanıcı bugün tekrar premium ekranı görmeyecek
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final today = DateTime.now().toString().split(' ')[0]; // YYYY-MM-DD formatı
      await prefs.setString('premium_screen_last_shown', today);
    } catch (_) {
      // Hata durumunda sessiz geç
    }

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
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive değerler
    final isSmallScreen = screenHeight < 700;
    final isMediumScreen = screenHeight >= 700 && screenHeight < 850;

    final marketingSlides = [
      (
      title: 'Sınırsız AI Özel Ders Koçu',
      subtitle: 'Özel ders yerine ayda 5.000₺+ tasarruf! Taktik Tavşan 7/24 yanınızda.',
      icon: Icons.school_rounded,
      color: const Color(0xFF5b3d88)
      ),
      (
      title: '%300 Daha Hızlı Öğren',
      subtitle: 'Kişiselleştirilmiş öğrenme ile zamanını 3 kat daha verimli kullan.',
      icon: Icons.speed_rounded,
      color: const Color(0xFF2E7D32)
      ),
      (
      title: 'Reklamlardan Tamamen Kurtul',
      subtitle: 'Hiç kesinti yok! Saatte 12 dakika reklam = ayda 6 saat tasarruf.',
      icon: Icons.block_rounded,
      color: const Color(0xFFE63946)
      ),
      (
      title: 'Hedef Odaklı Çalışma Planı',
      subtitle: 'AI ile her gün ne çalışacağını bilen başarılı öğrenciler gibi.',
      icon: Icons.military_tech_rounded,
      color: Theme.of(context).colorScheme.secondary
      ),
      (
      title: 'Cevher Atölyesi: Hata Analizin',
      subtitle: 'Her hatadan ders çıkar, aynı soruları bir daha çözme.',
      icon: Icons.diamond_rounded,
      color: const Color(0xFFFFB020)
      ),
      (
      title: 'Akıllı Test Analizi & Tahmin',
      subtitle: 'Hangi konular sınavda çıkacak? AI zayıf noktalarını gösterir.',
      icon: Icons.insights_rounded,
      color: Theme.of(context).colorScheme.tertiary
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

          // SCROLLABLE CONTENT
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // Safe Area Padding + Space for floating buttons
                SizedBox(height: MediaQuery.of(context).padding.top + 68),

                // PAZARLAMA ALANI - Header
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isSmallScreen ? 4 : 6,
                  ),
                  child: _AnimatedHeader(
                    slideController: _headerSlideController,
                    fadeController: _fadeController,
                    isSmallScreen: isSmallScreen,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 4 : 6),

                // PageView (Özellik Carousel - DYNAMIC)
                _buildMarketingCarousel(marketingSlides, isSmallScreen, isMediumScreen),
                SizedBox(height: isSmallScreen ? 4 : 6),

                // Page Indicator
                _buildPageIndicator(marketingSlides),
                SizedBox(height: isSmallScreen ? 8 : 12),

                // 3. FİYATLANDIRMA ALANI
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
                        _buildPurchaseOptions(context, ref, offerings, isSmallScreen),
                        // Güven Rozetleri ve Yasal Metin
                        FadeTransition(
                          opacity: _fadeController,
                          child: Column(
                            children: [
                              const _TrustBadges(),
                              const _PriceTransparencyFooter(),
                              Padding(
                                padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset + 2 : 8),
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

          // Floating Buttons
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close Button
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withAlpha(230),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.outline.withAlpha(60),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(40),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 24,
                      color: colorScheme.onSurface,
                    ),
                    tooltip: 'Kapat',
                    onPressed: _handleBack,
                  ),
                ),

                // Restore Button
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E3192).withAlpha(100),
                        blurRadius: 16,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: const Color(0xFF1BFFFF).withAlpha(60),
                        blurRadius: 20,
                        spreadRadius: -2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _restorePurchases,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.restore_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Geri Yükle',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildMarketingCarousel(
      List<({String title, String subtitle, IconData icon, Color color})> marketingSlides,
      bool isSmallScreen,
      bool isMediumScreen,
      ) {
    final carouselHeight = isSmallScreen ? 75.0 : (isMediumScreen ? 85.0 : 95.0);

    return FadeTransition(
      opacity: _fadeController,
      child: SizedBox(
        height: carouselHeight,
        child: PageView.builder(
          controller: _pageController,
          itemCount: marketingSlides.length,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            final slide = marketingSlides[index];
            return AnimatedBuilder(
              animation: _pageController,
              builder: (context, child) {
                double value = 1.0;
                if (_pageController.position.haveDimensions) {
                  value = _pageController.page! - index;
                  value = (1 - (value.abs() * 0.3)).clamp(0.7, 1.0);
                }

                return Center(
                  child: Transform.scale(
                    scale: value,
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  ),
                );
              },
              child: _MarketingSlideCard(
                title: slide.title,
                subtitle: slide.subtitle,
                icon: slide.icon,
                color: slide.color,
                isSmallScreen: isSmallScreen,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSubscribeButton(BuildContext context, WidgetRef ref, bool isSmallScreen) {
    return FadeTransition(
      opacity: _fadeController,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 14 : 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF2E3192),
              Color(0xFF1BFFFF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E3192).withOpacity(0.6),
              blurRadius: 28,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: const Color(0xFF1BFFFF).withOpacity(0.4),
              blurRadius: 36,
              spreadRadius: -4,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _selectedPackage != null && !_isPurchasing
                ? () => _purchasePackage(context, ref, _selectedPackage!)
                : null,
            borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
            child: Center(
              child: _isPurchasing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: isSmallScreen ? 20 : 24,
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 10 : 14),
                        Text(
                          'Şimdi PRO\'ya Geç',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16.0 : 19.0,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 10 : 14),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: isSmallScreen ? 20 : 24,
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

  Widget _buildPageIndicator(List<({String title, String subtitle, IconData icon, Color color})> marketingSlides) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double currentPage = _pageController.hasClients ? _pageController.page ?? 0 : 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(marketingSlides.length, (index) {
              final isActive = index == currentPage.round();

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: isActive ? 28.0 : 8.0,
                  height: 8.0,
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? const LinearGradient(
                            colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    color: isActive
                        ? null
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: const Color(0xFF2E3192).withOpacity(0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildPurchaseOptions(BuildContext context, WidgetRef ref, Offerings? offerings, bool isSmallScreen) {
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

    // Eğer hiç seçim yapılmadıysa, aylık planı varsayılan olarak seç
    _selectedPackage ??= monthly;

    // Yıllık paket için aylık eşdeğer fiyatı hesapla
    String? monthlyEquiv;
    if (yearly != null) {
      final monthlyPrice = yearly.storeProduct.price / 12;
      monthlyEquiv = monthlyPrice % 1 == 0
        ? '${monthlyPrice.toStringAsFixed(0)}₺'
        : '${monthlyPrice.toStringAsFixed(2)}₺';
    }

    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallScreen ? 8 : 12),
        child: Column(
          children: [
            if (yearly != null)
              _PurchaseOptionCard(
                animationController: _cardPopController,
                package: yearly,
                title: 'Yıllık - En Akıllı Seçim',
                price: yearly.storeProduct.priceString,
                billingPeriod: '/ yıl',
                monthlyEquivalent: monthlyEquiv,
                tag: savePercent != null ? '%${savePercent.toStringAsFixed(0)} TASARRUF' : '🔥 EN ÇOK TERCİH EDİLEN',
                highlight: _selectedPackage?.identifier == yearly.identifier,
                delay: const Duration(milliseconds: 0),
                isSmallScreen: isSmallScreen,
                onTap: () {
                  setState(() => _selectedPackage = yearly);
                },
              ),
            if (yearly != null && monthly != null)
              SizedBox(height: isSmallScreen ? 6 : 8),
            if (monthly != null)
              _PurchaseOptionCard(
                animationController: _cardPopController,
                package: monthly,
                title: 'Aylık - Risk Almadan Dene',
                price: monthly.storeProduct.priceString,
                billingPeriod: '/ ay',
                tag: '💪 TAM KONTROL',
                highlight: _selectedPackage?.identifier == monthly.identifier,
                delay: const Duration(milliseconds: 100),
                isSmallScreen: isSmallScreen,
                onTap: () {
                  setState(() => _selectedPackage = monthly);
                },
              ),
            // Ana Abone Ol Butonu
            SizedBox(height: isSmallScreen ? 12 : 16),
            _buildSubscribeButton(context, ref, isSmallScreen),
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

// --- NEW: Price Transparency Footer ---
class _PriceTransparencyFooter extends StatelessWidget {
  const _PriceTransparencyFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface.withOpacity(0.65);
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      color: textColor,
      height: 1.4,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        '✨ İlk 7 gün tamamen ÜCRETSİZ! Beğenmezsen istediğin zaman iptal et. '
            'Yüzbinlerce öğrenci Taktik PRO ile hedeflerine ulaştı. '
            'Aboneliğini istediğin an Ayarlar > Abonelik Yönetimi\'nden kolayca iptal edebilirsin. '
            'Tüm fiyatlar vergiler dahil, şeffaf ve net.',
        textAlign: TextAlign.center,
        style: textStyle,
      ),
    );
  }
}

// --- 1. ANIMATED HEADER (No Change) ---

class _AnimatedHeader extends StatefulWidget {
  final AnimationController slideController;
  final AnimationController fadeController;
  final bool isSmallScreen;

  const _AnimatedHeader({
    required this.slideController,
    required this.fadeController,
    this.isSmallScreen = false,
  });

  @override
  State<_AnimatedHeader> createState() => _AnimatedHeaderState();
}

class _AnimatedHeaderState extends State<_AnimatedHeader> {
  @override
  Widget build(BuildContext context) {
    final titleSize = widget.isSmallScreen ? 24.0 : 28.0;
    final subtitleSize = widget.isSmallScreen ? 13.0 : 15.0;

    return Column(
      children: [
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
              .animate(CurvedAnimation(parent: widget.slideController, curve: Curves.easeOutCubic)),
          child: FadeTransition(
            opacity: widget.fadeController,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF2E3192),
                  Color(0xFF1BFFFF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                'Taktik PRO',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontSize: titleSize,
                  letterSpacing: -1.2,
                  height: 1,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: widget.isSmallScreen ? 4 : 8),
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
              .animate(CurvedAnimation(parent: widget.slideController, curve: const Interval(0.2, 1, curve: Curves.easeOutCubic))),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: widget.fadeController, curve: const Interval(0.2, 1)),
            child: Text(
              '1 kahve fiyatına başarının anahtarı',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                fontWeight: FontWeight.w700,
                fontSize: subtitleSize,
                height: 1.3,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MarketingSlideCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSmallScreen;

  const _MarketingSlideCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isSmallScreen = false,
  });

  @override
  State<_MarketingSlideCard> createState() => _MarketingSlideCardState();
}

class _MarketingSlideCardState extends State<_MarketingSlideCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardPadding = widget.isSmallScreen ? 14.0 : 16.0;
    final iconSize = widget.isSmallScreen ? 40.0 : 46.0;
    final titleSize = widget.isSmallScreen ? 13.5 : 15.0;
    final subtitleSize = widget.isSmallScreen ? 11.0 : 12.0;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.15 * _glowAnimation.value),
                blurRadius: 20 * _glowAnimation.value,
                spreadRadius: 2 * _glowAnimation.value,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: EdgeInsets.all(cardPadding),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            widget.color.withOpacity(0.15),
                            widget.color.withOpacity(0.05),
                            colorScheme.surface.withOpacity(0.8),
                          ]
                        : [
                            widget.color.withOpacity(0.08),
                            Colors.white.withOpacity(0.9),
                            Colors.white.withOpacity(0.95),
                          ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  border: Border.all(
                    color: widget.color.withOpacity(isDark ? 0.3 : 0.2),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    // Icon Container
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.color,
                            widget.color.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withOpacity(0.4 * _glowAnimation.value),
                            blurRadius: 12 * _glowAnimation.value,
                            spreadRadius: 2,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.icon,
                        color: Colors.white,
                        size: widget.isSmallScreen ? 22 : 26,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Text Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onSurface,
                              fontSize: titleSize,
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.7),
                              fontSize: subtitleSize,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Arrow Icon
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: widget.isSmallScreen ? 16 : 18,
                      color: widget.color.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
    this.monthlyEquivalent,
    this.tag,
    this.highlight = false,
    required this.onTap,
    required this.delay,
    this.isSmallScreen = false,
  });

  final AnimationController animationController;
  final Package package;
  final String title;
  final String price;
  final String billingPeriod;
  final String? monthlyEquivalent;
  final String? tag;
  final bool highlight;
  final VoidCallback onTap;
  final Duration delay;
  final bool isSmallScreen;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                gradient: widget.highlight
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF2E3192),
                          Color(0xFF1BFFFF),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                Color(0xFF1F1F2E),
                                Color(0xFF1A1A2E),
                              ]
                            : [
                                Colors.white,
                                Color(0xFFF8FAFC),
                              ],
                      ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.highlight
                      ? Colors.white.withOpacity(0.5)
                      : const Color(0xFF2E3192).withOpacity(0.2),
                  width: widget.highlight ? 2 : 1.5,
                ),
                boxShadow: widget.highlight
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2E3192).withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 0,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: const Color(0xFF1BFFFF).withOpacity(0.3),
                          blurRadius: 28,
                          spreadRadius: -4,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withOpacity(0.4)
                              : Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: -2,
                        ),
                      ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: EdgeInsets.all(widget.isSmallScreen ? 12.0 : 14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: widget.isSmallScreen ? 14.0 : 15.5,
                                  color: widget.highlight ? Colors.white : colorScheme.onSurface,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.highlight
                                    ? Colors.white.withOpacity(0.25)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: widget.highlight
                                      ? Colors.white
                                      : colorScheme.onSurface.withOpacity(0.3),
                                  width: 2,
                                ),
                                boxShadow: widget.highlight
                                    ? [
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                widget.highlight ? Icons.check_circle : Icons.circle_outlined,
                                color: widget.highlight
                                    ? Colors.white
                                    : colorScheme.onSurface.withOpacity(0.4),
                                size: widget.isSmallScreen ? 18 : 20,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: widget.isSmallScreen ? 2 : 4),
                        // ÜCRETSİZ DENEME VURGUSU - Her iki pakette de göster
                        if (hasFreeTrial)
                          Padding(
                            padding: EdgeInsets.only(bottom: widget.isSmallScreen ? 5 : 6),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: widget.isSmallScreen ? 8 : 10,
                                vertical: widget.isSmallScreen ? 4 : 5,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: widget.highlight
                                    ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
                                    : [const Color(0xFF1BFFFF), const Color(0xFF2E3192)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(widget.isSmallScreen ? 6 : 8),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.highlight
                                      ? const Color(0xFFFFD700).withOpacity(0.5)
                                      : const Color(0xFF1BFFFF).withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.celebration_rounded,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '7 GÜN BEDAVA DENE 🎁',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: widget.isSmallScreen ? 9.5 : 10.5,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              widget.price,
                              style: TextStyle(
                                fontSize: widget.isSmallScreen ? 22.0 : 26.0,
                                fontWeight: FontWeight.w900,
                                color: widget.highlight ? Colors.white : colorScheme.onSurface,
                                letterSpacing: -1.0,
                              ),
                            ),
                            SizedBox(width: widget.isSmallScreen ? 3 : 4),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.billingPeriod,
                                  style: TextStyle(
                                    fontSize: widget.isSmallScreen ? 11.0 : 13.0,
                                    fontWeight: FontWeight.w700,
                                    color: widget.highlight
                                        ? Colors.white.withOpacity(0.9)
                                        : colorScheme.onSurface.withOpacity(0.65),
                                  ),
                                ),
                                // Yıllık pakette aylık eşdeğeri göster
                                if (widget.monthlyEquivalent != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Aylık ${widget.monthlyEquivalent}',
                                    style: TextStyle(
                                      fontSize: widget.isSmallScreen ? 9.0 : 10.0,
                                      fontWeight: FontWeight.w800,
                                      color: widget.highlight
                                          ? const Color(0xFFFFD700)
                                          : colorScheme.secondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // TASARRUF ETİKETİ
                  if (widget.tag != null)
                    Positioned(
                      top: -12,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: widget.highlight
                              ? const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFF1BFFFF), Color(0xFF2E3192)],
                                ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.highlight
                                  ? const Color(0xFFFFD700).withOpacity(0.5)
                                  : const Color(0xFF1BFFFF).withOpacity(0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.highlight ? Icons.local_fire_department_rounded : Icons.star_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.tag!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 10.5,
                                letterSpacing: 0.4,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: const [
          _TrustBadge(icon: Icons.verified_user_rounded, text: '10.000+ Mutlu Öğrenci', color: Color(0xFF2E7D32)),
          _TrustBadge(icon: Icons.lock_rounded, text: 'Güvenli Ödeme', color: Color(0xFF4CAF50)),
          _TrustBadge(icon: Icons.cancel_schedule_send_rounded, text: '1 Tıkla İptal', color: Color(0xFF2196F3)),
          _TrustBadge(icon: Icons.trending_up_rounded, text: '%40 Not Artışı', color: Color(0xFFFF6F00)),
        ],
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(isDark ? 0.15 : 0.1),
            color.withOpacity(isDark ? 0.08 : 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  final bool isCompact;
  const _LegalFooter({this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _FooterLink(
            text: 'Kullanım Şartları',
            targetUrl: 'https://www.codenzi.com/taktik-kullanim-sozlesmesi.html'
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              width: 1,
              height: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
          ),
          const _FooterLink(
            text: 'Gizlilik Politikası',
            targetUrl: 'https://www.codenzi.com/taktik-gizlilik-politikasi.html'
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String text;
  final String targetUrl;

  const _FooterLink({required this.text, required this.targetUrl});

  Future<void> _launchURL(BuildContext context) async {
    final uri = Uri.parse(targetUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bağlantı açılamadı: $targetUrl')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => _launchURL(context),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
      ),
    );
  }
}

