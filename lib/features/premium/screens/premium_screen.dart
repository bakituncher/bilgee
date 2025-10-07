import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/shared/widgets/loading_screen.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:taktik/core/app_check/app_check_helper.dart';

// NEW Product IDs from Google Play Store
const String _monthlySubscriptionId = 'premium_aylik';
const String _yearlySubscriptionId = 'premium_yillik';
const List<String> _kProductIds = <String>[
  _monthlySubscriptionId,
  _yearlySubscriptionId,
];

// Provider for the purchase service
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return PurchaseService(FirebaseFunctions.instanceFor(region: 'us-central1'));
});

// Provider for the subscription products
final productsProvider = FutureProvider<List<ProductDetails>>((ref) async {
  final purchaseService = ref.watch(purchaseServiceProvider);
  return await purchaseService.loadProducts();
});

class PurchaseService {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseFunctions _functions;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  PurchaseService(this._functions);

  Future<List<ProductDetails>> loadProducts() async {
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      return [];
    }
    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(_kProductIds.toSet());
    if (response.error != null) {
      return [];
    }
    return response.productDetails;
  }

  void listenToPurchaseUpdated(
      void Function(PurchaseDetails) onPurchase, void Function() onError) {
    _subscription = _inAppPurchase.purchaseStream.listen(
      (purchaseDetailsList) {
        for (var purchaseDetails in purchaseDetailsList) {
          if (purchaseDetails.status == PurchaseStatus.pending) {
            // Handled by loading overlay
          } else {
            if (purchaseDetails.status == PurchaseStatus.error) {
              onError();
            } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                purchaseDetails.status == PurchaseStatus.restored) {
              onPurchase(purchaseDetails);
            }
            if (purchaseDetails.pendingCompletePurchase) {
              _inAppPurchase.completePurchase(purchaseDetails);
            }
          }
        }
      },
      onDone: () => _subscription.cancel(),
      onError: (error) => onError(),
    );
  }

  Future<void> buySubscription(ProductDetails productDetails) async {
    // Android: varsa offerToken kullan, yoksa standart akış
    if (defaultTargetPlatform == TargetPlatform.android && productDetails is GooglePlayProductDetails) {
      final String? offerToken = _getAndroidFreeTrialOfferToken(productDetails);
      if (offerToken != null && offerToken.isNotEmpty) {
        final purchaseParam = GooglePlayPurchaseParam(
          productDetails: productDetails,
          offerToken: offerToken,
        );
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
        return;
      }
    }
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> verifyPurchase(PurchaseDetails purchaseDetails) async {
    // App Check token hazır olsun (Console'da zorunlu ise çağrı reddedilmesin)
    await ensureAppCheckTokenReady();
    final HttpsCallable callable = _functions.httpsCallable('premium-verifyPurchase');
    final packageInfo = await PackageInfo.fromPlatform();
    await callable.call(<String, dynamic>{
      'productId': purchaseDetails.productID,
      'purchaseToken': purchaseDetails.verificationData.serverVerificationData,
      'packageName': packageInfo.packageName,
    });
  }

  void dispose() {
    _subscription.cancel();
  }
}

// Android için ÜCRETSİZ DENEME offerToken'ını güvenli şekilde al
String? _getAndroidFreeTrialOfferToken(ProductDetails p) {
  try {
    if (p is GooglePlayProductDetails) {
      // 'subscriptionOfferDetails' alanına dinamik olarak erişmek, eski eklenti sürümleriyle uyumluluk sağlar.
      final offers = (p as dynamic).subscriptionOfferDetails as List?;
      if (offers == null || offers.isEmpty) return null;

      // Ücretsiz deneme içeren teklifi bul (genellikle ilk faz 0 ücretlidir)
      final freeTrialOffer = offers.firstWhere(
        (offer) {
          final phases = (offer.pricingPhases.pricingPhaseList as List?);
          if (phases == null || phases.isEmpty) return false;
          // İlk ödeme fazının fiyatı 0 mı diye kontrol et
          final firstPhase = phases.first;
          return firstPhase.priceAmountMicros == 0;
        },
        orElse: () => null, // Eşleşen teklif yoksa null dön
      );

      return freeTrialOffer?.offerToken as String?;
    }
  } catch (_) {
    // Hata durumunda (alan yok, tip uyuşmazlığı vb.) null dön
  }
  return null;
}

// Bir ürünün ücretsiz deneme içerip içermediğini kontrol et
bool _hasFreeTrial(ProductDetails p) {
  return _getAndroidFreeTrialOfferToken(p) != null;
}

// Abonelik fiyatı: yeni API varsa fazların sonunu, yoksa price döndür
String _displayPriceFor(ProductDetails p) {
  try {
    if (p is GooglePlayProductDetails) {
      final dyn = p as dynamic; // Derleme hatası olmaması için dinamik erişim
      final offers = dyn.subscriptionOfferDetails;
      if (offers != null && offers.isNotEmpty) {
        final phases = offers.first.pricingPhases.pricingPhaseList as List?;
        if (phases != null && phases.isNotEmpty) {
          final last = phases.last;
          final formatted = (last.formattedPrice ?? last.priceFormatted) as String?; // farklı sürümler
          if (formatted != null && formatted.isNotEmpty) return formatted;
        }
      }
    }
  } catch (_) {}
  return p.price;
}

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  String _selectedProductId = _monthlySubscriptionId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    ref.read(purchaseServiceProvider).listenToPurchaseUpdated(
      (details) async {
        setState(() => _isLoading = true);
        try {
          await ref.read(purchaseServiceProvider).verifyPurchase(details);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Abonelik doğrulandı! Premium özellikler aktif.'),
            backgroundColor: Colors.green,
          ));
          context.pop();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Doğrulama hatası: ${e.toString()}'),
            backgroundColor: AppTheme.accentColor,
          ));
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
      () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Satın alma işlemi sırasında bir hata oluştu.'),
          backgroundColor: AppTheme.accentColor,
        ));
      },
    );
  }

  @override
  void dispose() {
    ref.read(purchaseServiceProvider).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0A101A),
      body: Stack(
        children: [
          productsAsync.when(
            data: (products) {
              if (products.isEmpty) {
                // In debug mode, show mock UI if products fail to load
                if (kDebugMode) return _buildMockBody(context);
                // In release mode, show error
                return _buildErrorBody('Abonelikler yüklenemedi.\nLütfen Google Play ayarlarınızı kontrol edin.');
              }
              return _buildRealBody(context, products);
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.goldColor)),
            error: (err, _) => _buildErrorBody('Bir hata oluştu: ${err.toString()}'),
          ),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildRealBody(BuildContext context, List<ProductDetails> products) {
    ProductDetails? monthly;
    ProductDetails? yearly;
    try {
      monthly = products.firstWhere((p) => p.id == _monthlySubscriptionId);
      yearly = products.firstWhere((p) => p.id == _yearlySubscriptionId);
    } catch (e) {
      return _buildErrorBody('Abonelik ürünleri bulunamadı. Lütfen ürün IDlerini kontrol edin.');
    }

    final selectedProduct = _selectedProductId == _yearlySubscriptionId ? yearly : monthly;
    final monthlyHasFreeTrial = _hasFreeTrial(monthly);

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(context),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildSubscriptionCard(
                  title: 'YILLIK ABONELİK',
                  price: _displayPriceFor(yearly),
                  priceDetails: 'Yıllık',
                  isSelected: _selectedProductId == _yearlySubscriptionId,
                  onTap: () => setState(() => _selectedProductId = _yearlySubscriptionId),
                  // Yıllık planda deneme yok
                ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
                const SizedBox(height: 16),
                _buildSubscriptionCard(
                  title: 'AYLIK ABONELİK',
                  price: _displayPriceFor(monthly),
                  priceDetails: 'Aylık',
                  isSelected: _selectedProductId == _monthlySubscriptionId,
                  onTap: () => setState(() => _selectedProductId = _monthlySubscriptionId),
                  bannerText: monthlyHasFreeTrial ? '7 GÜN ÜCRETSİZ DENE' : null,
                ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1),
                const SizedBox(height: 40),
                _buildPerksList().animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomBar(
              context,
              onPressed: () {
                ref.read(purchaseServiceProvider).buySubscription(selectedProduct);
              },
              buttonText: (_selectedProductId == _monthlySubscriptionId && monthlyHasFreeTrial)
                  ? '7 Gün Ücretsiz Dene ve Abone Ol'
                  : 'Şimdi Abone Ol',
              hasFreeTrial: monthlyHasFreeTrial,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMockBody(BuildContext context) {
    // This is the placeholder UI for development
    return CustomScrollView(
       slivers: [
        _buildSliverAppBar(context),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildSubscriptionCard(
                  title: 'YILLIK ABONELİK',
                  price: '₺1,199.99',
                  priceDetails: 'Yıllık',
                  isSelected: _selectedProductId == _yearlySubscriptionId,
                  onTap: () => setState(() => _selectedProductId = _yearlySubscriptionId),
                  // Deneme yok
                ),
                const SizedBox(height: 16),
                _buildSubscriptionCard(
                  title: 'AYLIK ABONELİK',
                  price: '₺149.99',
                  priceDetails: 'Aylık',
                  isSelected: _selectedProductId == _monthlySubscriptionId,
                  onTap: () => setState(() => _selectedProductId = _monthlySubscriptionId),
                  bannerText: '7 GÜN ÜCRETSİZ DENE',
                ),
                const SizedBox(height: 40),
                _buildPerksList(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomBar(
              context,
              onPressed: null, // Disabled in mock mode
              buttonText: _selectedProductId == _monthlySubscriptionId
                  ? '7 Gün Ücretsiz Dene'
                  : 'Şimdi Abone Ol',
              hasFreeTrial: false, // Mock data doesn't have a trial
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBody(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          message,
          style: const TextStyle(color: AppTheme.secondaryTextColor, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.goldColor)),
            SizedBox(height: 20),
            Text(
              'Abonelik doğrulanıyor...',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: const Color(0xFF0A101A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: AppTheme.secondaryTextColor),
        onPressed: () => context.pop(),
      ),
      centerTitle: true,
      title: Text(
        'Premium\'a Geç',
        style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.textColor),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.workspace_premium_rounded, color: AppTheme.goldColor, size: 50),
        const SizedBox(height: 24),
        Text(
          'Tüm Potansiyelini Ortaya Çıkar',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
              color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        const Text(
          'AI Koç, Cevher Atölyesi ve daha fazlasına sınırsız erişim sağla.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 16, height: 1.5),
        ),
      ],
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  Widget _buildSubscriptionCard({
    required String title,
    required String price,
    required String priceDetails,
    required bool isSelected,
    required VoidCallback onTap,
    String? bannerText,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.goldColor : AppTheme.lightSurfaceColor,
            width: 2.5,
          ),
          gradient: LinearGradient(
            colors: isSelected
                ? [const Color(0xFF3A2D0B), const Color(0xFF1C1604)]
                : [AppTheme.cardColor, AppTheme.cardColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? AppTheme.goldColor : AppTheme.secondaryTextColor,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        '$price / $priceDetails',
                        style: const TextStyle(color: AppTheme.secondaryTextColor, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (bannerText != null)
              Positioned(
                top: -15,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.goldColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    bannerText,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerksList() {
    final perks = [
      ('Sınırsız AI Koç Desteği', Icons.auto_awesome_rounded),
      ('Kişiselleştirilmiş Strateji Planları', Icons.insights_rounded),
      ('Derinlemesine Zayıflık Analizi', Icons.construction_rounded),
      ('Reklamsız Deneyim', Icons.ad_units_rounded),
    ];
    return Column(
      children: perks.map((perk) => Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          children: [
            Icon(perk.$2, color: AppTheme.successColor, size: 24),
            const SizedBox(width: 16),
            Text(perk.$1, style: const TextStyle(color: AppTheme.textColor, fontSize: 16)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildBottomBar(
    BuildContext context, {
    required VoidCallback? onPressed,
    required String buttonText,
    required bool hasFreeTrial,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      decoration: BoxDecoration(
        color: const Color(0xFF0A101A).withOpacity(0.8),
        border: const Border(
          top: BorderSide(color: AppTheme.lightSurfaceColor, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldColor,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              disabledBackgroundColor: AppTheme.lightSurfaceColor,
              shadowColor: AppTheme.goldColor.withOpacity(0.5),
              elevation: 4,
            ),
            onPressed: onPressed,
            child: Text(buttonText),
          ).animate().slide(begin: const Offset(0, 0.5)).fadeIn(),
          const SizedBox(height: 16),
          Text(
            hasFreeTrial
                ? '7 günlük deneme sadece Aylık plan için geçerlidir. Deneme bitiminde otomatik olarak yenilenir. İstediğiniz zaman iptal edebilirsiniz.'
                : 'Abonelik, satın almayı onayladığınızda başlar ve bir sonraki faturalama döneminde otomatik olarak yenilenir. Google Play Store ayarlarından istediğiniz zaman iptal edebilirsiniz.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.secondaryTextColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}