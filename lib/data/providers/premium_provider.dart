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
    final customerInfo = await Purchases.getCustomerInfo();
    _updatePremiumStatus(customerInfo);
  }

  void _updatePremiumStatus(CustomerInfo customerInfo) {
    // Check if the user has an active entitlement.
    // The entitlement identifier 'Taktik (Play Store)' was provided by the user.
    final isActive = customerInfo.entitlements.all['Taktik (Play Store)']?.isActive == true;
    if (state != isActive) {
      state = isActive;
    }
  }
}