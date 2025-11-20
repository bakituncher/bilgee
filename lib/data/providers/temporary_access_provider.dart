// lib/data/providers/temporary_access_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taktik/data/providers/shared_prefs_provider.dart';

/// Geçici erişim yöneticisi
/// Kullanıcılar ödüllü reklam izleyerek premium özelliklere geçici erişim kazanır
/// Stats ve Archive için tek bir ortak erişim anahtarı kullanılır
class TemporaryAccessManager {
  final SharedPreferences _prefs;

  TemporaryAccessManager(this._prefs);

  // Tek bir premium features erişim anahtarı (Stats + Archive)
  static const String _premiumFeaturesAccessKey = 'temp_premium_features_access_expiry';
  static const Duration _accessDuration = Duration(hours: 1);

  /// Premium özelliklere geçici erişim ver (Stats + Archive)
  Future<void> grantPremiumFeaturesAccess() async {
    final expiry = DateTime.now().add(_accessDuration).millisecondsSinceEpoch;
    await _prefs.setInt(_premiumFeaturesAccessKey, expiry);
  }

  /// Premium özelliklere erişimi var mı?
  bool hasPremiumFeaturesAccess() {
    final expiry = _prefs.getInt(_premiumFeaturesAccessKey);
    if (expiry == null) return false;

    final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiry);
    final now = DateTime.now();

    return now.isBefore(expiryDate);
  }

  /// Premium features erişimi ne zaman sona eriyor?
  DateTime? getPremiumFeaturesAccessExpiry() {
    final expiry = _prefs.getInt(_premiumFeaturesAccessKey);
    if (expiry == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(expiry);
  }

  // Geriye dönük uyumluluk için wrapper metodlar

  /// Stats'e geçici erişim ver (artık premium features erişimi veriyor)
  @Deprecated('Use grantPremiumFeaturesAccess instead')
  Future<void> grantStatsAccess() async {
    await grantPremiumFeaturesAccess();
  }

  /// Archive'e geçici erişim ver (artık premium features erişimi veriyor)
  @Deprecated('Use grantPremiumFeaturesAccess instead')
  Future<void> grantArchiveAccess() async {
    await grantPremiumFeaturesAccess();
  }

  /// Stats'e erişimi var mı? (premium features erişimini kontrol eder)
  @Deprecated('Use hasPremiumFeaturesAccess instead')
  bool hasStatsAccess() {
    return hasPremiumFeaturesAccess();
  }

  /// Archive'e erişimi var mı? (premium features erişimini kontrol eder)
  @Deprecated('Use hasPremiumFeaturesAccess instead')
  bool hasArchiveAccess() {
    return hasPremiumFeaturesAccess();
  }

  /// Tüm geçici erişimleri temizle
  Future<void> clearAllAccess() async {
    await _prefs.remove(_premiumFeaturesAccessKey);
  }
}

final temporaryAccessProvider = Provider<TemporaryAccessManager>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).requireValue;
  return TemporaryAccessManager(prefs);
});

/// Premium features erişim durumu provider'ı (Stats + Archive)
final hasPremiumFeaturesAccessProvider = Provider<bool>((ref) {
  final tempAccess = ref.watch(temporaryAccessProvider);
  return tempAccess.hasPremiumFeaturesAccess();
});

// Geriye dönük uyumluluk için wrapper provider'lar
/// Stats erişim durumu provider'ı (artık premium features erişimini kontrol eder)
@Deprecated('Use hasPremiumFeaturesAccessProvider instead')
final hasStatsAccessProvider = Provider<bool>((ref) {
  return ref.watch(hasPremiumFeaturesAccessProvider);
});

/// Archive erişim durumu provider'ı (artık premium features erişimini kontrol eder)
@Deprecated('Use hasPremiumFeaturesAccessProvider instead')
final hasArchiveAccessProvider = Provider<bool>((ref) {
  return ref.watch(hasPremiumFeaturesAccessProvider);
});

