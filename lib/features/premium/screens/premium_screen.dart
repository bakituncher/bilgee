import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:taktik/core/services/revenuecat_service.dart';
import 'package:collection/collection.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:taktik/data/providers/shared_prefs_provider.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'dart:ui';
import 'dart:async';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> with TickerProviderStateMixin {
  late final AnimationController _backgroundController;
  late final AnimationController _pulseController;

  // State
  bool _isPurchasing = false;
  Package? _selectedPackage;
  int _currentCarouselIndex = 0;

  // Modern Brand Colors - Premium Pink Theme (Instagram/Google Level)
  final Color _bgLight = const Color(0xFFFFFBFE);
  final Color _bgSecondary = const Color(0xFFFFF0F5);
  final Color _primaryPink = const Color(0xFFFF4D8D);
  final Color _accentPink = const Color(0xFFFF6BA5);
  final Color _deepPink = const Color(0xFFE91E63);
  final Color _purpleAccent = const Color(0xFF9C27B0);
  final Color _successColor = const Color(0xFF4CAF50);
  final Color _textPrimary = const Color(0xFF1A1A1A);
  final Color _textSecondary = const Color(0xFF666666);

  // Feature Data - Premium Benefits
  final List<Map<String, dynamic>> _features = [
    {
      'icon': Icons.auto_awesome_rounded,
      'title': "Kişisel Başarı Koçun",
      'desc': "Sana özel stratejiyle rakiplerine fark at, zirveye oyna.",
      'gradient': [const Color(0xFFFF6BA5), const Color(0xFFFF4D8D)]
    },
    {
      'icon': Icons.rocket_launch_rounded,
      'title': "Rakiplerinden Hızlı Ol",
      'desc': "Boşa çalışma! Nokta atışı analizlerle 3 kat hızlı ilerle.",
      'gradient': [const Color(0xFF9C27B0), const Color(0xFFE91E63)]
    },
    {
      'icon': Icons.visibility_off_rounded,
      'title': "%100 Saf Odaklanma",
      'desc': "Dikkatin dağılmasın. Reklam yok, sadece sen ve hedeflerin var.",
      'gradient': [const Color(0xFFFF4D8D), const Color(0xFF9C27B0)]
    },
    {
      'icon': Icons.insights_rounded,
      'title': "Stratejik Analiz",
      'desc': "Taktik Tavşan zayıf yönlerini bulsun, sınavda sürpriz yaşama.",
      'gradient': [const Color(0xFFE91E63), const Color(0xFFFF6BA5)]
    },
  ];

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // --- LOGIC ---

  Future<void> _handleBack() async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await prefs.setString('premium_screen_last_shown', DateTime.now().toString().split(' ')[0]);
    } catch (_) {}

    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _purchasePackage(Package package) async {
    if (_isPurchasing) return;
    setState(() => _isPurchasing = true);
    HapticFeedback.heavyImpact();

    try {
      final outcome = await RevenueCatService.makePurchase(package);

      if (!context.mounted) return;

      if (outcome.success) {
        try {
          await FirebaseFunctions.instanceFor(region: 'us-central1')
              .httpsCallable('premium-syncRevenueCatPremiumCallable')
              .call();
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Harika! Premium özellikler aktif ediliyor...'), backgroundColor: _successColor)
        );
        _handleBack();
      } else if (outcome.error != null && !outcome.cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: ${outcome.error}', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _restorePurchases() async {
    if (_isPurchasing) return;
    setState(() => _isPurchasing = true);

    try {
      await RevenueCatService.restorePurchases();
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      await functions.httpsCallable('premium-syncRevenueCatPremiumCallable').call();

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Üyelikler geri yüklendi ve eşitlendi.'), backgroundColor: _successColor)
        );
      }
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if(mounted) setState(() => _isPurchasing = false);
    }
  }

  // --- BUILD ---
  @override
  Widget build(BuildContext context) {
    final offeringsAsync = ref.watch(offeringsProvider);
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final user = ref.watch(userProfileProvider).valueOrNull;

    // Responsive: Ekran boyutuna göre boşlukları optimize et
    final isSmallScreen = size.height < 700;
    final isMediumScreen = size.height >= 700 && size.height < 850;

    // Bottom Bar yüksekliğini hesapla (Scroll Padding için gerekli)
    final bottomBarHeight = 80.0 + bottomPadding + (isSmallScreen ? 4 : 8);

    String examSuffix = "";
    if (user?.selectedExam != null) {
      final exam = user!.selectedExam!.toLowerCase();
      if (exam == 'yks') examSuffix = " YKS";
      else if (exam == 'lgs') examSuffix = " LGS";
      else if (exam == 'ags') examSuffix = " AGS - ÖABT";
      else if (exam.startsWith('kpss')) examSuffix = " KPSS";
    }

    return Scaffold(
      backgroundColor: _bgLight,
      body: Stack(
        children: [
          // 1. Animated Mesh Background
          _buildModernBackground(size),

          // 2. Main Content
          SafeArea(
            bottom: false, // Bottom bar handle ediyor
            child: Center(
              // Tabletler için genişliği sınırla
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: isSmallScreen ? 8 : 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: _textPrimary.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: _handleBack,
                              icon: Icon(Icons.close_rounded, color: _textPrimary, size: 24),
                              style: IconButton.styleFrom(
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_primaryPink.withOpacity(0.1), _purpleAccent.withOpacity(0.1)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _primaryPink.withOpacity(0.2)),
                            ),
                            child: GestureDetector(
                              onTap: _restorePurchases,
                              child: Text(
                                "Geri Yükle",
                                style: TextStyle(
                                  color: _deepPink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),

                    Expanded(
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              children: [
                                SizedBox(height: isSmallScreen ? 4 : (isMediumScreen ? 8 : 12)),
                                // Premium Badge/Icon
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [_primaryPink, _purpleAccent],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _primaryPink.withOpacity(0.3),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      )
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.diamond_rounded,
                                    size: isSmallScreen ? 28 : 32,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 8 : 10),
                                // Title with Gradient
                                ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    colors: [_primaryPink, _purpleAccent, _deepPink],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ).createShader(bounds),
                                  child: Text(
                                    "TAKTİK PRO$examSuffix",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 26 : 30,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 6 : 8),
                                // Subtitle
                                Text(
                                  "Başarının anahtarı artık senin elinde",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 6 : 8),
                                // Coffee Price Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _primaryPink.withOpacity(0.1),
                                        _purpleAccent.withOpacity(0.1)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _primaryPink.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.local_cafe_rounded,
                                        color: _deepPink,
                                        size: 14
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        "1 kahve fiyatına",
                                        style: TextStyle(
                                          color: _deepPink,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 12 : (isMediumScreen ? 14 : 16)),

                                // Feature Carousel - Modern Cards
                                SizedBox(
                                  height: size.height * 0.12,
                                  child: PageView.builder(
                                    controller: PageController(viewportFraction: 0.88),
                                    itemCount: _features.length,
                                    onPageChanged: (i) => setState(() => _currentCarouselIndex = i),
                                    itemBuilder: (ctx, index) => _buildModernFeatureCard(_features[index], index == _currentCarouselIndex),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Page Indicators - Pink Theme
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(_features.length, (index) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    height: 6,
                                    width: _currentCarouselIndex == index ? 28 : 6,
                                    decoration: BoxDecoration(
                                      gradient: _currentCarouselIndex == index
                                        ? LinearGradient(colors: [_primaryPink, _purpleAccent])
                                        : null,
                                      color: _currentCarouselIndex == index ? null : _textSecondary.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  )),
                                ),
                              ],
                            ),
                          ),

                          SliverToBoxAdapter(child: SizedBox(height: isSmallScreen ? 12 : (isMediumScreen ? 16 : 20))),

                          // PRICING SECTION
                          offeringsAsync.when(
                            data: (offerings) {
                              Package? monthly, yearly;
                              double? savePercent;
                              double? monthlyPriceVal;

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
                                    monthlyPriceVal = mPrice;
                                    if (mPrice > 0 && yPrice > 0) {
                                      savePercent = (1 - (yPrice / (mPrice * 12))) * 100;
                                    }
                                  }
                                }
                              }

                              if (_selectedPackage == null) _selectedPackage = yearly ?? monthly;

                              return SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    if (yearly != null)
                                      _ModernPricingCard(
                                        package: yearly,
                                        isSelected: _selectedPackage == yearly,
                                        isBestValue: true,
                                        savingsPercent: savePercent,
                                        compareMonthlyPrice: monthlyPriceVal,
                                        onTap: () => setState(() => _selectedPackage = yearly),
                                        accentColor: _primaryPink,
                                        badgeColor: _successColor,
                                      ),
                                    const SizedBox(height: 12),
                                    if (monthly != null)
                                      _ModernPricingCard(
                                        package: monthly,
                                        isSelected: _selectedPackage == monthly,
                                        isBestValue: false,
                                        savingsPercent: null,
                                        onTap: () => setState(() => _selectedPackage = monthly),
                                        accentColor: _primaryPink,
                                        badgeColor: _successColor,
                                      ),

                                    const SizedBox(height: 16),

                                    // Trust Badges - Modern Design
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: [
                                        _TrustBadgeSmall(
                                          icon: Icons.verified_user_rounded,
                                          label: "Güvenli Ödeme",
                                          color: _successColor,
                                        ),
                                        _TrustBadgeSmall(
                                          icon: Icons.event_available_rounded,
                                          label: "İstediğin Zaman İptal",
                                          color: _deepPink,
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),
                                    const _PriceTransparencyText(),
                                    // Bottom Bar kadar boşluk bırak
                                    SizedBox(height: bottomBarHeight),
                                  ]),
                                ),
                              );
                            },
                            loading: () => SliverToBoxAdapter(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(_primaryPink),
                                  ),
                                ),
                              ),
                            ),
                            error: (_, __) => const SliverToBoxAdapter(child: SizedBox()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. STICKY BOTTOM BAR - Premium Pink Theme
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: _bgLight.withOpacity(0.95),
                border: Border(
                  top: BorderSide(
                    color: _primaryPink.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _primaryPink.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, isSmallScreen ? 12 : 14, 20, bottomPadding + (isSmallScreen ? 6 : 8)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_pulseController.value * 0.015),
                              child: Container(
                                width: double.infinity,
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(26),
                                  gradient: LinearGradient(
                                    colors: [_primaryPink, _purpleAccent, _deepPink],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _primaryPink.withOpacity(0.4 + (_pulseController.value * 0.2)),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _selectedPackage != null ? () => _purchasePackage(_selectedPackage!) : null,
                                    borderRadius: BorderRadius.circular(26),
                                    child: Center(
                                      child: _isPurchasing
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 3,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.diamond_rounded,
                                                  color: Colors.white,
                                                  size: 22,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  (_selectedPackage?.storeProduct.introductoryPrice?.price == 0) &&
                                                  (_selectedPackage?.packageType == PackageType.monthly ||
                                                   (!(_selectedPackage?.identifier.toLowerCase().contains('annual') ?? false) &&
                                                    !(_selectedPackage?.identifier.toLowerCase().contains('year') ?? false)))
                                                      ? "ÜCRETSİZ DENE"
                                                      : "HEMEN BAŞLA",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _FooterLink(
                              text: "Kullanım Koşulları",
                              url: "https://www.codenzi.com/terms",
                              color: _textSecondary,
                            ),
                            Container(
                              height: 12,
                              width: 1,
                              color: _textSecondary.withOpacity(0.3),
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            _FooterLink(
                              text: "Gizlilik",
                              url: "https://www.codenzi.com/privacy",
                              color: _textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- VISUAL HELPER METHODS ---

  Widget _buildModernBackground(Size size) {
    return AnimatedBuilder(
      animation: _backgroundController,
      builder: (context, child) {
        return Stack(
          children: [
            // Base Light Background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_bgLight, _bgSecondary, _bgLight],
                ),
              ),
            ),
            // Animated Pink Gradient Blob - Top Right
            Positioned(
              top: -size.height * 0.15,
              right: -size.width * 0.2,
              child: Transform.rotate(
                angle: _backgroundController.value * 2 * math.pi * 0.5,
                child: Container(
                  width: size.width * 0.9,
                  height: size.width * 0.9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _primaryPink.withOpacity(0.15),
                        _accentPink.withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Animated Purple Gradient Blob - Bottom Left
            Positioned(
              bottom: size.height * 0.05,
              left: -size.width * 0.15,
              child: Transform.translate(
                offset: Offset(
                  math.sin(_backgroundController.value * 2 * math.pi) * 30,
                  math.cos(_backgroundController.value * 2 * math.pi) * 20,
                ),
                child: Container(
                  width: size.width * 0.7,
                  height: size.width * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _purpleAccent.withOpacity(0.12),
                        _deepPink.withOpacity(0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Subtle blur effect for modern feel
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(color: Colors.transparent),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModernFeatureCard(Map<String, dynamic> item, bool isActive) {
    final gradient = item['gradient'] as List<Color>? ?? [_primaryPink, _purpleAccent];

    return AnimatedScale(
      scale: isActive ? 1.0 : 0.94,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? gradient[0].withOpacity(0.3) : _textSecondary.withOpacity(0.1),
            width: 2,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: gradient[0].withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            // Icon with gradient background
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: isActive
                    ? LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [
                          _textSecondary.withOpacity(0.1),
                          _textSecondary.withOpacity(0.05),
                        ],
                      ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item['icon'],
                color: isActive ? Colors.white : _textSecondary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item['title'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: isActive ? _textPrimary : _textSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['desc'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: _textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Pricing Card ---

class _ModernPricingCard extends StatelessWidget {
  final Package package;
  final bool isSelected;
  final bool isBestValue;
  final VoidCallback onTap;
  final Color accentColor;
  final Color badgeColor;
  final double? savingsPercent;
  final double? compareMonthlyPrice;

  const _ModernPricingCard({
    required this.package,
    required this.isSelected,
    required this.isBestValue,
    required this.onTap,
    required this.accentColor,
    required this.badgeColor,
    this.savingsPercent,
    this.compareMonthlyPrice,
  });

  @override
  Widget build(BuildContext context) {
    final isAnnual = package.packageType == PackageType.annual ||
        package.identifier.toLowerCase().contains('annual') ||
        package.identifier.toLowerCase().contains('year');

    final hasTrial = package.storeProduct.introductoryPrice?.price == 0;

    String bigPriceDisplay = "";
    String smallSubtext = "";
    String? strikeThroughPrice;

    if (isAnnual) {
      final monthlyEq = package.storeProduct.price / 12;
      bigPriceDisplay = "₺${monthlyEq.toStringAsFixed(2)} /ay";
      smallSubtext = "Yıllık ${package.storeProduct.priceString} faturalanır";

      if (compareMonthlyPrice != null) {
        strikeThroughPrice = "₺${compareMonthlyPrice!.toStringAsFixed(2)}";
      }
    } else {
      bigPriceDisplay = package.storeProduct.priceString;
      smallSubtext = "Her ay yenilenir";
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(isSelected ? 3 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: isSelected
              ? LinearGradient(
                  colors: [accentColor, const Color(0xFF9C27B0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          border: !isSelected
              ? Border.all(
                  color: const Color(0xFFE0E0E0),
                  width: 1.5,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(21),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Radio Icon - Modern Checkbox Style
                Center(
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [accentColor, const Color(0xFF9C27B0)],
                            )
                          : null,
                      color: isSelected ? null : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? Colors.transparent : const Color(0xFFBDBDBD),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 14),

                // 2. Orta Kısım - Plan Details
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            isAnnual ? "Yıllık Plan" : "Aylık Plan",
                            style: TextStyle(
                              color: const Color(0xFF1A1A1A),
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (isBestValue && savingsPercent != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [badgeColor, badgeColor.withOpacity(0.8)],
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: badgeColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Text(
                                "%${savingsPercent!.toStringAsFixed(0)} TASARRUF",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (hasTrial && !isAnnual)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [accentColor.withOpacity(0.15), accentColor.withOpacity(0.05)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "🎁 7 GÜN ÜCRETSİZ DENE!",
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        )
                      else
                        Text(
                          smallSubtext,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // 3. Fiyat Kısmı - Premium Style
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isAnnual && strikeThroughPrice != null)
                        Text(
                          strikeThroughPrice,
                          style: TextStyle(
                            color: const Color(0xFF999999),
                            fontSize: 13,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: const Color(0xFF999999),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: ShaderMask(
                          shaderCallback: (bounds) => isSelected
                              ? LinearGradient(
                                  colors: [accentColor, const Color(0xFF9C27B0)],
                                ).createShader(bounds)
                              : const LinearGradient(
                                  colors: [Color(0xFF1A1A1A), Color(0xFF1A1A1A)],
                                ).createShader(bounds),
                          child: Text(
                            bigPriceDisplay,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      if (!isAnnual)
                        const SizedBox(height: 2),
                      if (!isAnnual)
                        Text(
                          "/ay",
                          style: TextStyle(
                            color: const Color(0xFF666666),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
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
      );
  }
}

class _PriceTransparencyText extends StatelessWidget {
  const _PriceTransparencyText();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'Abonelik otomatik yenilenir, dilediğin zaman iptal edebilirsin.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: const Color(0xFF666666),
          fontSize: 11,
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String text;
  final String url;
  final Color color;

  const _FooterLink({
    required this.text,
    required this.url,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url)),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _TrustBadgeSmall extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TrustBadgeSmall({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

