import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:taktik/core/services/revenuecat_service.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';

// Provider to fetch offerings from RevenueCat using the central service
final offeringsProvider = FutureProvider<Offerings>((ref) async {
  return await ref.watch(revenueCatServiceProvider).getOfferings();
});

// Provider to manage the user's premium status.
// This provider now derives its state directly from the
// server-authoritative userProfileProvider stream.
final premiumStatusProvider = Provider<bool>((ref) {
  final userProfile = ref.watch(userProfileProvider);
  return userProfile.value?.isPremium ?? false;
});

// Central provider for the RevenueCatService instance.
final revenueCatServiceProvider = Provider<RevenueCatService>((ref) {
  return RevenueCatService();
});
