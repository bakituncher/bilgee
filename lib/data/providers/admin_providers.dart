// lib/data/providers/admin_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
// cloud_firestore kütüphanesini kaldırdık çünkü artık doğrudan okuma yapmıyoruz.
import 'package:taktik/features/auth/application/auth_controller.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final adminClaimProvider = FutureProvider<bool>((ref) async {
  // Depend on the auth state stream provider
  final user = ref.watch(authControllerProvider).value;

  if (user == null) {
    // If there is no user, they are not an admin.
    return false;
  }

  try {
    // Force a refresh of the token to get the latest claims.
    final tokenResult = await user.getIdTokenResult(true);
    final claims = tokenResult.claims ?? {};

    // Return true if the 'admin' claim is set to true.
    return claims['admin'] == true;
  } on FirebaseAuthException catch (e) {
    // Network errors or unexpected stream end - return false safely
    print('Error getting admin claim: ${e.code} ${e.message}');
    return false;
  } catch (e) {
    // Any other unexpected error - return false safely
    print('Unexpected error getting admin claim: $e');
    return false;
  }
});

final superAdminProvider = FutureProvider<bool>((ref) async {
  // Re-evaluate if the user changes
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return false;

  try {
    final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('admin-isCurrentUserSuperAdmin');
    final result = await callable.call();
    return result.data['isSuperAdmin'] ?? false;
  } on FirebaseFunctionsException catch (e) {
    print('Error checking super admin status: ${e.code} ${e.message}');
    return false;
  } catch (e) {
    print('An unexpected error occurred while checking super admin status: $e');
    return false;
  }
});

/// GÜVENLİ VE PERFORMANSLI VERSİYON
/// İstatistikler sunucu tarafında (Cloud Function) hesaplanıp getirilir.
final userStatisticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    // Cloud Functions örneğini al (Bölge us-central1 olmalı, function'ınla aynı)
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

    // 'admin-getUserStats' fonksiyonunu çağır
    // (functions/src/admin.js dosyasında tanımladığımız isimle aynı olmalı)
    final callable = functions.httpsCallable('admin-getUserStats');

    final result = await callable.call();

    // Gelen veriyi Map formatına çevir
    return Map<String, dynamic>.from(result.data);
  } catch (e) {
    print('Error fetching user statistics via Cloud Function: $e');
    // Hata durumunda UI'da göstermek için hatayı fırlat
    rethrow;
  }
});