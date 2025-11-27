// lib/core/utils/app_info_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Uygulama bilgilerini (versiyon, build number, vb.) sağlayan provider
final appInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

/// Uygulama versiyonunu döndüren provider (örn: "1.2.3")
final appVersionProvider = Provider<String>((ref) {
  final appInfo = ref.watch(appInfoProvider);
  return appInfo.when(
    data: (info) => info.version,
    loading: () => '...',
    error: (_, __) => 'Bilinmiyor',
  );
});

/// Uygulama build numarasını döndüren provider (örn: "24")
final appBuildNumberProvider = Provider<String>((ref) {
  final appInfo = ref.watch(appInfoProvider);
  return appInfo.when(
    data: (info) => info.buildNumber,
    loading: () => '...',
    error: (_, __) => '?',
  );
});

/// Tam versiyon stringi (örn: "1.2.3 (24)")
final appFullVersionProvider = Provider<String>((ref) {
  final version = ref.watch(appVersionProvider);
  final buildNumber = ref.watch(appBuildNumberProvider);

  if (version == '...' || version == 'Bilinmiyor') return version;
  return '$version ($buildNumber)';
});

