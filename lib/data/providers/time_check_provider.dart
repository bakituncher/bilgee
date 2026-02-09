// lib/data/providers/time_check_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/core/services/time_check_service.dart';
import 'package:taktik/core/services/connectivity_service.dart';

/// Cihaz saatinin doğruluğunu kontrol eden provider.
/// İnternet bağlantısı olduğunda kontrolü gerçekleştirir.
final timeCheckProvider = FutureProvider<bool>((ref) async {
  final connectivityAsync = ref.watch(connectivityProvider);
  final isOnline = connectivityAsync.valueOrNull ?? false;

  if (!isOnline) {
    // İnternet yoksa kontrolü es geç, internet geldiğinde tekrar tetiklenir.
    return true;
  }

  return await TimeCheckService.isTimeAccurate();
});

/// Zaman kontrolünü manuel tetiklemek için.
final timeCheckTriggerProvider = StateProvider<int>((ref) => 0);

