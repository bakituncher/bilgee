import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:taktik/core/services/revenuecat_service.dart';
import 'package:taktik/data/providers/firestore_providers.dart';

// Provider to fetch offerings from RevenueCat
final offeringsProvider = FutureProvider<Offerings>((ref) async {
  return await RevenueCatService.getOfferings();
});

// Provider to manage the user's premium status.
// REFACTORED: This provider now derives its state directly from the
// server-authoritative userProfileProvider stream. This ensures a single
// source of truth for the user's premium status across the app.
final premiumStatusProvider = Provider<bool>((ref) {
  // Watch the server-verified user profile stream.
  final userProfile = ref.watch(userProfileProvider);
  // Return the premium status from the user model, defaulting to false.
  return userProfile.value?.isPremium ?? false;
});

// The old PremiumStatusNotifier has been removed as it represented a
// client-side source of truth which could conflict with the server's authoritative state.
// The app now relies solely on the Firestore stream for premium status.
// We can still provide a way to trigger a refresh from RevenueCat if needed.
final revenueCatServiceProvider = Provider((ref) {
  return RevenueCatService();
});

class RevenueCatService {
  Future<void> refresh() async {
    try {
      await Purchases.getCustomerInfo();
    } catch (_) {
      // Handle error if necessary
    }
  }

  Future<void> restorePurchases() async {
    try {
      await Purchases.restorePurchases();
    } catch (_) {
      // Handle error if necessary
    }
  }
}
