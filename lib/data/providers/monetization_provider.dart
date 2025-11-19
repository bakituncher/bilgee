// lib/data/providers/monetization_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/core/services/monetization_manager.dart';
import 'package:taktik/data/providers/shared_prefs_provider.dart';

/// Monetization Manager Provider
final monetizationManagerProvider = Provider<MonetizationManager>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).requireValue;
  return MonetizationManager(prefs);
});

