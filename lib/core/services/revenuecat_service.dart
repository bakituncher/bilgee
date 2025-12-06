// --- REVENUECAT DEVRE DIŞI ---
// import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
// import 'package:purchases_flutter/purchases_flutter.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';

// Mock CustomerInfo for disabled RevenueCat
class MockCustomerInfo {}

// Mock StoreProduct
class MockStoreProduct {
  final double price = 0.0;
  final String priceString = '₺0,00';
  final dynamic introductoryPrice = null;
}

// Mock Package for disabled RevenueCat
class MockPackage {
  final String identifier = '';
  final MockStoreProduct storeProduct = MockStoreProduct();
}

class PurchaseOutcome {
  final MockCustomerInfo? info;
  final bool cancelled;
  final String? error;
  const PurchaseOutcome({this.info, this.cancelled = false, this.error});
  bool get success => info != null;
}

// Mock Offerings
class MockOfferings {
  final Map<String, dynamic> all = {};
  dynamic get current => null;
}

class RevenueCatService {
  // RevenueCat devre dışı - init hiçbir şey yapmıyor
  static Future<void> init() async {
    debugPrint("⚠️ RevenueCat devre dışı - init çağrısı atlandı");
    return;
  }

  static bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;
  static bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  // Mock getOfferings
  static Future<MockOfferings> getOfferings() async {
    debugPrint("⚠️ RevenueCat devre dışı - getOfferings mock veri döndürüyor");
    return MockOfferings();
  }

  // Mock makePurchase - her zaman iptal edilmiş gibi davranır
  static Future<PurchaseOutcome> makePurchase(MockPackage package) async {
    debugPrint("⚠️ RevenueCat devre dışı - makePurchase çağrısı mock döndürüyor");
    return const PurchaseOutcome(
      info: null,
      cancelled: true,
      error: 'RevenueCat devre dışı'
    );
  }

  // Mock restorePurchases
  static Future<MockCustomerInfo?> restorePurchases() async {
    debugPrint("⚠️ RevenueCat devre dışı - restorePurchases mock döndürüyor");
    return null;
  }
}
