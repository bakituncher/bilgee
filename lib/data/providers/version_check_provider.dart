// lib/data/providers/version_check_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/core/services/version_check_service.dart';

/// Uygulama açılışında versiyon kontrolü yapan provider
final versionCheckProvider = FutureProvider<VersionCheckResult>((ref) async {
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

