import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// TODO: Replace with your actual RevenueCat API keys
const String _googleApiKey = 'goog_JStBnogEUetfbcoYdIHKyTZEdXf';
const String _appleApiKey = 'appl_api_key_placeholder'; // Replace if you have an Apple key

class PurchaseOutcome {
  final CustomerInfo? info;
  final bool cancelled;
  final String? error;
  const PurchaseOutcome({this.info, this.cancelled = false, this.error});
  bool get success => info != null;
}

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

  // Satın alma sonucu: başarı (CustomerInfo), iptal (cancelled) veya hata (error)
  static Future<PurchaseOutcome> makePurchase(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package); // PurchaseResult
      return PurchaseOutcome(info: result.customerInfo);
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return const PurchaseOutcome(info: null, cancelled: true);
      }
      print("Error making purchase: $e");
      return PurchaseOutcome(info: null, cancelled: false, error: e.message);
    } catch (e) {
      return PurchaseOutcome(info: null, error: e.toString());
    }
  }
}

// A simple way to check the platform without needing a BuildContext
bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;
bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;
const defaultTargetPlatform = TargetPlatform.android; // Or TargetPlatform.iOS