import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taktik/shared/notifications/notification_service.dart';

class NotificationPermissionScreen extends ConsumerStatefulWidget {
  const NotificationPermissionScreen({super.key});

  @override
  ConsumerState<NotificationPermissionScreen> createState() => _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState extends ConsumerState<NotificationPermissionScreen> {
  bool _isLoading = false;
  static const String _prefKey = 'notification_permission_asked';

  Future<void> _markPermissionAsked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, true);
    } catch (e) {
      if (kDebugMode) debugPrint('SharedPreferences hatası: $e');
    }
  }

  // Çarpıya basınca çalışacak fonksiyon (İzin istemeden geç)
  Future<void> _skipPermission() async {
    await _markPermissionAsked();
    if (mounted) {
      context.go('/');
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {

      // Bildirim iznini iste
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        debugPrint('Bildirim izin durumu: ${settings.authorizationStatus}');
      }

      // Android 13+ için ek izin kontrolü
      if (Platform.isAndroid) {
        final status = await ph.Permission.notification.status;
        if (!status.isGranted) {
          await ph.Permission.notification.request();
        }
      }

      // İzin verildiyse FCM token'ı kaydet
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await NotificationService.instance.registerTokenAfterPermissionGranted();
      }

      // İzni sorduğumuzu kaydet
      await _markPermissionAsked();

      // İzin verilsin veya verilmesin, kullanıcıyı ana ekrana yönlendir
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Bildirim izni hatası: $e');

      // Hata durumunda bile devam et ve kaydet
      await _markPermissionAsked();

      if (mounted) {
        context.go('/');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // --- EKLEME BAŞLANGICI ---
              // Sağ üst köşeye, çok belli olmayan (silik) kapatma butonu
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: IconButton(
                    onPressed: _isLoading ? null : _skipPermission,
                    icon: const Icon(Icons.close_rounded),
                    // Rengi temanın yüzey rengine uyumlu ama çok şeffaf (0.3) yapıyoruz
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                    iconSize: 26, // Standarttan bir tık büyük ama ince durabilir
                    splashRadius: 20,
                  ),
                ),
              ).animate().fadeIn(delay: 1000.ms), // Kullanıcı önce içeriği görsün, buton sonra belirsin
              // --- EKLEME BİTİŞİ ---

              const Spacer(flex: 1),

              // Lottie Animasyonu
              SizedBox(
                height: screenHeight * 0.35,
                child: Lottie.asset(
                  'assets/lotties/Notification Bell.json',
                  fit: BoxFit.contain,
                ),
              ).animate().fadeIn(duration: 600.ms).scale(delay: 200.ms),

              const SizedBox(height: 32),

              // Başlık
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Bildirimlerle Haberdar Ol!',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 16),

              // Açıklama Metni
              Text(
                'Sana özel hatırlatmalar, motivasyon mesajları ve önemli güncellemeleri kaçırma! '
                    'Taktik Tavşan olarak seni bilgilendirmek ve hedeflerine ulaşmanda destek olmak için '
                    'bildirimlere izin verebilirsin.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),

              const Spacer(flex: 2),

              // İzin Ver Butonu
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isLoading ? null : _requestNotificationPermission,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: colorScheme.onPrimary,
                    ),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_active_rounded, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Bildirimlere İzin Ver',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3, end: 0),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}