// core/services/connectivity_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// İnternet bağlantısı kontrolü için provider
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();

  return connectivity.onConnectivityChanged.map((results) {
    // results bir liste - herhangi bir bağlantı varsa true
    return results.isNotEmpty &&
           !results.every((result) => result == ConnectivityResult.none);
  });
});

/// İlk bağlantı durumunu kontrol eden provider
final initialConnectivityProvider = FutureProvider<bool>((ref) async {
  final connectivity = Connectivity();
  final results = await connectivity.checkConnectivity();

  return results.isNotEmpty &&
         !results.every((result) => result == ConnectivityResult.none);
});

