import 'package:flutter_riverpod/flutter_riverpod.dart';
// --- REVENUECAT DEVRE DIŞI ---
// import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:taktik/core/services/revenuecat_service.dart';
import 'package:taktik/data/providers/firestore_providers.dart';

// Provider to fetch offerings from RevenueCat using the static method
// RevenueCat devre dışı olduğu için mock data döndürüyor
final offeringsProvider = FutureProvider<MockOfferings>((ref) async {
  return await RevenueCatService.getOfferings();
});

// Provider to manage the user's premium status.
// This provider derives its state directly from the
// server-authoritative userProfileProvider stream.
final premiumStatusProvider = Provider<bool>((ref) {
  final userProfile = ref.watch(userProfileProvider);
  return userProfile.value?.isPremium ?? false;
});

// The unnecessary revenueCatServiceProvider has been removed.
// All calls to RevenueCatService methods should be made statically,
// e.g., RevenueCatService.restorePurchases().
