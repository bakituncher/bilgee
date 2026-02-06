import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  AndroidNotificationChannel? _channel;
  void Function(String route)? _navigate;

  // Son gösterilenleri daha uzun süre tut (10 dk) – çift bildirimi engelle
  final Map<String, DateTime> _recent = {};
  bool _isDuplicate(RemoteMessage msg, {required String title, required String body, required String route}) {
    try {
      final now = DateTime.now();
      // Eski kayıtları temizle (10 dakika)
      _recent.removeWhere((key, ts) => now.difference(ts).inMinutes > 10);

      // Daha güvenilir bir anahtar oluştur
      String key = msg.messageId ?? msg.data['messageId'] as String? ?? '';
      if (key.isEmpty) {
        // Mesaj ID yoksa hash tabanlı anahtar oluştur
        final content = '$title|$body|$route|${msg.data.toString()}';
        key = content.hashCode.toString();
      }

      if (_recent.containsKey(key)) {
        if (kDebugMode) debugPrint('Çift bildirim engellendi: $key');
        return true;
      }
      _recent[key] = now;
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('Çift bildirim kontrolü hatası: $e');
      return false;
    }
  }

  String? _appVersion;
  int? _appBuild;
  String? _currentToken;

  Future<void> initialize({required void Function(String route) onNavigate}) async {
    if (_initialized) return;
    _navigate = onNavigate;

    // Uygulama sürüm bilgisi
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
      _appBuild = int.tryParse(info.buildNumber);
    } catch (_) {}

    // DÜZELTME: '@mipmap/ic_launcher' yerine Manifest'teki '@mipmap/launcher_icon' kullanılmalı
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iOSInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iOSInit);
    await _fln.initialize(initSettings, onDidReceiveNotificationResponse: (resp) {
      final route = resp.payload;
      if (route != null && route.isNotEmpty) {
        _navigate?.call(route);
      }
    });

    _channel = const AndroidNotificationChannel(
      'bilge_general',
      'Taktik Tavşan Genel',
      description: 'Genel bildirimler',
      importance: Importance.high,
    );
    await _fln
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel!);

    // iOS foreground sunum ayarları
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false);

    // NOT: Bildirim izni artık NotificationPermissionScreen'de isteniyor
    // İzin durumunu kontrol edip token'ı kaydet
    await _ensureAndRegisterToken();
    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      _registerToken(t, _appVersion, _appBuild);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _showLocal(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final route = message.data['route'] as String?;
      if (route != null && route.isNotEmpty) {
        _navigate?.call(route);
      }
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      final route = initial.data['route'] as String?;
      if (route != null && route.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _navigate?.call(route));
      }
    }

    _initialized = true;
  }

  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    // Arka planda sistem bildirimi zaten gösterilir.
  }


  Future<void> _ensureAndRegisterToken() async {
    try {
      // iOS'ta izin verilmeden token almaya çalışmak izin dialogu açabilir
      // Bu yüzden önce izin durumunu kontrol ediyoruz
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        // İzin henüz sorulmamış, NotificationPermissionScreen'de sorulacak
        if (kDebugMode) debugPrint('FCM: İzin henüz sorulmamış, token alınmadı');
        return;
      }

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        // İzin reddedilmiş, token almaya gerek yok
        if (kDebugMode) debugPrint('FCM: İzin reddedilmiş, token alınmadı');
        return;
      }

      // İzin verilmiş veya provisional, token alabiliriz
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token, _appVersion, _appBuild);
    } catch (e) {
      if (kDebugMode) debugPrint('FCM token alınamadı: $e');
    }
  }

  Future<void> _registerToken(String token, String? appVersion, int? appBuild) async {
    try {
      _currentToken = token;
      final HttpsCallable fn = FirebaseFunctions.instance.httpsCallable('notifications-registerFcmToken');
      final platform = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other');
      final lang = Intl.getCurrentLocale();
      await fn.call({
        'token': token,
        'platform': platform,
        'lang': lang,
        if (appVersion != null) 'appVersion': appVersion,
        if (appBuild != null) 'appBuild': appBuild,
      });
      if (kDebugMode) debugPrint('FCM token başarıyla kaydedildi');
    } catch (e) {
      if (kDebugMode) debugPrint('Token kaydı başarısız: $e');
    }
  }

  /// Kullanıcı çıkış yaptığında çağrılmalı - eski hesabın token'ını temizler
  Future<void> clearTokenOnLogout() async {
    try {
      if (_currentToken != null) {
        final HttpsCallable fn = FirebaseFunctions.instance.httpsCallable('notifications-unregisterFcmToken');
        await fn.call({
          'token': _currentToken,
        });
        if (kDebugMode) debugPrint('FCM token temizlendi: $_currentToken');
        _currentToken = null;
      }

      // Çift bildirim önleme cache'ini de temizle
      _recent.clear();

      // Firebase Messaging token'ını sil
      await FirebaseMessaging.instance.deleteToken();

      if (kDebugMode) debugPrint('Çıkış işlemi tamamlandı - tüm bildirim verileri temizlendi');
    } catch (e) {
      if (kDebugMode) debugPrint('Token temizleme hatası: $e');
    }
  }

  /// Yeni hesap girişinde çağrılmalı - yeni token'ı kaydeder
  Future<void> refreshTokenOnLogin() async {
    try {
      // Eski cache'i temizle
      _recent.clear();

      // Yeni token al ve kaydet
      await _ensureAndRegisterToken();

      if (kDebugMode) debugPrint('Yeni giriş için token yenilendi');
    } catch (e) {
      if (kDebugMode) debugPrint('Token yenileme hatası: $e');
    }
  }

  /// Bildirim izni verildikten sonra çağrılmalı - token'ı kaydeder
  /// NotificationPermissionScreen'den çağrılır
  Future<void> registerTokenAfterPermissionGranted() async {
    try {
      // İzin verildi, şimdi token alabiliriz
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _registerToken(token, _appVersion, _appBuild);
        if (kDebugMode) debugPrint('İzin sonrası FCM token kaydedildi');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('İzin sonrası token kaydı hatası: $e');
    }
  }

  Future<String?> _downloadToTemp(String url) async {
    try {
      final uri = Uri.parse(url);
      final httpClient = HttpClient();
      final req = await httpClient.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode != 200) return null;
      final bytes = await consolidateHttpClientResponseBytes(resp);
      final ext = uri.path.split('.').last.toLowerCase();
      final file = File('${Directory.systemTemp.path}/bilge_push_${DateTime.now().millisecondsSinceEpoch}.${ext.isEmpty ? 'img' : ext}');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      if (kDebugMode) debugPrint('Resim indirilemedi: $e');
      return null;
    }
  }

  Future<void> _showLocal(RemoteMessage msg) async {
    final title = msg.notification?.title ?? msg.data['title'] as String? ?? '';
    final body = msg.notification?.body ?? msg.data['body'] as String? ?? '';
    final route = msg.data['route'] as String? ?? '';

    // Dedup: kısa süre içinde aynı mesajı tekrar gösterme
    if (_isDuplicate(msg, title: title, body: body, route: route)) {
      return;
    }

    // imageUrl hem data'da hem de platform spesifik alanlarda olabilir
    final dataImage = msg.data['imageUrl'] as String?;
    final notifAndroidImage = msg.notification?.android?.imageUrl;
    final notifAppleImage = msg.notification?.apple?.imageUrl;
    final imageUrl = dataImage?.isNotEmpty == true
        ? dataImage!
        : (notifAndroidImage?.isNotEmpty == true
        ? notifAndroidImage!
        : (notifAppleImage?.isNotEmpty == true ? notifAppleImage! : ''));

    AndroidNotificationDetails androidDetails;
    DarwinNotificationDetails iosDetails;

    if (imageUrl.isNotEmpty) {
      final localPath = await _downloadToTemp(imageUrl);
      if (localPath != null) {
        final bigPicture = FilePathAndroidBitmap(localPath);
        final thumbIcon = FilePathAndroidBitmap(localPath);
        final style = BigPictureStyleInformation(
          bigPicture,
          // Dar görünümde küçük bir görsel ipucu verelim
          largeIcon: thumbIcon,
          hideExpandedLargeIcon: true,
          contentTitle: title,
          summaryText: body,
        );
        androidDetails = AndroidNotificationDetails(
          _channel?.id ?? 'bilge_general',
          _channel?.name ?? 'Taktik Tavşan Genel',
          channelDescription: _channel?.description,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: style,
          // Dar görünümde de küçük görsel gözüksün
          largeIcon: thumbIcon,
          subText: 'Görsel içerir',
        );
        iosDetails = DarwinNotificationDetails(
          attachments: [
            DarwinNotificationAttachment(localPath),
          ],
        );
      } else {
        // Görsel indirilemezse normal metin bildirimi göster
        androidDetails = AndroidNotificationDetails(
          _channel?.id ?? 'bilge_general',
          _channel?.name ?? 'Taktik Tavşan Genel',
          channelDescription: _channel?.description,
          importance: Importance.high,
          priority: Priority.high,
        );
        iosDetails = const DarwinNotificationDetails();
      }
    } else {
      androidDetails = AndroidNotificationDetails(
        _channel?.id ?? 'taktik_general',
        _channel?.name ?? 'Taktik Tavşan Genel',
        channelDescription: _channel?.description,
        importance: Importance.high,
        priority: Priority.high,
      );
      iosDetails = const DarwinNotificationDetails();
    }

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _fln.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
      payload: route,
    );
  }

  // Basit yerel bildirim (route opsiyonel). Pomodoro gibi dahili olaylarda kullanılır.
  Future<void> showLocalSimple({required String title, required String body, String? route}) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _channel?.id ?? 'bilge_general',
        _channel?.name ?? 'Taktik Tavşan Genel',
        channelDescription: _channel?.description,
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
      await _fln.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        details,
        payload: route ?? '',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Yerel bildirim gösterilemedi: $e');
    }
  }
}