import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> _requestNotificationPermission() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // iOS için önce App Tracking Transparency (ATT) iznini iste
      if (Platform.isIOS) {
        try {
          final trackingStatus = await AppTrackingTransparency.trackingAuthorizationStatus;

          if (trackingStatus == TrackingStatus.notDetermined) {
            await Future.delayed(const Duration(milliseconds: 500));
            final newStatus = await AppTrackingTransparency.requestTrackingAuthorization();

            if (kDebugMode) {
              debugPrint('ATT izin durumu: $newStatus');
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('ATT izin talebi hatası: $e');
        }
      }

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

  void _skipPermission() async {
    if (_isLoading) return;

    // Atladığını kaydet
    await _markPermissionAsked();

    // Kullanıcı şimdilik atlamak isterse direkt ana ekrana git
    if (mounted) {
      context.go('/');
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

              const SizedBox(height: 12),

              // Şimdilik Atla Butonu
              TextButton(
                onPressed: _isLoading ? null : _skipPermission,
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                child: Text(
                  'Şimdilik Atla',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ).animate().fadeIn(delay: 600.ms),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

