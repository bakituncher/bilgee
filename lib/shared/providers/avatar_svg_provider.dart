import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:taktik/core/services/connectivity_service.dart';

/// HTTP client injection for tests.
final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

/// Online/offline status with a sensible default (online) to avoid UI flicker.
final isOnlineProvider = Provider<bool>((ref) {
  final connectivityAsync = ref.watch(connectivityProvider);
  return connectivityAsync.valueOrNull ?? true;
});

/// Fetches Dicebear (or any) SVG and returns it as a String.
///
/// Important: This is intentionally NOT cached persistently because the main
/// issue is the "offline on first build -> never retries" behavior.
/// The provider is keepAlive per-url and will automatically retry when
/// connectivity turns online.
final avatarSvgProvider = FutureProvider.family.autoDispose<String, String>((ref, url) async {
  // Keep alive shortly so if the widget rebuilds we don't refetch immediately.
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 5), link.close);

  final isOnline = ref.watch(isOnlineProvider);
  if (!isOnline) {
    throw const SocketException('offline');
  }

  final client = ref.watch(httpClientProvider);

  try {
    final resp = await client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException('HTTP ${resp.statusCode}');
    }

    // Dicebear svgs are utf8.
    return utf8.decode(resp.bodyBytes);
  } on TimeoutException {
    throw const SocketException('timeout');
  }
});

