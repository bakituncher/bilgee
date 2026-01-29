import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:taktik/core/services/revenuecat_service.dart';
import 'package:collection/collection.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'dart:ui';
import 'dart:async';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:url_launcher/url_launcher.dart';

class ToolOfferScreen extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;
  final IconData? icon;
  final String? iconName; // YENİ: String olarak icon ismi
  final Color color;
  final String heroTag;
  final String marketingTitle;
  final String marketingSubtitle;
  final String? redirectRoute;
  final String? imageAsset;

  const ToolOfferScreen({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.iconName,
    required this.color,
    required this.heroTag,
    required this.marketingTitle,
    required this.marketingSubtitle,
    this.redirectRoute,
    this.imageAsset,
  });

  // Icon name'den IconData'ya çevirme
  IconData get resolvedIcon {
    if (icon != null) return icon!;
    switch (iconName) {
      case 'school':
        return Icons.school_rounded;
      case 'psychology':
        return Icons.psychology_rounded;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'calendar_month':
        return Icons.calendar_month_rounded;
      case 'camera_enhance':
        return Icons.camera_enhance_rounded;
      case 'radar':
        return Icons.radar_rounded;
      default:
        return Icons.auto_awesome;
    }
  }

  @override
  ConsumerState<ToolOfferScreen> createState() => _ToolOfferScreenState();
}

class _PriceTransparencyFooter extends StatelessWidget {
  const _PriceTransparencyFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface.withOpacity(0.6);
    final textStyle = theme.textTheme.bodySmall?.copyWith(color: textColor, height: 1.25, fontSize: 9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Text(
        'Abonelik otomatik yenilenir, dilediğin zaman iptal edebilirsin.',
        textAlign: TextAlign.center,
        style: textStyle,
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white38 : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _FooterLink(text: 'Kullanım Şartları', url: 'https://www.codenzi.com/taktik-kullanim-sozlesmesi.html'),
          const SizedBox(width: 8),
          Text('|', style: TextStyle(color: dividerColor, fontSize: 10)),
          const SizedBox(width: 8),
          const _FooterLink(text: 'Gizlilik Politikası', url: 'https://www.codenzi.com/taktik-gizlilik-politikasi.html'),
        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final linkColor = isDark ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant;
    return GestureDetector(
      onTap: () async {
        try {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Bağlantı açılamadı: $url')),
            );
          }
        } catch (_) {
          // URL açılamasa bile crash olmasın
        }
      },
      child: Text(
        text,
        style: TextStyle(
          color: linkColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: linkColor,
        ),
      ),
    );
  }
}

class _ToolOfferScreenState extends ConsumerState<ToolOfferScreen>
    with TickerProviderStateMixin {
  static const double _kButtonHeight = 52.0;
  static const double _kButtonBorderRadius = 99.0;

  late final AnimationController _fadeController;
  late final AnimationController _cardPopController;
  late final AnimationController _pulseController;

  Package? _selectedPackage;
  bool _isPurchaseInProgress = false;
  bool _hasInitializedPackage = false;
  bool _debugTrialOverride = false; // Debug için deneme kontrolü

  // Renk tanımlamaları - Premium screen ile aynı
  final Color _textPrimary = const Color(0xFF1A1A1A);

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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fadeController.forward();
        _cardPopController.forward();
      }
    });

    // Yıllık planı hemen seç
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDefaultPackage();
    });
  }

  void _initializeDefaultPackage() {
    if (!mounted || _hasInitializedPackage) return;

    final offeringsAsyncValue = ref.read(offeringsProvider);
    offeringsAsyncValue.whenData((offerings) {
      if (!mounted || _hasInitializedPackage) return;

      final current = offerings.current ??
          offerings.all.values.firstWhereOrNull(
                (o) => o.availablePackages.isNotEmpty,
          );

      if (current != null) {
        final yearly = current.annual ??
            current.getPackage('yillik-normal-yeni') ??
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
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _cardPopController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.aiHub);
    }
  }

  Future<void> _restorePurchases() async {
    if (_isPurchaseInProgress) return; // Zaten bir işlem varsa tekrar tetikleme
    if (!mounted) return; // Widget ağaçtan kaldırıldıysa işlemi durdur

    setState(() => _isPurchaseInProgress = true);

    // Kullanıcıya işlemin başladığını bildir
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Satın alımlar kontrol ediliyor ve sunucuyla eşitleniyor...'),
        backgroundColor: Colors.blueGrey,
        duration: Duration(milliseconds: 1500), // Çok uzun kalmasın
      ),
    );

    try {
      // 1. RevenueCat SDK ile lokal geri yükleme
      await RevenueCatService.restorePurchases();

      // 2. Backend senkronizasyonu (Rate Limit Korumalı)
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('premium-syncRevenueCatPremiumCallable');
      await callable.call();

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Kontrol tamamlandı. Premium durumunuz güncellendi.'),
          backgroundColor: Theme.of(context).colorScheme.secondary, // Başarılı rengi
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      // ✅ ÖZEL HATA YAKALAMA: Rate Limit (resource-exhausted)
      if (!mounted) return;
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
            backgroundColor: Theme.of(context).colorScheme.error
          ),
        );
      }
    } catch (e) {
      // ✅ GENEL HATA
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bir hata oluştu: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPurchaseInProgress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final offeringsAsyncValue = ref.watch(offeringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          _buildAnimatedGradientBackground(),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
            child: Container(color: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.5)),
          ),
          // Ana içerik
          Column(
            children: [
              // Header
              SafeArea(
                bottom: false,
                child: _buildCustomHeader(context),
              ),
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: 16, // Bottom bar için alan bırak
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ToolFeatureHeader(
                        heroTag: widget.heroTag,
                        icon: widget.resolvedIcon,
                        color: widget.color,
                        title: widget.title,
                        imageAsset: widget.imageAsset,
                      ),
                      const SizedBox(height: 8),
                      _MarketingInfo(
                        fadeController: _fadeController,
                        title: widget.marketingTitle,
                        subtitle: widget.marketingSubtitle,
                      ),
                      const SizedBox(height: 8),
                      // Purchase options (buton hariç)
                      _buildPurchaseSectionContent(offeringsAsyncValue),
                    ],
                  ),
                ),
              ),
              // Sabit bottom bar - Premium screen gibi
              _buildBottomBar(offeringsAsyncValue),
            ],
          ),
        ],
      ),
    );
  }

  /// Purchase section içeriği - Buton hariç (buton artık sabit bottom bar'da)
  Widget _buildPurchaseSectionContent(AsyncValue<Offerings?> offeringsAsyncValue) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark
              ? Theme.of(context).scaffoldBackgroundColor.withOpacity(0.6)
              : Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : widget.color.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : widget.color.withOpacity(0.08),
              spreadRadius: 0,
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: offeringsAsyncValue.when(
          data: (offerings) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPurchaseOptions(context, ref, offerings),
                  const SizedBox(height: 12),
                  _buildTrustBadges(),
                  const SizedBox(height: 8),
                  const _PriceTransparencyFooter(),
                ],
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(40.0),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
          error: (error, stack) => Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  'Paketler yüklenemedi',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrustBadges() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 20,
      runSpacing: 8,
      children: [
        _TrustBadgeCompact(
          icon: Icons.lock_outline_rounded,
          label: "Güvenli Ödeme",
          color: const Color(0xFF4CAF50), // Yeşil
        ),
        _TrustBadgeCompact(
          icon: Icons.cancel_outlined,
          label: "Kolay İptal",
          color: const Color(0xFFE91E63), // Deep Pink
        ),
      ],
    );
  }

  // ESKİ _buildPurchaseSection method'unu kaldır, artık kullanılmıyor

  Widget _buildCustomHeader(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    return Container(
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
                child: Text("Geri Yükle", style: TextStyle(color: widget.color, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedGradientBackground() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.5,
          colors: isDark
              ? [
            widget.color.withOpacity(0.3),
            Theme.of(context).scaffoldBackgroundColor.withOpacity(0.2),
            Theme.of(context).scaffoldBackgroundColor,
          ]
              : [
            widget.color.withOpacity(0.15),
            Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
            Theme.of(context).scaffoldBackgroundColor,
          ],
          stops: const [0.0, 0.4, 1.0],
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
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Text(
            'Şu anda müsait paket bulunmuyor',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
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
        current.getPackage('yillik-normal-yeni') ??
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

    // Eğer henüz seçim yapılmadıysa ve yıllık plan varsa, otomatik seç
    if (_selectedPackage == null && yearly != null && !_hasInitializedPackage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedPackage == null) {
          setState(() {
            _selectedPackage = yearly;
            _hasInitializedPackage = true;
          });
        }
      });
    }

    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sınırları Kaldır',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Potansiyelinin zirvesine ulaş',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 10),
            if (yearly != null)
              _PurchaseOptionCard(
                animationController: _cardPopController,
                package: yearly,
                title: 'Yıllık PRO Plan',
                price: yearly.storeProduct.priceString,
                billingPeriod: '/ yıl',
                tag: savePercent != null
                    ? '%${savePercent.toStringAsFixed(0)} TASARRUF'
                    : 'EN İYİ DEĞER',
                isSelected: _selectedPackage == yearly,
                delay: const Duration(milliseconds: 0),
                onSelected: (pkg) => setState(() => _selectedPackage = pkg),
                color: widget.color,
                debugTrialOverride: _debugTrialOverride,
              ),
            if (yearly != null && monthly != null) const SizedBox(height: 8),
            if (monthly != null)
              _PurchaseOptionCard(
                animationController: _cardPopController,
                package: monthly,
                title: 'Aylık PRO Plan',
                price: monthly.storeProduct.priceString,
                billingPeriod: '/ ay',
                isSelected: _selectedPackage == monthly,
                delay: const Duration(milliseconds: 100),
                onSelected: (pkg) => setState(() => _selectedPackage = pkg),
                color: widget.color,
                debugTrialOverride: _debugTrialOverride,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseButton() {
    final hasFreeTrial = _debugTrialOverride ||
                        (_selectedPackage?.storeProduct.introductoryPrice?.price == 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_pulseController.value * 0.02),
            child: Container(
              height: _kButtonHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_kButtonBorderRadius),
                gradient: LinearGradient(
                  colors: [
                    widget.color,
                    widget.color.withOpacity(0.7),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.5 + (_pulseController.value * 0.2)),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isPurchaseInProgress ? null : _purchasePackage,
                  borderRadius: BorderRadius.circular(_kButtonBorderRadius),
                  child: Center(
                    child: _isPurchaseInProgress
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.diamond_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                hasFreeTrial ? 'ÜCRETSİZ BAŞLA' : 'HEMEN BAŞLA',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
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
    );
  }

  /// Sabit bottom bar - Premium screen gibi
  Widget _buildBottomBar(AsyncValue<Offerings?> offeringsAsyncValue) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark
                  ? Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9)
                  : Theme.of(context).cardColor.withOpacity(0.95),
              border: Border(
                top: BorderSide(
                  color: widget.color.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    isSmallScreen ? 10 : 12,
                    20,
                    bottomPadding + (isSmallScreen ? 6 : 8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPurchaseButton(),
                      const SizedBox(height: 8),
                      const _LegalFooter(),
                    ],
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
      final outcome = await RevenueCatService.makePurchase(_selectedPackage!);
      if (!context.mounted) return;

      if (outcome.cancelled) {
        setState(() => _isPurchaseInProgress = false);
        return;
      }

      if (outcome.success) {
        // İyimser güncelleme için callable fonksiyonu tetikle
        try {
          final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
          final callable = functions.httpsCallable('premium-syncRevenueCatPremiumCallable');
          await callable.call();
        } catch (e) {
          print("Callable function for premium sync failed (safe to ignore): $e");
        }

        if (!mounted) return;
        // Başarılı satın alma sonrası Premium Welcome ekranına yönlendir
        context.go(AppRoutes.premiumWelcome);
        return;
      }

      final errMsg = outcome.error ?? 'Bilinmeyen hata';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Başarısız: $errMsg'),
            backgroundColor: Theme.of(context).colorScheme.error,
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
          backgroundColor: Theme.of(context).colorScheme.error,
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
    this.imageAsset,
  });

  final String heroTag;
  final IconData icon;
  final Color color;
  final String title;
  final String? imageAsset;

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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).cardColor.withOpacity(0.8),
                border: Border.all(color: color, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: imageAsset != null
                  ? ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(9.0),
                        child: Image.asset(
                          imageAsset!,
                          width: 46,
                          height: 46,
                          fit: BoxFit.contain,
                        ),
                      ),
                    )
                  : Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 17,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeTransition(
      opacity: fadeController,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
                fontSize: 11.5,
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
    this.debugTrialOverride = false,
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
  final bool debugTrialOverride;

  @override
  State<_PurchaseOptionCard> createState() => _PurchaseOptionCardState();
}

class _PurchaseOptionCardState extends State<_PurchaseOptionCard>
    with TickerProviderStateMixin {
  late final AnimationController _innerController;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late Timer _badgeTimer;
  bool _showFirstBadge = true;

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
    _innerController.dispose();
    _badgeTimer.cancel();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final introPrice = widget.package.storeProduct.introductoryPrice;
    final hasFreeTrial = widget.debugTrialOverride || (introPrice != null && introPrice.price == 0);

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
                        ? LinearGradient(
                            colors: [widget.color, widget.color.withOpacity(0.7)],
                          )
                        : LinearGradient(
                            colors: [
                              Colors.black.withOpacity(isDark ? 0.1 : 0.05),
                              Colors.black.withOpacity(isDark ? 0.05 : 0.02)
                            ],
                          ),
                    boxShadow: widget.isSelected
                        ? [
                            BoxShadow(
                              color: widget.color.withOpacity(0.25),
                              blurRadius: 12,
                              spreadRadius: 0,
                            )
                          ]
                        : [],
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? (isDark ? const Color(0xFF2A2A2A) : Colors.white)
                          : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA)),
                      borderRadius: BorderRadius.circular(18),
                      border: widget.isSelected
                          ? null
                          : Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black12,
                            ),
                    ),
                    child: Row(
                      children: [
                        // Radio Icon (Sol tarafta)
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.isSelected ? widget.color : Colors.transparent,
                            border: Border.all(
                              color: widget.isSelected
                                  ? widget.color
                                  : (isDark ? Colors.grey : Colors.grey.withOpacity(0.4)),
                              width: 2,
                            ),
                          ),
                          child: widget.isSelected
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 14),

                        // İçerik
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Plan Adı
                              Text(
                                widget.title,
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                  fontWeight: widget.isSelected ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Fiyat Bilgileri
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    widget.price,
                                    style: TextStyle(
                                      color: widget.color,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      widget.billingPeriod,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey
                                            : const Color(0xFF888888),
                                        fontSize: 11,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Tek Badge - Sadece Fade Geçişi
                if (hasFreeTrial || widget.tag != null)
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
                      child: _buildBadge(hasFreeTrial, widget.tag),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(bool hasFreeTrial, String? tag) {
    // Hem deneme hem tasarruf varsa, animasyonla değiştir
    if (hasFreeTrial && tag != null) {
      if (_showFirstBadge) {
        return _buildTrialBadge(key: const ValueKey('trial'));
      } else {
        return _buildSavingsBadge(tag, key: const ValueKey('savings'));
      }
    }

    // Sadece deneme varsa
    if (hasFreeTrial) {
      return _buildTrialBadge(key: const ValueKey('trial'));
    }

    // Sadece tasarruf varsa
    if (tag != null) {
      return _buildSavingsBadge(tag, key: const ValueKey('savings'));
    }

    return const SizedBox.shrink();
  }

  Widget _buildTrialBadge({Key? key}) {
    return Container(
      key: key,
      width: 115,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.color, const Color(0xFFFF1744)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.3),
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

  Widget _buildSavingsBadge(String tag, {Key? key}) {
    return Container(
      key: key,
      width: 115,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        tag,
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

class _TrustBadgeCompact extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TrustBadgeCompact({
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
          style: const TextStyle(
            color: Color(0xFF666666),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

