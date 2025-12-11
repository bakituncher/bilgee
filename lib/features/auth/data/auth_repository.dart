// lib/features/auth/data/auth_repository.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform;
import 'package:taktik/data/repositories/firestore_service.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import '../../../shared/notifications/notification_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    FirebaseAuth.instance,
    ref.watch(firestoreServiceProvider),
    GoogleSignIn(),
  );
});

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirestoreService _firestoreService;
  final GoogleSignIn _googleSignIn;

  AuthRepository(this._firebaseAuth, this._firestoreService, this._googleSignIn);

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

        // Varsayılan Avatar Belirleme
        String defaultStyle = 'bottts';
        if (gender == 'Kadın') {
          defaultStyle = 'avataaars';
        } else if (gender == 'Erkek') {
          defaultStyle = 'avataaars';
        }
        final defaultSeed = username.isNotEmpty ? username : userCredential.user!.uid;

        // Create user profile in Firestore
        await _firestoreService.createUserProfile(
          user: userCredential.user!,
          firstName: firstName,
          lastName: lastName,
          username: username,
          gender: gender,
          dateOfBirth: dateOfBirth,
          profileCompleted: true,
          avatarStyle: defaultStyle,
          avatarSeed: defaultSeed,
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
    // PERFORMANS İYİLEŞTİRMESİ: Bildirim token temizleme işlemini beklemeden
    // (fire-and-forget) arkaplanda çalıştır. Kullanıcının çıkış yapması için
    // sunucu yanıtı beklenmesine gerek yok.
    NotificationService.instance.clearTokenOnLogout().catchError((e) {
      // Bildirim temizleme hatası uygulamayı engellemesin
      if (kDebugMode) debugPrint('Bildirim temizleme hatası (arkaplan): $e');
    });

    // Kullanıcıyı hemen çıkar
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

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // The user canceled the sign-in
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      if (userCredential.user != null) {
        // Check if user is new
        final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
        if (isNewUser) {
          final user = userCredential.user!;
          final nameParts = user.displayName?.split(' ') ?? [''];
          final firstName = nameParts.isNotEmpty ? nameParts.first : '';
          final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
          final generatedUsername = user.email!.split('@').first;

          // Google kullanıcıları için varsayılan avatar
          await _firestoreService.createUserProfile(
            user: user,
            firstName: firstName,
            lastName: lastName,
            username: generatedUsername,
            avatarStyle: 'bottts',
            avatarSeed: generatedUsername,
          );
        }
      }
    } catch (e) {
      // Handle exceptions
      throw 'Google ile giriş yapılamadı. Lütfen tekrar deneyin.';
    }
  }

  /// Generates Nonce
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Returns the sha256 hash of [input] in hex notation.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> signInWithApple() async {
    try {
      UserCredential? userCredential;

      if (kIsWeb) {
        // Web: FirebaseAuth'un AppleAuthProvider ile signInWithProvider kullanımı
        final provider = AppleAuthProvider();
        provider.addScope('email');
        provider.addScope('name');
        userCredential = await _firebaseAuth.signInWithProvider(provider);
      } else if (Platform.isIOS) {
        // --- iOS: Native sign_in_with_apple paketi ile (Native Pencere) ---
        final rawNonce = _generateNonce();
        final nonce = _sha256ofString(rawNonce);

        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: nonce,
        );

        final oauthCredential = OAuthProvider("apple.com").credential(
          idToken: appleCredential.identityToken,
          rawNonce: rawNonce,
          accessToken: appleCredential.authorizationCode,
        );

        userCredential = await _firebaseAuth.signInWithCredential(oauthCredential);

        // iOS'ta yeni kullanıcı ise isim bilgilerini al
        if (userCredential.user != null) {
          final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
          if (isNewUser) {
            final user = userCredential.user!;
            final givenName = appleCredential.givenName ?? '';
            final familyName = appleCredential.familyName ?? '';
            String firstName = givenName;
            String lastName = familyName;
            if (firstName.isEmpty && lastName.isEmpty && user.displayName != null) {
              final nameParts = user.displayName!.split(' ');
              firstName = nameParts.isNotEmpty ? nameParts.first : '';
              lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
            }
            if (firstName.isEmpty && lastName.isEmpty) {
              firstName = 'Apple';
              lastName = 'Kullanıcısı';
            }
            final generatedUsername = user.email?.split('@').first ?? 'apple_${user.uid.substring(0, 8)}';
            await _firestoreService.createUserProfile(
              user: user,
              firstName: firstName,
              lastName: lastName,
              username: generatedUsername,
              avatarStyle: 'bottts',
              avatarSeed: generatedUsername,
            );
          }
        }
      } else {
        // --- ANDROID: Firebase OAuthProvider (State uyuşmazlık sorunu çözüldü) ---
        // Android'de webAuthenticationOptions ile uğraşmak yerine
        // Firebase'in kendi OAuthProvider'ını kullanıyoruz.
        // Bu yöntem, Firebase handler linkini otomatik ve doğru şekilde kullanır.
        final appleProvider = OAuthProvider('apple.com');
        appleProvider.addScope('email');
        appleProvider.addScope('name');

        userCredential = await _firebaseAuth.signInWithProvider(appleProvider);
      }

      // Yeni kullanıcı profili oluşturma (Web ve Android için)
      if (userCredential != null && userCredential.user != null && !Platform.isIOS) {
        final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
        if (isNewUser) {
          final user = userCredential.user!;
          final displayName = user.displayName ?? '';
          String firstName = '';
          String lastName = '';
          if (displayName.isNotEmpty) {
            final nameParts = displayName.split(' ');
            firstName = nameParts.isNotEmpty ? nameParts.first : '';
            lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
          }
          if (firstName.isEmpty && lastName.isEmpty) {
            firstName = 'Apple';
            lastName = 'Kullanıcısı';
          }
          final generatedUsername = user.email?.split('@').first ?? 'apple_${user.uid.substring(0, 8)}';
          await _firestoreService.createUserProfile(
            user: user,
            firstName: firstName,
            lastName: lastName,
            username: generatedUsername,
            avatarStyle: 'bottts',
            avatarSeed: generatedUsername,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('APPLE GİRİŞ HATASI DETAYI: $e');
      }
      final msg = e.toString();
      if (msg.contains('canceled') || msg.contains('popup_closed_by_user')) {
        return;
      }
      throw 'Apple ile giriş yapılamadı. Lütfen tekrar deneyin.';
    }
  }
}