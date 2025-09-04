import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:package_info_plus/package_info_plus.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  AndroidNotificationChannel? _channel;
  void Function(String route)? _navigate;

  // Son gösterilenleri kısa süreliğine tut (2 dk) – çift bildirimi engelle
  final Map<String, DateTime> _recent = {};
  bool _isDuplicate(RemoteMessage msg, {required String title, required String body, required String route}) {
    try {
      final now = DateTime.now();
      // Eski kayıtları temizle
      _recent.removeWhere((key, ts) => now.difference(ts).inSeconds > 120);
      String key = msg.messageId ?? msg.data['campaignId'] as String? ?? '';
      if (key.isEmpty) key = '${title}|${body}|${route}';
      if (_recent.containsKey(key)) return true;
      _recent[key] = now;
      return false;
    } catch (_) {
      return false;
    }
  }

  String? _appVersion;
  int? _appBuild;

  Future<void> initialize({required void Function(String route) onNavigate}) async {
    if (_initialized) return;
    _navigate = onNavigate;

    // Uygulama sürüm bilgisi
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
      _appBuild = int.tryParse(info.buildNumber);
    } catch (_) {}

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
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
      'BilgeAI Genel',
      description: 'Genel bildirimler',
      importance: Importance.high,
    );
    await _fln
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel!);

    // Android 13+ bildirim izni – areNotificationsEnabled ile kontrol ve gerekirse iste
    try {
      final androidFln = _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await androidFln?.areNotificationsEnabled() ?? true;
      if (!enabled && Platform.isAndroid) {
        final status = await ph.Permission.notification.status;
        if (!status.isGranted) {
          await ph.Permission.notification.request();
        }
      }
    } catch (_) {}

    // iOS foreground sunum ayarları
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false);

    await _requestPermission();

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

  Future<void> _requestPermission() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    } catch (_) {}
  }

  Future<void> _ensureAndRegisterToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token, _appVersion, _appBuild);
    } catch (e) {
      if (kDebugMode) debugPrint('FCM token alınamadı: $e');
    }
  }

  Future<void> _registerToken(String token, String? appVersion, int? appBuild) async {
    try {
      final HttpsCallable fn = FirebaseFunctions.instance.httpsCallable('registerFcmToken');
      final platform = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other');
      final lang = Intl.getCurrentLocale();
      await fn.call({
        'token': token,
        'platform': platform,
        'lang': lang,
        if (appVersion != null) 'appVersion': appVersion,
        if (appBuild != null) 'appBuild': appBuild,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Token kaydı başarısız: $e');
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
          _channel?.name ?? 'BilgeAI Genel',
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
          _channel?.name ?? 'BilgeAI Genel',
          channelDescription: _channel?.description,
          importance: Importance.high,
          priority: Priority.high,
        );
        iosDetails = const DarwinNotificationDetails();
      }
    } else {
      androidDetails = AndroidNotificationDetails(
        _channel?.id ?? 'bilge_general',
        _channel?.name ?? 'BilgeAI Genel',
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
}
