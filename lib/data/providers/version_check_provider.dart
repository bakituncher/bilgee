// lib/data/providers/version_check_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/core/services/version_check_service.dart';
import 'package:taktik/core/services/connectivity_service.dart';
import 'package:taktik/data/providers/admin_providers.dart';

/// Uygulama açılışında versiyon kontrolü yapan provider
/// İnternet bağlantısı değişikliklerini izler ve online olduğunda yeniden kontrol eder
/// Admin kullanıcılar için zorunlu güncelleme gerektirmez
final versionCheckProvider = FutureProvider<VersionCheckResult>((ref) async {
  // İnternet bağlantısını izle - her değiştiğinde provider yeniden çalışacak
  final connectivityAsync = ref.watch(connectivityProvider);
  final isOnline = connectivityAsync.valueOrNull ?? true;

  // Admin kontrolü yap
  final isAdminAsync = ref.watch(adminClaimProvider);
  final isAdmin = isAdminAsync.valueOrNull ?? false;

  // Offline ise veya admin ise, güncelleme gerektirmeyen varsayılan sonuç döndür
  if (!isOnline || isAdmin) {
    final packageInfo = await VersionCheckService.getPackageInfo();
    return VersionCheckResult(
      updateRequired: false,
      currentVersion: packageInfo.version,
      currentBuildNumber: int.tryParse(packageInfo.buildNumber) ?? 0,
    );
  }

  // Online ise ve admin değilse gerçek kontrol yap
  return await VersionCheckService.checkVersion();
});

/// Versiyon kontrolünü manuel olarak tetiklemek için state provider
final versionCheckTriggerProvider = StateProvider<int>((ref) => 0);

/// Versiyon kontrolünü yeniden yapmak için kullanılabilir provider
final versionCheckRefreshableProvider = FutureProvider.autoDispose<VersionCheckResult>((ref) async {
  // Trigger'ı izle, değiştiğinde yeniden kontrol et
  ref.watch(versionCheckTriggerProvider);
  return await VersionCheckService.checkVersion();
});

