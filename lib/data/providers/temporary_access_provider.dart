// lib/data/providers/temporary_access_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taktik/data/providers/shared_prefs_provider.dart';

/// Geçici erişim yöneticisi
/// Kullanıcılar ödüllü reklam izleyerek 1 saatlik premium özelliklere erişim kazanır
class TemporaryAccessManager {
  final SharedPreferences _prefs;

  TemporaryAccessManager(this._prefs);

  static const String _statsAccessKey = 'temp_stats_access_expiry';
  static const String _archiveAccessKey = 'temp_archive_access_expiry';
  static const Duration _accessDuration = Duration(hours: 1);

  /// Stats'e geçici erişim ver
  Future<void> grantStatsAccess() async {
    final expiry = DateTime.now().add(_accessDuration).millisecondsSinceEpoch;
    await _prefs.setInt(_statsAccessKey, expiry);
  }

  /// Archive'e geçici erişim ver
  Future<void> grantArchiveAccess() async {
    final expiry = DateTime.now().add(_accessDuration).millisecondsSinceEpoch;
    await _prefs.setInt(_archiveAccessKey, expiry);
  }

  /// Stats'e erişimi var mı?
  bool hasStatsAccess() {
    final expiry = _prefs.getInt(_statsAccessKey);
    if (expiry == null) return false;

    final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiry);
    final now = DateTime.now();

    return now.isBefore(expiryDate);
  }

  /// Archive'e erişimi var mı?
  bool hasArchiveAccess() {
    final expiry = _prefs.getInt(_archiveAccessKey);
    if (expiry == null) return false;

    final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiry);
    final now = DateTime.now();

    return now.isBefore(expiryDate);
  }

  /// Stats erişimi ne zaman sona eriyor?
  DateTime? getStatsAccessExpiry() {
    final expiry = _prefs.getInt(_statsAccessKey);
    if (expiry == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(expiry);
  }

  /// Archive erişimi ne zaman sona eriyor?
  DateTime? getArchiveAccessExpiry() {
    final expiry = _prefs.getInt(_archiveAccessKey);
    if (expiry == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(expiry);
  }

  /// Tüm geçici erişimleri temizle
  Future<void> clearAllAccess() async {
    await _prefs.remove(_statsAccessKey);
    await _prefs.remove(_archiveAccessKey);
  }
}

final temporaryAccessProvider = Provider<TemporaryAccessManager>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).requireValue;
  return TemporaryAccessManager(prefs);
});

/// Stats erişim durumu provider'ı
final hasStatsAccessProvider = Provider<bool>((ref) {
  final tempAccess = ref.watch(temporaryAccessProvider);
  return tempAccess.hasStatsAccess();
});

/// Archive erişim durumu provider'ı
final hasArchiveAccessProvider = Provider<bool>((ref) {
  final tempAccess = ref.watch(temporaryAccessProvider);
  return tempAccess.hasArchiveAccess();
});

