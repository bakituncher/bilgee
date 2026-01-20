import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:taktik/core/services/revenuecat_service.dart';
import 'package:collection/collection.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'dart:ui';
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
      case 'auto_fix_high':
        return Icons.auto_fix_high_rounded;
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
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Text(
        'Abonelik, siz iptal edene kadar seçtiğiniz tarife (aylık/yıllık) üzerinden otomatik olarak yenilenir. '
            'Ücretsiz deneme süresi (varsa) sonunda ücretlendirme başlar. '
            'Aboneliğinizi uygulamanın ayarlar sekmesinde bulunan "Abonelik Yönetimi" bölümünden istediğiniz zaman kolayca iptal edebilirsiniz. '
            'Fiyatlara tüm vergiler dahildir.',
        textAlign: TextAlign.center,
        style: textStyle,
      ),
    );
  }
}

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
  const _LegalFooter();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white38 : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
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
        final uri = Uri.parse(url);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Bağlantı açılamadı: $url'),
                action: SnackBarAction(
                  label: 'Tekrar',
                  onPressed: () async {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ),
            );
          }
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

  Future<void> _restorePurchases() async {
    if (_isPurchaseInProgress) return; // Zaten bir işlem varsa tekrar tetikleme

    setState(() => _isPurchaseInProgress = true);

    // Kullanıcıya işlemin başladığını bildir
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kontrol tamamlandı. Premium durumunuz güncellendi.'),
            backgroundColor: Theme.of(context).colorScheme.secondary, // Başarılı rengi
          ),
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
              backgroundColor: Theme.of(context).colorScheme.error
            ),
          );
        }
      }
    } catch (e) {
      // ✅ GENEL HATA
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
      if (mounted) {
        setState(() => _isPurchaseInProgress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final offeringsAsyncValue = ref.watch(offeringsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
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
          // ÇÖZÜM: SafeArea ve SingleChildScrollView ile tüm body'yi sarmala
          SafeArea(
            child: Column(
              children: [
                _buildCustomHeader(context),
                // ÇÖZÜM: Expanded içinde SingleChildScrollView ile scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        _ToolFeatureHeader(
                          heroTag: widget.heroTag,
                          icon: widget.resolvedIcon,
                          color: widget.color,
                          title: widget.title,
                          imageAsset: widget.imageAsset,
                        ),
                        const SizedBox(height: 20),
                        _MarketingInfo(
                          fadeController: _fadeController,
                          title: widget.marketingTitle,
                          subtitle: widget.marketingSubtitle,
                        ),
                        const SizedBox(height: 20),
                        // ÇÖZÜM: Purchase section burada, scroll edilebilir
                        _buildPurchaseSectionContent(offeringsAsyncValue),
                        const SizedBox(height: 20),
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

  /// ÇÖZÜM: Purchase section içeriğini ayrı method'a çıkar (scroll içinde olacak)
  Widget _buildPurchaseSectionContent(AsyncValue<Offerings?> offeringsAsyncValue) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8)
            : Theme.of(context).cardColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.15),
            spreadRadius: isDark ? 5 : 2,
            blurRadius: isDark ? 25 : 15,
          ),
        ],
      ),
      child: offeringsAsyncValue.when(
        data: (offerings) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPurchaseOptions(context, ref, offerings),
                const SizedBox(height: 12),
                _buildPurchaseButton(),
                const SizedBox(height: 10),
                const _TrustBadges(),
                const _PriceTransparencyFooter(),
                const _LegalFooter(),
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
    );
  }

  // ESKİ _buildPurchaseSection method'unu kaldır, artık kullanılmıyor

  Widget _buildCustomHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Orta - Başlık
          Text(
            'Özel Teklif',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          // Sol - Kapat Butonu
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 28,
                color: isDark ? Colors.white70 : Theme.of(context).colorScheme.onSurface,
              ),
              tooltip: 'Kapat',
              onPressed: _handleBack,
            ),
          ),
          // Sağ - Geri Yükle Butonu
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isPurchaseInProgress ? null : _restorePurchases,
              child: _isPurchaseInProgress
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    )
                  : Text(
                      'Geri Yükle',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
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

    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sınırları Kaldır',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Potansiyelinin zirvesine ulaş',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            if (yearly != null)
              _PurchaseOptionCard(
                animationController: _cardPopController,
                package: yearly,
                title: 'Yıllık PRO Plan',
                price: yearly.storeProduct.priceString,
                billingPeriod: '/ yıl',
                tag: savePercent != null
                    ? '%${savePercent.toStringAsFixed(0)} AVANTAJ'
                    : 'EN İYİ DEĞER',
                isSelected: _selectedPackage == yearly,
                delay: const Duration(milliseconds: 0),
                onSelected: (pkg) => setState(() => _selectedPackage = pkg),
                color: widget.color,
              ),
            if (yearly != null && monthly != null) const SizedBox(height: 10),
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
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                    : Text(
                  'Abone Ol ve Başla',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Harika! Premium özellikler aktif ediliyor...'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Başarılı satın alma sonrası AI Hub ekranına yönlendir
        context.go(AppRoutes.aiHub);
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
              width: 85,
              height: 85,
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
                        padding: const EdgeInsets.all(12.0),
                        child: Image.asset(
                          imageAsset!,
                          width: 61,
                          height: 61,
                          fit: BoxFit.contain,
                        ),
                      ),
                    )
                  : Icon(icon, size: 42, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeTransition(
      opacity: fadeController,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(18),
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
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final introPrice = widget.package.storeProduct.introductoryPrice;
    final hasFreeTrial = introPrice != null && introPrice.price == 0;

    final borderColor = widget.isSelected
        ? widget.color
        : (isDark
        ? Theme.of(context).cardColor.withOpacity(0.5)
        : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5));
    final backgroundColor = widget.isSelected
        ? widget.color.withOpacity(0.15)
        : (isDark
        ? Colors.white.withOpacity(0.05)
        : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.1));

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
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // ÜCRETSİZ DENEME VURGUSU - SADECE AYLIK PAKETTE
                              if (hasFreeTrial && widget.title.toLowerCase().contains('aylık'))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1BFFFF).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFF1BFFFF).withOpacity(0.4),
                                      ),
                                    ),
                                    child: Text(
                                      '🎁 İLK 7 GÜN ÜCRETSİZ DENE',
                                      style: TextStyle(
                                        color: const Color(0xFF1BFFFF),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 9.5,
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
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                      color: widget.isSelected
                                          ? widget.color
                                          : Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    widget.billingPeriod,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
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
                                : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
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
                              : const Color(0xFFFFB020),
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
                          style: TextStyle(
                            color: widget.isSelected
                                ? Colors.white
                                : (Theme.of(context).brightness == Brightness.dark
                                ? Theme.of(context).scaffoldBackgroundColor
                                : Colors.white),
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
