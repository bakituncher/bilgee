import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// --- REVENUECAT DEVRE DIŞI ---
// import 'package:purchases_flutter/purchases_flutter.dart';
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
  MockPackage? _selectedPackage;

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
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive değerler
    final isSmallScreen = screenHeight < 700;
    final isMediumScreen = screenHeight >= 700 && screenHeight < 850;

    final marketingSlides = [
      (
      title: 'Sınırsız TaktikAI Koçu',
      subtitle: 'Yapay zeka koçunuzla sınırsız strateji ve ders desteği.',
      icon: Icons.rocket_launch_rounded,
      color: const Color(0xFF5b3d88)
      ),
      (
      title: 'Reklamlardan Arındırılmış Deneyim',
      subtitle: 'Hiç reklam olmadan kesintisiz çalışma ve odaklanma.',
      icon: Icons.block_rounded,
      color: const Color(0xFFE63946)
      ),
      (
      title: 'Kişiselleştirilmiş Yol Haritası',
      subtitle: 'Hedeflerinize göre otomatik ayarlanan haftalık plan.',
      icon: Icons.map_rounded,
      color: Theme.of(context).colorScheme.secondary
      ),
      (
      title: 'Cevher Atölyesi Full Erişim',
      subtitle: 'Hata analizi, özel ders notları ve testler.',
      icon: Icons.diamond_outlined,
      color: const Color(0xFFFFB020)
      ),
      (
      title: 'Gelişmiş Test Analizi',
      subtitle: 'Yapay zeka yorumlarıyla detaylı performans raporları.',
      icon: Icons.analytics_rounded,
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

          Column(
            children: [
              // 1. ÜST KISIM (Sabit)
              _buildCustomHeader(context),

              // 2. SCROLLABLE CONTENT
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // PAZARLAMA ALANI - Header
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: isSmallScreen ? 6 : 10,
                        ),
                        child: _AnimatedHeader(
                          slideController: _headerSlideController,
                          fadeController: _fadeController,
                          isSmallScreen: isSmallScreen,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 6 : 10),

                      // PageView (Özellik Carousel - DYNAMIC)
                      _buildMarketingCarousel(marketingSlides, isSmallScreen, isMediumScreen),
                      SizedBox(height: isSmallScreen ? 8 : 12),

                      // Page Indicator
                      _buildPageIndicator(marketingSlides),
                      SizedBox(height: isSmallScreen ? 12 : 18),

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
              ),
            ],
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

  Widget _buildMarketingCarousel(
    List<({String title, String subtitle, IconData icon, Color color})> marketingSlides,
    bool isSmallScreen,
    bool isMediumScreen,
  ) {
    final carouselHeight = isSmallScreen ? 85.0 : (isMediumScreen ? 100.0 : 115.0);

    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        height: carouselHeight,
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
              isSmallScreen: isSmallScreen,
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
        padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 15 : 19),
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
              color: const Color(0xFF2E3192).withOpacity(0.5),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFF1BFFFF).withOpacity(0.3),
              blurRadius: 32,
              spreadRadius: -4,
              offset: const Offset(0, 12),
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
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: isSmallScreen ? 22 : 26,
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 12),
                        Text(
                          'Hemen Başla',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16.5 : 19.0,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 12),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: isSmallScreen ? 22 : 26,
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
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(marketingSlides.length, (index) {
            final double scale = 1.0 - (index - currentPage).abs().clamp(0.0, 1.0) * 0.3;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: index == currentPage.round() ? 24.0 : 8.0,
                height: 8.0,
                decoration: BoxDecoration(
                  gradient: index == currentPage.round()
                      ? const LinearGradient(
                          colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  color: index == currentPage.round()
                      ? null
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: index == currentPage.round()
                      ? [
                          BoxShadow(
                            color: const Color(0xFF2E3192).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildPurchaseOptions(BuildContext context, WidgetRef ref, dynamic offerings, bool isSmallScreen) {
    // --- REVENUECAT DEVRE DIŞI - HİÇ PAKET YOK ---
    MockPackage? monthly, yearly;
    double? savePercent;

    // RevenueCat devre dışı olduğu için paket bilgisi yok
    // Offerings null veya boş olacak
    /*
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
    */
    // --- END OF PACKAGE EXTRACTION ---

    // Eğer hiç seçim yapılmadıysa, aylık planı varsayılan olarak seç
    _selectedPackage ??= monthly;

    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: isSmallScreen ? 10 : 14),
        child: Column(
          children: [
            if (yearly != null)
              _PurchaseOptionCard(
                animationController: _cardPopController,
                package: yearly,
                title: 'Yıllık PRO Plan',
                price: yearly.storeProduct.priceString,
                billingPeriod: '/ yıl',
                tag: savePercent != null ? '%${savePercent.toStringAsFixed(0)} İNDİRİM' : 'EN POPÜLER',
                highlight: _selectedPackage?.identifier == yearly.identifier,
                delay: const Duration(milliseconds: 0),
                isSmallScreen: isSmallScreen,
                onTap: () {
                  setState(() => _selectedPackage = yearly);
                },
              ),
            if (yearly != null && monthly != null)
              SizedBox(height: isSmallScreen ? 8 : 10),
            if (monthly != null)
              _PurchaseOptionCard(
                animationController: _cardPopController,
                package: monthly,
                title: 'Aylık PRO Plan',
                price: monthly.storeProduct.priceString,
                billingPeriod: '/ ay',
                tag: 'ESNEKLİK',
                highlight: _selectedPackage?.identifier == monthly.identifier,
                delay: const Duration(milliseconds: 100),
                isSmallScreen: isSmallScreen,
                onTap: () {
                  setState(() => _selectedPackage = monthly);
                },
              ),
            // Ana Abone Ol Butonu
            SizedBox(height: isSmallScreen ? 16 : 20),
            _buildSubscribeButton(context, ref, isSmallScreen),
          ],
        ),
      ),
    );
  }

  // --- PURCHASE LOGIC (KEPT AS IS) ---

  Future<void> _purchasePackage(BuildContext context, WidgetRef ref, MockPackage package) async {
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
    final textColor = theme.colorScheme.onSurface.withOpacity(0.6);
    final textStyle = theme.textTheme.bodySmall?.copyWith(color: textColor, height: 1.25, fontSize: 9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Text(
        'Abonelik, siz iptal edene kadar seçtiğiniz tarife (aylık/yıllık) üzerinden otomatik olarak yenilenir. '
            'Ücretsiz deneme süresi (varsa) sonunda ücretlendirme başlar. '
            'Aboneliğinizi Google Play Store\'daki "Abonelikler" bölümünden istediğiniz zaman kolayca iptal edebilirsiniz. '
            'Fiyatlara tüm vergiler dahildir.',
        textAlign: TextAlign.center,
        style: textStyle,
      ),
    );
  }
}

// --- 1. ANIMATED HEADER (No Change) ---

class _AnimatedHeader extends StatelessWidget {
  final AnimationController slideController;
  final AnimationController fadeController;
  final bool isSmallScreen;

  const _AnimatedHeader({
    required this.slideController,
    required this.fadeController,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconSize = isSmallScreen ? 28.0 : 36.0;
    final titleSize = isSmallScreen ? 24.0 : 30.0;
    final subtitleSize = isSmallScreen ? 13.0 : 15.0;
    final iconPadding = isSmallScreen ? 8.0 : 10.0;

    return Column(
      children: [
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
              .animate(CurvedAnimation(parent: slideController, curve: Curves.easeOutCubic)),
          child: FadeTransition(
            opacity: fadeController,
            child: Container(
              padding: EdgeInsets.all(iconPadding),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF2E3192),
                    Color(0xFF1BFFFF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E3192).withOpacity(0.4),
                    blurRadius: isSmallScreen ? 20 : 24,
                    spreadRadius: isSmallScreen ? 1 : 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFF1BFFFF).withOpacity(0.3),
                    blurRadius: isSmallScreen ? 24 : 32,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Icon(
                Icons.diamond_rounded,
                size: iconSize,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 10 : 14),
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
              .animate(CurvedAnimation(parent: slideController, curve: const Interval(0.2, 1, curve: Curves.easeOutCubic))),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: fadeController, curve: const Interval(0.2, 1)),
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
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 5 : 8),
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
              .animate(CurvedAnimation(parent: slideController, curve: const Interval(0.4, 1, curve: Curves.easeOutCubic))),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: fadeController, curve: const Interval(0.4, 1)),
            child: Text(
              'Rakiplerine fark at, hedefe koş',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
                fontWeight: FontWeight.w600,
                fontSize: subtitleSize,
                height: 1.3,
                letterSpacing: -0.2,
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
  final bool isSmallScreen;

  const _MarketingSlideCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardPadding = isSmallScreen ? 12.0 : 16.0;
    final iconSize = isSmallScreen ? 32.0 : 38.0;
    final iconInnerSize = isSmallScreen ? 18.0 : 22.0;
    final titleSize = isSmallScreen ? 13.0 : 15.0;
    final subtitleSize = isSmallScreen ? 10.5 : 12.0;
    final spacing = isSmallScreen ? 9.0 : 12.0;

    return Container(
      padding: EdgeInsets.all(cardPadding),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    colorScheme.surface,
                    Color.lerp(colorScheme.surface, color, 0.08)!,
                  ]
                : [
                    Colors.white,
                    Color.lerp(Colors.white, color, 0.08)!,
                  ],
          ),
          borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
          border: Border.all(
            color: color.withOpacity(isDark ? 0.4 : 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: isSmallScreen ? 16 : 20,
              spreadRadius: 0,
              offset: Offset(0, isSmallScreen ? 6 : 8),
            ),
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 12,
              spreadRadius: -2,
              offset: const Offset(0, 4),
            ),
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color,
                      color.withOpacity(0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: isSmallScreen ? 10 : 12,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: iconInnerSize),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                        fontSize: titleSize,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallScreen ? 3 : 5),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                        fontSize: subtitleSize,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
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
    this.isSmallScreen = false,
  });

  final AnimationController animationController;
  final MockPackage package;
  final String title;
  final String price;
  final String billingPeriod;
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
                                Color(0xFF1A1A2E),
                                Color(0xFF16213E),
                              ]
                            : [
                                Colors.white,
                                Color(0xFFF8F9FA),
                              ],
                      ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.highlight
                      ? Colors.white.withOpacity(0.4)
                      : const Color(0xFF2E3192).withOpacity(0.15),
                  width: widget.highlight ? 3 : 1.5,
                ),
                boxShadow: widget.highlight
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2E3192).withOpacity(0.6),
                          blurRadius: 32,
                          spreadRadius: 0,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: const Color(0xFF1BFFFF).withOpacity(0.4),
                          blurRadius: 48,
                          spreadRadius: -4,
                          offset: const Offset(0, 16),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withOpacity(0.3)
                              : Colors.black.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                          spreadRadius: -2,
                        ),
                      ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: EdgeInsets.all(widget.isSmallScreen ? 14.0 : 18.0),
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
                                  fontSize: widget.isSmallScreen ? 15.0 : 18.0,
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
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: widget.highlight
                                      ? Colors.white
                                      : colorScheme.onSurface.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                widget.highlight ? Icons.check_circle : Icons.circle_outlined,
                                color: widget.highlight
                                    ? Colors.white
                                    : colorScheme.onSurface.withOpacity(0.4),
                                size: widget.isSmallScreen ? 20 : 24,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: widget.isSmallScreen ? 3 : 5),
                        // ÜCRETSİZ DENEME VURGUSU
                        if (hasFreeTrial && !widget.highlight)
                          Padding(
                            padding: EdgeInsets.only(bottom: widget.isSmallScreen ? 6 : 8),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: widget.isSmallScreen ? 8 : 10,
                                vertical: widget.isSmallScreen ? 3 : 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1BFFFF).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(widget.isSmallScreen ? 6 : 8),
                                border: Border.all(color: const Color(0xFF1BFFFF).withOpacity(0.4)),
                              ),
                              child: Text(
                                '🎁 İLK 7 GÜN ÜCRETSİZ DENE',
                                style: TextStyle(
                                  color: const Color(0xFF1BFFFF),
                                  fontWeight: FontWeight.w900,
                                  fontSize: widget.isSmallScreen ? 9.5 : 11.0,
                                  letterSpacing: 0.5,
                                ),
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
                                fontSize: widget.isSmallScreen ? 24.0 : 28.0,
                                fontWeight: FontWeight.w900,
                                color: widget.highlight ? Colors.white : colorScheme.onSurface,
                                letterSpacing: -1,
                              ),
                            ),
                            SizedBox(width: widget.isSmallScreen ? 3 : 5),
                            Text(
                              widget.billingPeriod,
                              style: TextStyle(
                                fontSize: widget.isSmallScreen ? 12.0 : 14.0,
                                fontWeight: FontWeight.w600,
                                color: widget.highlight
                                    ? Colors.white.withOpacity(0.85)
                                    : colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),

                      ],
                    ),
                  ),
                  // TASARRUF ETiketinin Konumlandırılması
                  if (widget.tag != null)
                    Positioned(
                      top: -14,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.highlight
                                  ? const Color(0xFFFFD700).withOpacity(0.5)
                                  : const Color(0xFF1BFFFF).withOpacity(0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.highlight ? Icons.local_fire_department_rounded : Icons.star_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.tag!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.5,
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TrustRow(icon: Icons.lock_rounded, text: 'Güvenli Ödeme'),
          SizedBox(width: 14),
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
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 3.5),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 10.5),
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
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 3.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _FooterLink(text: 'Kullanım Şartları', targetUrl: 'https://www.codenzi.com/taktik-kullanim-sozlesmesi.html'),
              const SizedBox(width: 7),
              Text('|', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38), fontSize: 9)),
              const SizedBox(width: 7),
              const _FooterLink(text: 'Gizlilik Politikası', targetUrl: 'https://www.codenzi.com/taktik-gizlilik-politikasi.html'),
            ],
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
    final color = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    return GestureDetector(
      onTap: () => _launchURL(context),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
      ),
    );
  }
}

