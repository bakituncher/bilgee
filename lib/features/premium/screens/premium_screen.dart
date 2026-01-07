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

  // Modern Brand Colors
  final Color _bgDark = const Color(0xFF0F1115);
  final Color _primaryBrand = const Color(0xFF4C4DDC);
  final Color _accentBrand = const Color(0xFF00E5FF);
  final Color _successColor = const Color(0xFF00D26A);

  // Feature Data
  final List<Map<String, dynamic>> _features = [
    {
      'icon': Icons.school_rounded,
      'title': "Sınırsız Özel Ders Koçu",
      'desc': "Taktik Tavşan 7/24 yanınızda, her soruna çözüm."
    },
    {
      'icon': Icons.bolt_rounded,
      'title': "%300 Daha Hızlı Öğren",
      'desc': "Yapay zeka ile kişiselleştirilmiş hızlandırılmış plan."
    },
    {
      'icon': Icons.block_rounded,
      'title': "Reklamları Yok Et",
      'desc': "Kesintisiz odaklanma. Sadece dersine odaklan."
    },
    {
      'icon': Icons.analytics_rounded,
      'title': "Detaylı Hata Analizi",
      'desc': "Nerede yanlış yaptığını gör, netlerini artır."
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

    // Responsive: Ekran çok küçükse (iPhone SE gibi) bazı boşlukları kıs
    final isSmallScreen = size.height < 700;

    // Bottom Bar yüksekliğini hesapla (Scroll Padding için gerekli)
    final bottomBarHeight = 112.0 + bottomPadding + (isSmallScreen ? 10 : 30);

    String examSuffix = "";
    if (user?.selectedExam != null) {
      final exam = user!.selectedExam!.toLowerCase();
      if (exam == 'yks') examSuffix = " YKS";
      else if (exam == 'lgs') examSuffix = " LGS";
      else if (exam.startsWith('kpss')) examSuffix = " KPSS";
    }

    return Scaffold(
      backgroundColor: _bgDark,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: _handleBack,
                            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 28),
                            style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.1)),
                          ),
                          TextButton(
                            onPressed: _restorePurchases,
                            child: const Text("Geri Yükle", style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600)),
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
                                SizedBox(height: isSmallScreen ? 5 : 10),
                                const Icon(Icons.diamond_rounded, size: 48, color: Color(0xFF00E5FF)),
                                SizedBox(height: isSmallScreen ? 8 : 12),
                                ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    colors: [_primaryBrand, _accentBrand],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ).createShader(bounds),
                                  child: Text(
                                    "TAKTİK PRO$examSuffix",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 32 : 38,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                      height: 1,
                                    ),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 8 : 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: const Text(
                                    "1 kahve fiyatına başarının anahtarı",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 20 : 30),

                                // Feature Carousel (Fix: SizedBox yerine Container kullanıldı)
                                Container(
                                  height: size.height * 0.18,
                                  constraints: const BoxConstraints(minHeight: 120, maxHeight: 160),
                                  child: PageView.builder(
                                    controller: PageController(viewportFraction: 0.85),
                                    itemCount: _features.length,
                                    onPageChanged: (i) => setState(() => _currentCarouselIndex = i),
                                    itemBuilder: (ctx, index) => _buildModernFeatureCard(_features[index], index == _currentCarouselIndex),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(_features.length, (index) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    height: 6,
                                    width: _currentCarouselIndex == index ? 24 : 6,
                                    decoration: BoxDecoration(
                                      color: _currentCarouselIndex == index ? _accentBrand : Colors.white24,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  )),
                                ),
                              ],
                            ),
                          ),

                          SliverToBoxAdapter(child: SizedBox(height: isSmallScreen ? 20 : 40)),

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
                                        accentColor: _primaryBrand,
                                        badgeColor: _successColor,
                                      ),
                                    const SizedBox(height: 16),
                                    if (monthly != null)
                                      _ModernPricingCard(
                                        package: monthly,
                                        isSelected: _selectedPackage == monthly,
                                        isBestValue: false,
                                        savingsPercent: null,
                                        onTap: () => setState(() => _selectedPackage = monthly),
                                        accentColor: _primaryBrand,
                                        badgeColor: _successColor,
                                      ),

                                    const SizedBox(height: 24),

                                    // Trust Badges
                                    const Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 24,
                                      runSpacing: 10,
                                      children: [
                                        _TrustBadgeSmall(
                                          icon: Icons.lock_outline_rounded,
                                          label: "Güvenli Ödeme",
                                          color: Color(0xFF00D26A),
                                        ),
                                        _TrustBadgeSmall(
                                          icon: Icons.cancel_outlined,
                                          label: "Kolay İptal",
                                          color: Color(0xFF00E5FF),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 16),
                                    const _PriceTransparencyText(),
                                    // Bottom Bar kadar boşluk bırak
                                    SizedBox(height: bottomBarHeight),
                                  ]),
                                ),
                              );
                            },
                            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
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

          // 3. STICKY BOTTOM BAR
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_bgDark.withOpacity(0.8), _bgDark],
                    ),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding + 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_selectedPackage != null && _selectedPackage!.storeProduct.introductoryPrice?.price == 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.shield_outlined, size: 14, color: Colors.white54),
                                    const SizedBox(width: 6),
                                    Text(
                                      "7 Gün Ücretsiz Deneme, sonra ${_selectedPackage!.storeProduct.priceString}",
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),

                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: 1.0 + (_pulseController.value * 0.02),
                                  child: Container(
                                    width: double.infinity,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(colors: [_primaryBrand, _primaryBrand.withOpacity(0.8)]),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _primaryBrand.withOpacity(0.4 + (_pulseController.value * 0.2)),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        )
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _selectedPackage != null ? () => _purchasePackage(_selectedPackage!) : null,
                                        borderRadius: BorderRadius.circular(16),
                                        child: Center(
                                          child: _isPurchasing
                                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                                              : Text(
                                            (_selectedPackage?.storeProduct.introductoryPrice?.price == 0)
                                                ? "ÜCRETSİZ DENE"
                                                : "HEMEN BAŞLA",
                                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _FooterLink(text: "Kullanım Koşulları", url: "https://www.codenzi.com/terms"),
                                Container(height: 12, width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
                                _FooterLink(text: "Gizlilik", url: "https://www.codenzi.com/privacy"),
                              ],
                            ),
                          ],
                        ),
                      ),
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
            Container(color: _bgDark),
            Positioned(
              top: -size.height * 0.1,
              right: -size.width * 0.2,
              child: Transform.rotate(
                angle: _backgroundController.value * 2 * math.pi,
                child: Container(
                  width: size.width * 0.8, height: size.width * 0.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [_primaryBrand.withOpacity(0.2), Colors.transparent]),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: size.height * 0.1,
              left: -size.width * 0.1,
              child: Transform.translate(
                offset: Offset(0, math.sin(_backgroundController.value * 2 * math.pi) * 50),
                child: Container(
                  width: size.width * 0.6, height: size.width * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [_accentBrand.withOpacity(0.15), Colors.transparent]),
                  ),
                ),
              ),
            ),
            BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(color: Colors.transparent)),
          ],
        );
      },
    );
  }

  Widget _buildModernFeatureCard(Map<String, dynamic> item, bool isActive) {
    // Burada constraints hatası almamak için LayoutBuilder kullanılabilir ama
    // basitçe Container ile yapıyoruz.
    return AnimatedScale(
      scale: isActive ? 1.0 : 0.9,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isActive ? _primaryBrand.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(item['icon'], color: isActive ? _accentBrand : Colors.white54, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                      item['title'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isActive ? Colors.white : Colors.white70)
                  ),
                  const SizedBox(height: 4),
                  Text(
                      item['desc'],
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.2)
                  ),
                ],
              ),
            )
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
      bigPriceDisplay = "${monthlyEq.toStringAsFixed(2)}₺ /ay";
      smallSubtext = "Yıllık ${package.storeProduct.priceString} faturalanır";

      if (compareMonthlyPrice != null) {
        final totalYearlyIfPaidMonthly = compareMonthlyPrice! * 12;
        strikeThroughPrice = "${totalYearlyIfPaidMonthly.toStringAsFixed(2)}₺";
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(isSelected ? 2 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isSelected
              ? LinearGradient(colors: [accentColor, const Color(0xFF00E5FF)])
              : LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
          boxShadow: isSelected
              ? [BoxShadow(color: accentColor.withOpacity(0.25), blurRadius: 12, spreadRadius: 0)]
              : [],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1A1D25) : const Color(0xFF16181E),
            borderRadius: BorderRadius.circular(18),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Radio Icon
                Center(
                  child: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? accentColor : Colors.transparent,
                      border: Border.all(
                          color: isSelected ? accentColor : Colors.grey.withOpacity(0.4),
                          width: 2
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

                // 2. Orta Kısım
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            isAnnual ? "Yıllık Plan" : "Aylık Plan",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 16
                            ),
                          ),
                          if (isBestValue && savingsPercent != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "%${savingsPercent!.toStringAsFixed(0)} KAZANÇ",
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900
                                ),
                              ),
                            )
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (hasTrial)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "7 GÜN ÜCRETSİZ, SONRA",
                            style: TextStyle(
                                color: accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5
                            ),
                          ),
                        )
                      else
                        Text(
                          smallSubtext,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 3. Fiyat Kısmı
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isAnnual && strikeThroughPrice != null)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            strikeThroughPrice,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          bigPriceDisplay,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (!isAnnual)
                        Text(
                          "/ay",
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 10
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
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        'Abonelik otomatik yenilenir, dilediğin zaman iptal edebilirsin.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, height: 1.4),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String text;
  final String url;
  const _FooterLink({required this.text, required this.url});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url)),
      child: Text(text, style: const TextStyle(color: Colors.white38, fontSize: 11, decoration: TextDecoration.underline)),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}