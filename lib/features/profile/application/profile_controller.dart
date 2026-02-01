import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';

final profileControllerProvider = StateNotifierProvider<ProfileController, AsyncValue<void>>((ref) {
  return ProfileController(ref);
});

class ProfileController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ProfileController(this._ref) : super(const AsyncValue.data(null));

  /// Kullanıcı adının müsait olup olmadığını kontrol et
  Future<bool> checkUsernameAvailability(String username) async {
    try {
      final userId = _ref.read(authControllerProvider).value?.uid;
      if (userId == null) return false;

      final firestoreService = _ref.read(firestoreServiceProvider);
      return await firestoreService.checkUsernameAvailability(
        username,
        excludeUserId: userId,
      );
    } catch (e) {
      return false;
    }
  }

  Future<void> updateUserProfile({
    required String firstName,
    required String lastName,
    required String? gender,
    required DateTime? dateOfBirth,
    String? username,
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

      if (username != null && username.isNotEmpty) {
        dataToUpdate['username'] = username;
      }

      await firestoreService.updateUserProfile(userId, dataToUpdate);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
