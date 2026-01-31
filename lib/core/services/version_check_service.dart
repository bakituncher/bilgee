// lib/core/services/version_check_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Versiyon karşılaştırma ve zorunlu güncelleme kontrolü için servis
class VersionCheckService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Package bilgisini getirir (internal helper)
  static Future<PackageInfo> getPackageInfo() async {
    return await PackageInfo.fromPlatform();
  }

  /// Uygulama versiyonunu kontrol eder ve zorunlu güncelleme gerekip gerekmediğini döner
  static Future<VersionCheckResult> checkVersion() async {
    try {
      // Uygulama bilgilerini al
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      if (kDebugMode) {
        debugPrint('[VersionCheck] Current: $currentVersion ($currentBuildNumber)');
      }

      // Firestore'dan minimum versiyon bilgisini çek
      final platform = Platform.isIOS ? 'ios' : 'android';
      final configDoc = await _firestore
          .collection('app_config')
          .doc('version_control')
          .get();

      if (!configDoc.exists) {
        if (kDebugMode) {
          debugPrint('[VersionCheck] Config document not found, assuming no update needed');
        }
        return VersionCheckResult(
          updateRequired: false,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
        );
      }

      final data = configDoc.data() ?? {};
      final platformData = data[platform] as Map<String, dynamic>?;

      if (platformData == null) {
        if (kDebugMode) {
          debugPrint('[VersionCheck] No $platform config found');
        }
        return VersionCheckResult(
          updateRequired: false,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
        );
      }

      // Minimum versiyon ve build number'ı al
      final minVersion = platformData['minVersion'] as String?;
      final minBuildNumber = platformData['minBuildNumber'] as int?;
      final latestVersion = platformData['latestVersion'] as String?;
      final latestBuildNumber = platformData['latestBuildNumber'] as int?;
      final updateMessage = platformData['updateMessage'] as String?;
      final forceUpdate = platformData['forceUpdate'] as bool? ?? false;

      if (kDebugMode) {
        debugPrint('[VersionCheck] Min: $minVersion ($minBuildNumber), Latest: $latestVersion ($latestBuildNumber)');
        debugPrint('[VersionCheck] Force Update: $forceUpdate');
      }

      // Build number kontrolü (PRIMARY - en güvenilir yöntem)
      bool needsUpdate = false;
      if (minBuildNumber != null) {
        needsUpdate = currentBuildNumber < minBuildNumber;
      } else if (minVersion != null && minVersion.isNotEmpty) {
        // Fallback: Build number yoksa version string karşılaştır (önerilmez)
        needsUpdate = _isVersionLower(currentVersion, minVersion);
      }

      return VersionCheckResult(
        updateRequired: needsUpdate && forceUpdate,
        updateAvailable: needsUpdate,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
        minVersion: minVersion,
        minBuildNumber: minBuildNumber,
        latestVersion: latestVersion,
        latestBuildNumber: latestBuildNumber,
        updateMessage: updateMessage,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VersionCheck] Error: $e');
      }
      // Hata durumunda güncelleme gerektirme (kullanıcıyı bloklamayalım)
      final packageInfo = await PackageInfo.fromPlatform();
      return VersionCheckResult(
        updateRequired: false,
        currentVersion: packageInfo.version,
        currentBuildNumber: int.tryParse(packageInfo.buildNumber) ?? 0,
      );
    }
  }

  /// Version string'lerini karşılaştırır (semantic versioning)
  /// Returns true if current < minimum
  static bool _isVersionLower(String current, String minimum) {
    try {
      final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final minParts = minimum.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      // En uzun listeye göre karşılaştır
      final maxLength = currentParts.length > minParts.length ? currentParts.length : minParts.length;

      for (int i = 0; i < maxLength; i++) {
        final currentPart = i < currentParts.length ? currentParts[i] : 0;
        final minPart = i < minParts.length ? minParts[i] : 0;

        if (currentPart < minPart) return true;
        if (currentPart > minPart) return false;
      }

      return false; // Versiyonlar eşit
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VersionCheck] Error comparing versions: $e');
      }
      return false;
    }
  }

  /// Firestore'da versiyon kontrolü yapılandırmasını oluşturur (sadece admin için)
  static Future<void> updateVersionConfig({
    required String platform, // 'ios' veya 'android'
    String? minVersion,
    int? minBuildNumber,
    String? latestVersion,
    int? latestBuildNumber,
    String? updateMessage,
    bool? forceUpdate,
  }) async {
    final data = <String, dynamic>{};

    if (minVersion != null) data['minVersion'] = minVersion;
    if (minBuildNumber != null) data['minBuildNumber'] = minBuildNumber;
    if (latestVersion != null) data['latestVersion'] = latestVersion;
    if (latestBuildNumber != null) data['latestBuildNumber'] = latestBuildNumber;
    if (updateMessage != null) data['updateMessage'] = updateMessage;
    if (forceUpdate != null) data['forceUpdate'] = forceUpdate;

    await _firestore
        .collection('app_config')
        .doc('version_control')
        .set({
      platform: data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (kDebugMode) {
      debugPrint('[VersionCheck] Updated $platform config: $data');
    }
  }
}

/// Versiyon kontrolü sonucu
class VersionCheckResult {
  final bool updateRequired; // Zorunlu güncelleme gerekli mi?
  final bool updateAvailable; // Güncelleme mevcut mu? (zorunlu olmayabilir)
  final String currentVersion;
  final int currentBuildNumber;
  final String? minVersion;
  final int? minBuildNumber;
  final String? latestVersion;
  final int? latestBuildNumber;
  final String? updateMessage;

  const VersionCheckResult({
    required this.updateRequired,
    this.updateAvailable = false,
    required this.currentVersion,
    required this.currentBuildNumber,
    this.minVersion,
    this.minBuildNumber,
    this.latestVersion,
    this.latestBuildNumber,
    this.updateMessage,
  });

  @override
  String toString() {
    return 'VersionCheckResult(updateRequired: $updateRequired, current: $currentVersion ($currentBuildNumber), min: $minVersion ($minBuildNumber))';
  }
}

