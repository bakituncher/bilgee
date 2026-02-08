// lib/core/services/time_check_service.dart
import 'package:ntp/ntp.dart';
import 'package:flutter/foundation.dart';

class TimeCheckService {
  /// Maksimum izin verilen zaman sapması (saniye cinsinden)
  static const int maxThresholdSeconds = 120; // 2 dakika

  /// Cihaz saatinin doğru olup olmadığını kontrol eder
  static Future<bool> isTimeAccurate() async {
    try {
      // NTP üzerinden gerçek zamanı al
      DateTime ntpTime = await NTP.now().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('NTP Timeout'),
      );
      DateTime localTime = DateTime.now();

      int offset = ntpTime.difference(localTime).inSeconds.abs();

      if (kDebugMode) {
        debugPrint('[TimeCheck] NTP Zamanı: $ntpTime');
        debugPrint('[TimeCheck] Yerel Zaman: $localTime');
        debugPrint('[TimeCheck] Sapma: $offset saniye');
      }

      return offset <= maxThresholdSeconds;
    } catch (e) {
      if (kDebugMode) debugPrint('[TimeCheck] Hata: $e');
      // Eğer NTP kontrolü başarısız olursa (örn. internet hızı veya NTP sunucusuna ulaşılamaması),
      // kullanıcıyı engellememek için varsayılan olarak true dönebiliriz.
      // Ancak kritik işlemlerde bu kontrol çok önemliyse false da dönebilir.
      return true;
    }
  }
}

