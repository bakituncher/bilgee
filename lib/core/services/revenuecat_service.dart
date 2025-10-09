import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// TODO: Replace with your actual RevenueCat API keys
const String _googleApiKey = 'goog_JStBnogEUetfbcoYdIHKyTZEdXf';
const String _appleApiKey = 'appl_api_key_placeholder'; // Replace if you have an Apple key

class RevenueCatService {
  static Future<void> init() async {
    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration configuration;
    if (isAndroid) {
      configuration = PurchasesConfiguration(_googleApiKey);
    } else if (isIOS) {
      configuration = PurchasesConfiguration(_appleApiKey);
    } else {
      // Unsupported platform
      return;
    }
    await Purchases.configure(configuration);
  }

  static bool get isAndroid => TargetPlatform.android == defaultTargetPlatform;
  static bool get isIOS => TargetPlatform.iOS == defaultTargetPlatform;

  static Future<Offerings> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } on PlatformException catch (e) {
      print("Error fetching offerings: $e");
      rethrow; // Rethrow to be handled by the provider
    }
  }

  static Future<bool> makePurchase(Package package) async {
    try {
      await Purchases.purchasePackage(package);
      return true;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        print("Error making purchase: $e");
      }
      return false;
    }
  }
}

// A simple way to check the platform without needing a BuildContext
bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;
bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;
const defaultTargetPlatform = TargetPlatform.android; // Or TargetPlatform.iOS