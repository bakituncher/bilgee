// lib/features/auth/application/auth_controller.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:purchases_flutter/purchases_flutter.dart'; // RevenueCat SDK
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/data/auth_repository.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';
import '../../../shared/notifications/notification_service.dart';

final authControllerProvider = StreamNotifierProvider<AuthController, User?>(() {
  return AuthController();
});

class AuthController extends StreamNotifier<User?> {
  @override
  Stream<User?> build() {
    final authRepository = ref.watch(authRepositoryProvider);
    final authStream = authRepository.authStateChanges;
    // Uygulama her açıldığında veya kullanıcı durumu değiştiğinde tetiklenir.
    final subscription = authStream.listen(_onUserActivity);
    ref.onDispose(() => subscription.cancel());
    return authStream;
  }

  void _onUserActivity(User? user) {
    if (user != null) {
      // RevenueCat'e giriş yaparak app_user_id'yi Firebase uid ile senkronize et
      _logInToRevenueCat(user.uid);

      // Oturum açan kullanıcının admin yetkisini kontrol et ve ayarla.
      // Bu işlem arka planda sessizce yapılır.
      _updateAdminClaim(user);

      // Yeni giriş için bildirim token'ını yenile
      Future.delayed(const Duration(seconds: 1), () async {
        try {
          await NotificationService.instance.refreshTokenOnLogin();
        } catch (e) {
          print("Bildirim token yenileme hatası (güvenli): $e");
        }
      });

      // --- ZİYARET KAYDI: user_activity aylık dokümanına yaz ---
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          if (state.hasValue) {
            final firestoreService = ref.read(firestoreServiceProvider);
            await firestoreService.recordUserVisit(user.uid);
            // Görev ilerlemesini tetikle (aksiyon bazlı)
            ref.read(questNotifierProvider.notifier).userLoggedInOrOpenedApp();
          }
        } catch (e) {
          print("Quest update on auth change failed (safe to ignore on startup): $e");
        }
      });
      // ------------------------------------
    }
  }

  Future<void> _updateAdminClaim(User user) async {
    try {
      // DÜZELTME: Fonksiyon adı yanlıştı ('setSelfAdmin').
      // index.js içinde exports.admin = admin; olduğu için gerçek callable adı 'admin-setSelfAdmin'.
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('admin-setSelfAdmin');
      await callable.call();
      await user.getIdTokenResult(true); // claimleri yenile
      print('Admin claim updated successfully.');
    } catch (e) {
      print('Failed to update admin claim: $e');
    }
  }


  Future<void> signIn({required String email, required String password}) {
    final authRepository = ref.read(authRepositoryProvider);
    return authRepository.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUp({
    required String firstName,
    required String lastName,
    required String username,
    String? gender,
    DateTime? dateOfBirth,
    required String email,
    required String password,
  }) {
    final authRepository = ref.read(authRepositoryProvider);
    return authRepository.signUpWithEmailAndPassword(
      firstName: firstName,
      lastName: lastName,
      username: username,
      gender: gender,
      dateOfBirth: dateOfBirth,
      email: email,
      password: password,
    );
  }

  Future<void> _logInToRevenueCat(String uid) async {
    try {
      await Purchases.logIn(uid);
    } catch (e) {
      print("RevenueCat login error (safe to ignore): $e");
    }
  }

  Future<void> _logOutFromRevenueCat() async {
    try {
      await Purchases.logOut();
    } catch (e) {
      print("RevenueCat logout error (safe to ignore): $e");
    }
  }

  Future<void> signOut() async {
    await _logOutFromRevenueCat();
    final authRepository = ref.read(authRepositoryProvider);
    await authRepository.signOut();
  }

  Future<void> updatePassword({required String currentPassword, required String newPassword}) {
    final authRepository = ref.read(authRepositoryProvider);
    return authRepository.updatePassword(currentPassword: currentPassword, newPassword: newPassword);
  }

  Future<void> resetPassword(String email) {
    final authRepository = ref.read(authRepositoryProvider);
    return authRepository.resetPassword(email);
  }

  Future<void> signInWithGoogle() async {
    // Google sign-in'den önce mevcut RevenueCat kullanıcısını temizle
    await _logOutFromRevenueCat();
    final authRepository = ref.read(authRepositoryProvider);
    await authRepository.signInWithGoogle();
  }
}