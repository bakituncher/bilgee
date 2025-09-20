// lib/features/auth/data/auth_repository.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/repositories/firestore_service.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    FirebaseAuth.instance,
    ref.watch(firestoreServiceProvider),
  );
});

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirestoreService _firestoreService;

  AuthRepository(this._firebaseAuth, this._firestoreService);

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> signUpWithEmailAndPassword({
    required String firstName,
    required String lastName,
    required String username,
    String? gender,
    DateTime? dateOfBirth,
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        // Send verification email
        await userCredential.user!.sendEmailVerification();

        // Create user profile in Firestore
        await _firestoreService.createUserProfile(
          user: userCredential.user!,
          firstName: firstName,
          lastName: lastName,
          username: username,
          gender: gender,
          dateOfBirth: dateOfBirth,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw 'Girdiğiniz şifre çok zayıf.';
      } else if (e.code == 'email-already-in-use') {
        throw 'Bu e-posta adresi zaten kullanımda.';
      } else {
        throw 'Bir hata oluştu. Lütfen tekrar deneyin.';
      }
    }
  }

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw 'E-posta veya şifre hatalı.';
      } else {
        throw 'Bir hata oluştu. Lütfen tekrar deneyin.';
      }
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw 'Oturum bulunamadı.';
    }
    final email = user.email;
    if (email == null) {
      throw 'E-posta bulunamadı.';
    }
    try {
      final credential = EmailAuthProvider.credential(email: email, password: currentPassword);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw 'Mevcut şifreniz hatalı.';
      } else if (e.code == 'weak-password') {
        throw 'Yeni şifre çok zayıf (en az 6 karakter).';
      } else if (e.code == 'requires-recent-login') {
        throw 'Güvenlik nedeniyle tekrar giriş yapmanız gerekiyor.';
      } else {
        throw 'Şifre güncellenemedi. Lütfen tekrar deneyin.';
      }
    } catch (_) {
      throw 'Şifre güncellenemedi. Lütfen tekrar deneyin.';
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
      } else if (e.code == 'invalid-email') {
        throw 'Geçersiz e-posta adresi.';
      } else if (e.code == 'too-many-requests') {
        throw 'Çok fazla deneme yapıldı. Lütfen sonra tekrar deneyin.';
      } else if (e.code == 'network-request-failed') {
        throw 'Ağ hatası. İnternet bağlantınızı kontrol edin.';
      } else {
        throw 'Şifre sıfırlama e-postası gönderilemedi.';
      }
    } catch (_) {
      throw 'Şifre sıfırlama e-postası gönderilemedi.';
    }
  }
}