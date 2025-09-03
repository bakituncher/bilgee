import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  AndroidNotificationChannel? _channel;
  void Function(String route)? _navigate;

  Future<void> initialize({required void Function(String route) onNavigate}) async {
    if (_initialized) return;
    _navigate = onNavigate;

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

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    await _requestPermission();

    await _ensureAndRegisterToken();
    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      _registerToken(t);
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
      if (token != null) await _registerToken(token);
    } catch (e) {
      if (kDebugMode) debugPrint('FCM token alınamadı: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      final HttpsCallable fn = FirebaseFunctions.instance.httpsCallable('registerFcmToken');
      final platform = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other');
      final lang = Intl.getCurrentLocale();
      await fn.call({'token': token, 'platform': platform, 'lang': lang});
    } catch (e) {
      if (kDebugMode) debugPrint('Token kaydı başarısız: $e');
    }
  }

  Future<void> _showLocal(RemoteMessage msg) async {
    final title = msg.notification?.title ?? msg.data['title'] as String? ?? '';
    final body = msg.notification?.body ?? msg.data['body'] as String? ?? '';
    final route = msg.data['route'] as String? ?? '';

    final androidDetails = AndroidNotificationDetails(
      _channel?.id ?? 'bilge_general',
      _channel?.name ?? 'BilgeAI Genel',
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
      payload: route,
    );
  }
}
