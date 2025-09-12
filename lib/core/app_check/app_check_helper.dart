import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// App Check tokenının hazır olduğundan emin olmak için yardımcı.
/// İlk uygulama açılışında Functions çağrısından hemen önce token henüz üretilmemiş
/// olabiliyor ve boş / eksik header sebebiyle sunucuda decode hatası oluşuyor.
Future<void> ensureAppCheckTokenReady({int maxAttempts = 3}) async {
  // Debug modunda genelde anında hazır; yine de aynı akış basit.
  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      final token = await FirebaseAppCheck.instance.getToken();
      if (token != null && token.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[AppCheck] Token başarıyla alındı (deneme $attempt)');
        }
        return; // Hazır
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppCheck] Token denemesi $attempt hata: $e');
      }
      
      // "Too many attempts" hatası alındığında daha fazla deneme yapmaya gerek yok
      if (e.toString().toLowerCase().contains('too many attempts')) {
        if (kDebugMode) {
          debugPrint('[AppCheck] Too many attempts hatası - token denemeleri durduruluyor');
        }
        break;
      }
      
      // Firebase exception türü kontrolü
      if (e.toString().contains('firebase') && e.toString().contains('exception')) {
        if (kDebugMode) {
          debugPrint('[AppCheck] Firebase exception - işlem durduruluyor');
        }
        break;
      }
      
      // Devam edip yeniden deneyeceğiz.
    }
    // Son deneme değilse kısa gecikme (artan backoff)
    if (attempt < maxAttempts) {
      final delayMs = 100 + (attempt * 100); // 200, 300, 400ms
      await Future.delayed(Duration(milliseconds: delayMs));
    }
  }
  // Buraya düşerse token alınamadı; Functions yine enforcement kapalı ise devam eder.
  if (kDebugMode) {
    debugPrint('[AppCheck] Uyarı: Token alınamadı ancak callable fonksiyon yine de çalışabilir');
  }
}
