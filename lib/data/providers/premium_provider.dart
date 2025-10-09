import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:taktik/core/services/revenuecat_service.dart';

// Provider to fetch offerings from RevenueCat
final offeringsProvider = FutureProvider<Offerings>((ref) async {
  return await RevenueCatService.getOfferings();
});

// Provider to manage the user's premium status
final premiumStatusProvider = StateNotifierProvider<PremiumStatusNotifier, bool>((ref) {
  return PremiumStatusNotifier();
});

class PremiumStatusNotifier extends StateNotifier<bool> {
  PremiumStatusNotifier() : super(false) {
    _init();
  }

  Future<void> _init() async {
    // Listen to purchaser updates
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      _updatePremiumStatus(customerInfo);
    });

    // Check initial status
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _updatePremiumStatus(customerInfo);
    } catch (e) {
      if (kDebugMode) debugPrint('[RC] getCustomerInfo failed: $e');
    }
  }

  Future<void> refresh() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _updatePremiumStatus(customerInfo);
    } catch (e) {
      if (kDebugMode) debugPrint('[RC] refresh getCustomerInfo failed: $e');
    }
  }

  Future<void> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      _updatePremiumStatus(customerInfo);
    } catch (e) {
      if (kDebugMode) debugPrint('[RC] restorePurchases failed: $e');
    }
  }

  void updateFromCustomerInfo(CustomerInfo customerInfo) {
    _updatePremiumStatus(customerInfo);
  }

  void _updatePremiumStatus(CustomerInfo customerInfo) {
    // Debug: aktif entitlement anahtarlarını ve aktif abonelik ürünlerini logla
    if (kDebugMode) {
      try {
        final entKeys = customerInfo.entitlements.active.keys.toList();
        final subs = customerInfo.activeSubscriptions.toList();
        debugPrint('[RC] Active entitlements: $entKeys | Active subscriptions: $subs');
      } catch (_) {}
    }

    // Premium durumu: aktif entitlement VARSA ya da aktif abonelik VARSA
    final hasAnyActiveEntitlement = customerInfo.entitlements.active.isNotEmpty;
    final hasAnyActiveSubscription = customerInfo.activeSubscriptions.isNotEmpty;
    final isPremium = hasAnyActiveEntitlement || hasAnyActiveSubscription;

    if (state != isPremium) {
      state = isPremium;
    }
  }
}