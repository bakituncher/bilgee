import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';

final profileControllerProvider = StateNotifierProvider<ProfileController, AsyncValue<void>>((ref) {
  return ProfileController(ref);
});

/// Mevcut kullanıcının engellediği kullanıcı ID'lerinin listesini stream eder.
final blockedUsersProvider = StreamProvider<List<String>>((ref) {
  final authState = ref.watch(authControllerProvider);
  final userId = authState.value?.uid;

  if (userId == null) {
    return Stream.value([]);
  }

  final firestoreService = ref.read(firestoreServiceProvider);
  return firestoreService.usersCollection.doc(userId).snapshots().map((snapshot) {
    if (snapshot.exists && snapshot.data() != null) {
      // UserModel.fromSnapshot'u doğrudan kullanmak yerine,
      // sadece 'blockedUsers' alanını güvenle okuyoruz.
      final data = snapshot.data()!;
      final blocked = data['blockedUsers'];
      if (blocked is List) {
        return List<String>.from(blocked);
      }
    }
    return [];
  });
});


class ProfileController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ProfileController(this._ref) : super(const AsyncValue.data(null));

  Future<bool> blockUser(String userIdToBlock) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(firestoreServiceProvider).blockUser(userIdToBlock);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> unblockUser(String userIdToUnblock) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(firestoreServiceProvider).unblockUser(userIdToUnblock);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> reportUser({required String reportedUserId, required String reason}) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(firestoreServiceProvider).reportUser(reportedUserId: reportedUserId, reason: reason);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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
