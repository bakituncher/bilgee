// lib/data/providers/admin_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:taktik/features/auth/application/auth_controller.dart'; // Add this import

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final adminClaimProvider = FutureProvider<bool>((ref) async {
  // Depend on the auth state stream provider
  final user = ref.watch(authControllerProvider).value;

  if (user == null) {
    // If there is no user, they are not an admin.
    return false;
  }

  // Force a refresh of the token to get the latest claims.
  final tokenResult = await user.getIdTokenResult(true);
  final claims = tokenResult.claims ?? {};

  // Return true if the 'admin' claim is set to true.
  return claims['admin'] == true;
});

