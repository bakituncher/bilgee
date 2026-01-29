// lib/data/providers/admin_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

