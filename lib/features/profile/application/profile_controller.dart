import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';

final profileControllerProvider = StateNotifierProvider<ProfileController, AsyncValue<void>>((ref) {
  return ProfileController(ref);
});

class ProfileController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ProfileController(this._ref) : super(const AsyncValue.data(null));

  Future<void> updateUserProfile({
    required String firstName,
    required String lastName,
    required String? gender,
    required DateTime? dateOfBirth,
  }) async {
    state = const AsyncValue.loading();
    try {
      final userId = _ref.read(authControllerProvider).value?.uid;
      if (userId == null) {
        throw Exception("User not logged in");
      }
      final firestoreService = _ref.read(firestoreServiceProvider);

      final Map<String, dynamic> dataToUpdate = {
        'firstName': firstName,
        'lastName': lastName,
        'gender': gender,
        'dateOfBirth': dateOfBirth,
      };

      await firestoreService.updateUserProfile(userId, dataToUpdate);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
