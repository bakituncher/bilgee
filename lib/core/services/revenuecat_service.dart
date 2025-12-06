import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PurchaseOutcome {
  final CustomerInfo? info;
  final bool cancelled;
  final String? error;
  const PurchaseOutcome({this.info, this.cancelled = false, this.error});
  bool get success => info != null;
}

class RevenueCatService {
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) {
      debugPrint("⚠️ RevenueCat zaten başlatılmış");
      return;
    }

    await Purchases.setLogLevel(LogLevel.debug);

    // Environment variables'dan API anahtarlarını al
    final googleApiKey = dotenv.env['REVENUECAT_GOOGLE_API_KEY'];
    final appleApiKey = dotenv.env['REVENUECAT_APPLE_API_KEY'];

    PurchasesConfiguration configuration;
    if (isAndroid) {
      if (googleApiKey == null || googleApiKey.isEmpty) {
        throw Exception('RevenueCat Google API key not found in environment variables');
      }
      configuration = PurchasesConfiguration(googleApiKey);
    } else if (isIOS) {
      if (appleApiKey == null || appleApiKey.isEmpty) {
        throw Exception('RevenueCat Apple API key not found in environment variables');
      }
      configuration = PurchasesConfiguration(appleApiKey);
    } else {
      // Unsupported platform
      debugPrint("⚠️ RevenueCat desteklenmeyen platform");
      return;
    }

    await Purchases.configure(configuration);
    _isInitialized = true;
    debugPrint("✅ RevenueCat configure edildi");
  }

  static bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;
  static bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  static Future<Offerings> getOfferings() async {
    if (!_isInitialized) {
      throw Exception('RevenueCat henüz başlatılmadı. Lütfen önce init() metodunu çağırın.');
    }
    try {
      return await Purchases.getOfferings();
    } on PlatformException catch (e) {
      debugPrint("Error fetching offerings: $e");
      rethrow; // Rethrow to be handled by the provider
    }
  }

  // Satın alma sonucu: başarı (CustomerInfo), iptal (cancelled) veya hata (error)
  static Future<PurchaseOutcome> makePurchase(Package package) async {
    if (!_isInitialized) {
      throw Exception('RevenueCat henüz başlatılmadı. Lütfen önce init() metodunu çağırın.');
    }
    try {
      final result = await Purchases.purchasePackage(package); // PurchaseResult
      return PurchaseOutcome(info: result.customerInfo);
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return const PurchaseOutcome(info: null, cancelled: true);
      } else if (errorCode == PurchasesErrorCode.productAlreadyPurchasedError) {
        // Zaten satın alınmışsa, bu bir başarı durumudur.
        // Durumu senkronize etmek için restorePurchases çağır.
        final customerInfo = await Purchases.restorePurchases();
        return PurchaseOutcome(info: customerInfo);
      }
      debugPrint("Error making purchase: $e");
      return PurchaseOutcome(info: null, cancelled: false, error: e.message);
    } catch (e) {
      return PurchaseOutcome(info: null, error: e.toString());
    }
  }

  static Future<CustomerInfo?> restorePurchases() async {
    if (!_isInitialized) {
      throw Exception('RevenueCat henüz başlatılmadı. Lütfen önce init() metodunu çağırın.');
    }
    try {
      return await Purchases.restorePurchases();
    } on PlatformException catch (e) {
      debugPrint("Error restoring purchases: $e");
      return null;
    }
  }
}
