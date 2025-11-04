// lib/core/utils/premium_display_utils.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/data/providers/premium_provider.dart';

/// Utility class to handle displaying the premium screen
class PremiumDisplayUtils {
  /// Show the premium screen if the user is not already premium
  /// Returns true if the screen was shown, false otherwise
  static Future<bool> showPremiumScreenIfNeeded({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    // Check if user is already premium
    final isPremium = ref.read(premiumStatusProvider);
    
    if (isPremium) {
      debugPrint('[PremiumDisplay] User is premium, skipping display');
      return false;
    }
    
    // Check if context is still mounted and valid for navigation
    if (!context.mounted) {
      debugPrint('[PremiumDisplay] Context not mounted, skipping display');
      return false;
    }
    
    // Navigate to premium screen
    try {
      context.push(AppRoutes.premium);
      debugPrint('[PremiumDisplay] Premium screen displayed');
      return true;
    } catch (e) {
      debugPrint('[PremiumDisplay] Error showing premium screen: $e');
      return false;
    }
  }
}
