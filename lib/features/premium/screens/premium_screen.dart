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
  late final PageController _featurePageController;
  Timer? _autoScrollTimer;

  // State
  bool _isPurchasing = false;
  Package? _selectedPackage;
  int _currentCarouselIndex = 0;
  bool _userInteracting = false;
  bool _debugTrialOverride = false; // Debug için deneme kontrolü

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

  // Feature Data
  final List<Map<String, dynamic>> _features = [
    {
      'icon': Icons.camera_enhance_rounded,
      'title': "Saniyeler İçinde Çözdür",
      'desc': "Sorunun fotoğrafını çek, anında çözüm al."
    },
    {
      'icon': Icons.calendar_month_rounded,
      'title': "Haftalık Akıllı Planlama",
      'desc': "Sana özel hızlandırılmış programla hedefine %300 daha hızlı ulaş."
    },
    {
      'icon': Icons.quiz_rounded,
      'title': "Sınırsız Test Çözümü",
      'desc': "Reels kaydırır gibi test çöz, kendini sına."
    },
    {
      'icon': Icons.auto_stories_rounded,
      'title': "Özel Konu Özetleri",
      'desc': "Her konuyu özetlenmiş haliyle hızlıca öğren."
    },
    {
      'icon': Icons.analytics_rounded,
      'title': "Detaylı Hata Analizi",
      'desc': "Nerede yanlış yaptığını gör, netlerini artır."
    },
    {
      'icon': Icons.save_rounded,
      'title': "Etütleri Kaydet",
      'desc': "Etüt odasındaki çalışmalarını kaydet, istediğin zaman tekrar et."
    },
    {
      'icon': Icons.block_rounded,
      'title': "Reklamları Yok Et",
      'desc': "Kesintisiz odaklanma. Sadece dersine odaklan."
    },
  ];

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _featurePageController = PageController(viewportFraction: 0.85);

    // Otomatik kart geçişi - 3 saniyede bir
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_userInteracting && mounted) {
        final nextIndex = (_currentCarouselIndex + 1) % _features.length;
        _featurePageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _backgroundController.dispose();
    _pulseController.dispose();
    _featurePageController.dispose();
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
          // Backend sync işlemi
          await FirebaseFunctions.instanceFor(region: 'us-central1')
              .httpsCallable('premium-syncRevenueCatPremiumCallable')
              .call();
        } catch (_) {}

        // --- DÜZELTME BURADA YAPILDI ---
        // Eski kod: _handleBack();
        // Yeni kod: Başarılı satın alımdan sonra karşılama ekranına git
        if (mounted) {
          context.go(AppRoutes.premiumWelcome);
        }
        // -------------------------------

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
    if (_isPurchasing) return; // Zaten bir işlem varsa tekrar tetikleme
    setState(() => _isPurchasing = true);
    HapticFeedback.mediumImpact();

    // Kullanıcıya işlemin başladığını bildir
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Satın alımlar kontrol ediliyor ve sunucuyla eşitleniyor...'),
        backgroundColor: Colors.blueGrey,
        duration: Duration(milliseconds: 1500),
      ),
    );

    try {
      // 1. RevenueCat SDK ile lokal geri yükleme
      await RevenueCatService.restorePurchases();

      // 2. Backend senkronizasyonu (Rate Limit Korumalı)
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      await functions.httpsCallable('premium-syncRevenueCatPremiumCallable').call();

      if(mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: const Text('Kontrol tamamlandı. Premium durumunuz güncellendi.'),
                backgroundColor: _successColor
            )
        );
      }
    } on FirebaseFunctionsException catch (e) {
      // ✅ ÖZEL HATA YAKALAMA: Rate Limit (resource-exhausted)
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (e.code == 'resource-exhausted') {
          // Backend'den gelen "Lütfen XX saniye bekleyin" mesajını göster
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message ?? 'Çok sık işlem yaptınız. Lütfen biraz bekleyin.'),
              backgroundColor: Colors.orange, // Uyarı rengi (Kırmızı değil)
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          // Diğer Firebase hataları
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Sunucu hatası: ${e.message}'),
                backgroundColor: Colors.red
            ),
          );
        }
      }
    } catch(e) {
      // ✅ GENEL HATA
      if(mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bir hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    final bottomBarHeight = 90.0 + bottomPadding + (isSmallScreen ? 6 : 12);

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
                        vertical: isSmallScreen ? 4 : 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: _handleBack,
                            icon: Icon(Icons.close_rounded, color: _textPrimary, size: 28),
                            style: IconButton.styleFrom(backgroundColor: _textPrimary.withOpacity(0.05)),
                          ),
                          Row(
                            children: [
                              // DEBUG BUTONU
                              Container(
                                decoration: BoxDecoration(
                                  color: _debugTrialOverride ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    setState(() => _debugTrialOverride = !_debugTrialOverride);
                                    HapticFeedback.lightImpact();
                                  },
                                  icon: Icon(
                                    _debugTrialOverride ? Icons.check_circle : Icons.science_outlined,
                                    color: _debugTrialOverride ? Colors.green : Colors.grey,
                                    size: 20,
                                  ),
                                  tooltip: 'Test: ${_debugTrialOverride ? "Deneme VAR" : "Deneme YOK"}',
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _restorePurchases,
                                child: Text("Geri Yükle", style: TextStyle(color: _deepPink, fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
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
                                SizedBox(height: isSmallScreen ? 2 : 4),
                                Icon(
                                  Icons.diamond_rounded,
                                  size: isSmallScreen ? 34 : 38,
                                  color: _primaryPink,
                                ),
                                SizedBox(height: isSmallScreen ? 6 : 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [_primaryPink, _purpleAccent, _deepPink],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ).createShader(bounds),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        "TAKTİK PRO$examSuffix",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 30 : 34,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 6 : 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _primaryPink.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: _primaryPink.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.local_cafe_rounded, color: _deepPink, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        "1 kahve fiyatına",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: _deepPink, fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 12 : 16),

                                // Feature Carousel (Fix: SizedBox yerine Container kullanıldı)
                                Container(
                                  height: size.height * 0.17,
                                  constraints: const BoxConstraints(minHeight: 115, maxHeight: 150),
                                  child: GestureDetector(
                                    onPanDown: (_) {
                                      setState(() => _userInteracting = true);
                                    },
                                    onPanEnd: (_) {
                                      // Kullanıcı etkileşimi bittikten 5 saniye sonra otomatik scroll'u tekrar başlat
                                      Future.delayed(const Duration(seconds: 5), () {
                                        if (mounted) {
                                          setState(() => _userInteracting = false);
                                        }
                                      });
                                    },
                                    onPanCancel: () {
                                      Future.delayed(const Duration(seconds: 5), () {
                                        if (mounted) {
                                          setState(() => _userInteracting = false);
                                        }
                                      });
                                    },
                                    child: PageView.builder(
                                      controller: _featurePageController,
                                      itemCount: _features.length,
                                      onPageChanged: (i) => setState(() => _currentCarouselIndex = i),
                                      itemBuilder: (ctx, index) => _buildModernFeatureCard(_features[index]),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(_features.length, (index) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    height: 6,
                                    width: _currentCarouselIndex == index ? 24 : 6,
                                    decoration: BoxDecoration(
                                      color: _currentCarouselIndex == index ? _purpleAccent : _textSecondary.withOpacity(0.2),
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
                                        debugTrialOverride: _debugTrialOverride,
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
                                        debugTrialOverride: _debugTrialOverride,
                                      ),

                                    const SizedBox(height: 16),

                                    // Trust Badges
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 20,
                                      runSpacing: 8,
                                      children: [
                                        _TrustBadgeSmall(
                                          icon: Icons.lock_outline_rounded,
                                          label: "Güvenli Ödeme",
                                          color: _successColor,
                                        ),
                                        _TrustBadgeSmall(
                                          icon: Icons.cancel_outlined,
                                          label: "Kolay İptal",
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
                            loading: () => SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(color: _primaryPink))),
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
                    color: _bgLight.withOpacity(0.9),
                    border: Border(top: BorderSide(color: _primaryPink.withOpacity(0.1))),
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
                                  scale: 1.0 + (_pulseController.value * 0.02),
                                  child: Container(
                                    width: double.infinity,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      gradient: LinearGradient(
                                        colors: [_primaryPink, _purpleAccent, _deepPink],
                                        stops: const [0.0, 0.6, 1.0],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _purpleAccent.withOpacity(0.5 + (_pulseController.value * 0.2)),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        )
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _selectedPackage != null ? () => _purchasePackage(_selectedPackage!) : null,
                                        borderRadius: BorderRadius.circular(30),
                                        child: Center(
                                          child: _isPurchasing
                                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                                              : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.diamond_rounded, color: Colors.white, size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                (_debugTrialOverride || _selectedPackage?.storeProduct.introductoryPrice?.price == 0)
                                                    ? "ÜCRETSİZ BAŞLA"
                                                    : "HEMEN BAŞLA",
                                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5),
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

                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _FooterLink(text: "Kullanım Koşulları", url: "https://www.codenzi.com/terms"),
                                Container(height: 12, width: 1, color: _textSecondary.withOpacity(0.3), margin: const EdgeInsets.symmetric(horizontal: 10)),
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
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_bgLight, _bgSecondary],
                ),
              ),
            ),
            Positioned(
              top: -size.height * 0.1,
              right: -size.width * 0.2,
              child: Transform.rotate(
                angle: _backgroundController.value * 2 * math.pi,
                child: Container(
                  width: size.width * 0.8, height: size.width * 0.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [_primaryPink.withOpacity(0.15), Colors.transparent]),
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
                    gradient: RadialGradient(colors: [_purpleAccent.withOpacity(0.12), Colors.transparent]),
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

  Widget _buildModernFeatureCard(Map<String, dynamic> item) {
    // Burada constraints hatası almamak için LayoutBuilder kullanılabilir ama
    // basitçe Container ile yapıyoruz.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _primaryPink.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(color: _primaryPink.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_primaryPink, _purpleAccent]),
              shape: BoxShape.circle,
            ),
            child: Icon(item['icon'], color: Colors.white, size: 20),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _textPrimary)
                ),
                const SizedBox(height: 2),
                Text(
                    item['desc'],
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: _textSecondary, height: 1.2)
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// --- Pricing Card ---

class _ModernPricingCard extends StatefulWidget {
  final Package package;
  final bool isSelected;
  final bool isBestValue;
  final VoidCallback onTap;
  final Color accentColor;
  final Color badgeColor;
  final double? savingsPercent;
  final double? compareMonthlyPrice;
  final bool debugTrialOverride;

  const _ModernPricingCard({
    required this.package,
    required this.isSelected,
    required this.isBestValue,
    required this.onTap,
    required this.accentColor,
    required this.badgeColor,
    this.savingsPercent,
    this.compareMonthlyPrice,
    this.debugTrialOverride = false,
  });

  @override
  State<_ModernPricingCard> createState() => _ModernPricingCardState();
}

class _ModernPricingCardState extends State<_ModernPricingCard> {
  late Timer _badgeTimer;
  bool _showFirstBadge = true;

  @override
  void initState() {
    super.initState();
    // Badge animasyonu için timer
    _badgeTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _showFirstBadge = !_showFirstBadge;
        });
      }
    });
  }

  @override
  void dispose() {
    _badgeTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAnnual = widget.package.packageType == PackageType.annual ||
        widget.package.identifier.toLowerCase().contains('annual') ||
        widget.package.identifier.toLowerCase().contains('year');

    final hasTrial = widget.debugTrialOverride || (widget.package.storeProduct.introductoryPrice?.price == 0);

    String bigPriceDisplay = "";
    String smallSubtext = "";
    String? strikeThroughPrice;

    if (isAnnual) {
      final monthlyEq = widget.package.storeProduct.price / 12;
      bigPriceDisplay = "₺${monthlyEq.toStringAsFixed(2)} /ay";
      smallSubtext = "Yıllık ${widget.package.storeProduct.priceString} faturalanır";

      if (widget.compareMonthlyPrice != null) {
        strikeThroughPrice = "₺${widget.compareMonthlyPrice!.toStringAsFixed(2)}";
      }
    } else {
      bigPriceDisplay = widget.package.storeProduct.priceString;
      smallSubtext = "Her ay yenilenir";
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: EdgeInsets.all(widget.isSelected ? 2 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: widget.isSelected
                  ? LinearGradient(colors: [widget.accentColor, const Color(0xFF9C27B0)])
                  : LinearGradient(colors: [Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.02)]),
              boxShadow: widget.isSelected
                  ? [BoxShadow(color: widget.accentColor.withOpacity(0.25), blurRadius: 12, spreadRadius: 0)]
                  : [],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: widget.isSelected ? Colors.white : const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(18),
                border: widget.isSelected ? null : Border.all(color: Colors.black12),
              ),
              child: Row(
                children: [
                  // 1. Radio Icon
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isSelected ? widget.accentColor : Colors.transparent,
                      border: Border.all(
                          color: widget.isSelected ? widget.accentColor : Colors.grey.withOpacity(0.4),
                          width: 2
                      ),
                    ),
                    child: widget.isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 14),

                  // 2. İçerik Kısmı
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Plan Adı
                        Text(
                          isAnnual ? "Yıllık Plan" : "Aylık Plan",
                          style: TextStyle(
                              color: const Color(0xFF1A1A1A),
                              fontWeight: widget.isSelected ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 17
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Fiyat Bilgileri
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Ana Fiyat
                            Text(
                              bigPriceDisplay,
                              style: TextStyle(
                                color: widget.accentColor,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),

                            if (isAnnual && strikeThroughPrice != null) ...[
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  strikeThroughPrice,
                                  style: const TextStyle(
                                    color: Color(0xFF999999),
                                    fontSize: 13,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Color(0xFF999999),
                                    height: 1,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Alt Açıklama
                        Text(
                          smallSubtext,
                          style: const TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 11,
                              height: 1.2
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tek Badge - Sadece Fade Geçişi
          if (hasTrial || (widget.isBestValue && widget.savingsPercent != null))
            Positioned(
              top: -4,
              right: -2,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  // Sadece fade - pozisyon değişikliği yok
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: _buildBadge(hasTrial, widget.isBestValue, widget.savingsPercent, widget.accentColor, widget.badgeColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(bool hasTrial, bool isBestValue, double? savingsPercent, Color accentColor, Color badgeColor) {
    // Hem deneme hem tasarruf varsa, animasyonla değiştir
    if (hasTrial && isBestValue && savingsPercent != null) {
      if (_showFirstBadge) {
        return _buildTrialBadge(accentColor, key: const ValueKey('trial'));
      } else {
        return _buildSavingsBadge(savingsPercent, badgeColor, key: const ValueKey('savings'));
      }
    }

    // Sadece deneme varsa
    if (hasTrial) {
      return _buildTrialBadge(accentColor, key: const ValueKey('trial'));
    }

    // Sadece tasarruf varsa
    if (isBestValue && savingsPercent != null) {
      return _buildSavingsBadge(savingsPercent, badgeColor, key: const ValueKey('savings'));
    }

    return const SizedBox.shrink();
  }

  Widget _buildTrialBadge(Color accentColor, {Key? key}) {
    return Container(
      key: key,
      width: 115,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor, const Color(0xFFFF1744)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Text(
        "7 GÜN ÜCRETSİZ",
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildSavingsBadge(double savingsPercent, Color badgeColor, {Key? key}) {
    return Container(
      key: key,
      width: 115,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [badgeColor, const Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        "%${savingsPercent.toStringAsFixed(0)} TASARRUF",
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
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
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'Abonelik otomatik yenilenir, dilediğin zaman iptal edebilirsin.',
          textAlign: TextAlign.center,
          maxLines: 1,
          style: const TextStyle(color: Color(0xFF666666), fontSize: 9, height: 1.4),
        ),
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
      child: Text(text, style: const TextStyle(color: Color(0xFF666666), fontSize: 11, decoration: TextDecoration.underline)),
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
            color: const Color(0xFF666666),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}