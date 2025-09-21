// lib/features/auth/application/auth_controller.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/data/auth_repository.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';

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
      // Oturum açan kullanıcının admin yetkisini kontrol et ve ayarla.
      // Bu işlem arka planda sessizce yapılır.
      _updateAdminClaim(user);

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
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('setSelfAdmin');
      await callable.call();
      // Kullanıcının token'ını yenilemeye zorla, böylece yeni claim'ler alınır.
      await user.getIdTokenResult(true);
      print('Admin claim updated successfully.');
    } catch (e) {
      print('Failed to update admin claim: $e');
      // Hata durumunda kullanıcı deneyimini etkileme.
      // Bu sadece bir yetkilendirme kontrolüdür.
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

  Future<void> signOut() {
    final authRepository = ref.read(authRepositoryProvider);
    return authRepository.signOut();
  }

  Future<void> updatePassword({required String currentPassword, required String newPassword}) {
    final authRepository = ref.read(authRepositoryProvider);
    return authRepository.updatePassword(currentPassword: currentPassword, newPassword: newPassword);
  }

  Future<void> resetPassword(String email) {
    final authRepository = ref.read(authRepositoryProvider);
    return authRepository.resetPassword(email);
  }
}