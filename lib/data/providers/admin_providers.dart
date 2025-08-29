// lib/data/providers/admin_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final adminClaimProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return false;
  final token = await user.getIdTokenResult(true);
  final claims = token.claims ?? {};
  return claims['admin'] == true;
});

