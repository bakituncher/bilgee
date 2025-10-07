import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/shared/widgets/loading_screen.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Product IDs from Google Play Store
const String _monthlySubscriptionId = 'taktikai_monthly_subscription';
const String _yearlySubscriptionId = 'taktikai_yearly_subscription';
const List<String> _kProductIds = <String>[
  _monthlySubscriptionId,
  _yearlySubscriptionId,
];

// Provider for the purchase service
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return PurchaseService(FirebaseFunctions.instance);
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
      // Handle store not available
      return [];
    }
    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(_kProductIds.toSet());
    if (response.error != null) {
      // Handle error
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
            // Show pending UI
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
      onDone: () {
        _subscription.cancel();
      },
      onError: (error) {
        onError();
      },
    );
  }

  Future<void> buySubscription(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam =
        PurchaseParam(productDetails: productDetails);
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> verifyPurchase(PurchaseDetails purchaseDetails) async {
    final HttpsCallable callable =
        _functions.httpsCallable('premium-verifyPurchase');
    final packageInfo = await PackageInfo.fromPlatform();

    try {
      await callable.call(<String, dynamic>{
        'productId': purchaseDetails.productID,
        'purchaseToken': purchaseDetails.verificationData.serverVerificationData,
        'packageName': packageInfo.packageName,
      });
    } on FirebaseFunctionsException {
      // Re-throw to be handled by the UI
      rethrow;
    }
  }

  void dispose() {
    _subscription.cancel();
  }
}

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  ProductDetails? _selectedProduct;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final purchaseService = ref.read(purchaseServiceProvider);
    purchaseService.listenToPurchaseUpdated((purchaseDetails) async {
      setState(() => _isLoading = true);
      try {
        await purchaseService.verifyPurchase(purchaseDetails);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Abonelik doğrulandı! Premium özellikler aktif.'),
              backgroundColor: Colors.green),
        );
        // Pop the screen on success
        if (mounted) context.pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Doğrulama hatası: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }, () {
      // Handle purchase stream error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Satın alma işlemi sırasında bir hata oluştu.'),
            backgroundColor: Colors.red),
      );
    });
  }

  @override
  void dispose() {
    ref.read(purchaseServiceProvider).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsyncValue = ref.watch(productsProvider);
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      appBar: AppBar(
        title: const Text('TaktikAI Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          productsAsyncValue.when(
            data: (products) {
              if (products.isEmpty) {
                return const Center(
                  child: Text(
                    'Abonelikler yüklenemedi. Lütfen daha sonra tekrar deneyin.',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              // Set default selection
              _selectedProduct ??= products.firstWhere((p) => p.id == _yearlySubscriptionId);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 32),
                    _buildSubscriptionOptions(context, products),
                    const SizedBox(height: 32),
                    _buildPerksList(context),
                    const SizedBox(height: 32),
                    _buildCTAButton(context),
                    const SizedBox(height: 16),
                    _buildTermsAndConditions(context),
                  ],
                ),
              );
            },
            loading: () => const LoadingScreen(),
            error: (err, stack) => Center(
              child: Text('Hata: ${err.toString()}', style: const TextStyle(color: Colors.white)),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    SizedBox(height: 20),
                    Text(
                      'Abonelik doğrulanıyor...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 60),
        const SizedBox(height: 16),
        Text(
          'Potansiyelini Ortaya Çıkar',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'TaktikAI\'ın tüm gücünü kullanarak hedeflerine daha hızlı ulaş.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildSubscriptionOptions(BuildContext context, List<ProductDetails> products) {
    final monthly = products.firstWhere((p) => p.id == _monthlySubscriptionId);
    final yearly = products.firstWhere((p) => p.id == _yearlySubscriptionId);

    return Column(
      children: [
        _buildSubscriptionCard(
          context: context,
          product: yearly,
          title: 'Yıllık Plan',
          subtitle: 'En Avantajlı Seçim',
          isSelected: _selectedProduct?.id == _yearlySubscriptionId,
          onTap: () {
            setState(() {
              _selectedProduct = yearly;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildSubscriptionCard(
          context: context,
          product: monthly,
          title: 'Aylık Plan',
          subtitle: null,
          isSelected: _selectedProduct?.id == _monthlySubscriptionId,
          onTap: () {
            setState(() {
              _selectedProduct = monthly;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSubscriptionCard({
    required BuildContext context,
    required ProductDetails product,
    required String title,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.lightSurfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: Colors.amber, width: 3)
              : Border.all(color: Colors.transparent, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: AppTheme.primaryTextColor),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              product.price,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primaryTextColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerksList(BuildContext context) {
    const perks = [
      'Sınırsız AI Koç Desteği',
      'Kişiselleştirilmiş Strateji Planları',
      'Derinlemesine Zayıflık Analizi',
      'Yeni Özelliklere Erken Erişim',
      'Reklamsız Deneyim',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tüm Premium Özellikler',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...perks.map((perk) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.amber, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      perk,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildCTAButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: () {
        if (_selectedProduct != null) {
          final purchaseService = ref.read(purchaseServiceProvider);
          purchaseService.buySubscription(_selectedProduct!);
        }
      },
      child: const Text('Premium\'a Geç'),
    );
  }

  Widget _buildTermsAndConditions(BuildContext context) {
    return Text(
      'Aboneliğiniz, mevcut dönemin bitiminden en az 24 saat önce iptal edilmediği sürece otomatik olarak yenilenir. '
      'Ayarları istediğiniz zaman Google Play aboneliklerinizden yönetebilirsiniz.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
    );
  }
}