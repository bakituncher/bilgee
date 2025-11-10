// lib/data/providers/moderation_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/models/blocked_user_model.dart';
import 'package:taktik/data/repositories/moderation_service.dart';

/// ModerationService provider
final moderationServiceProvider = Provider<ModerationService>((ref) {
  return ModerationService();
});

/// Engellenen kullanıcıları dinle (Stream)
final blockedUsersStreamProvider = StreamProvider.autoDispose<List<BlockedUserModel>>((ref) {
  final service = ref.watch(moderationServiceProvider);
  return service.streamBlockedUsers();
});

/// Engellenen kullanıcıları getir (Future - detaylı bilgilerle)
final blockedUsersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(moderationServiceProvider);
  return service.getBlockedUsers();
});

/// Belirli bir kullanıcının engel durumunu kontrol et
final blockStatusProvider = FutureProvider.autoDispose.family<BlockStatus, String>((ref, userId) async {
  final service = ref.watch(moderationServiceProvider);
  return service.checkIfBlocked(userId);
});

/// Kullanıcının engellenip engellenmediğini hızlı kontrol et (cache)
final isUserBlockedProvider = FutureProvider.autoDispose.family<bool, String>((ref, userId) async {
  final service = ref.watch(moderationServiceProvider);
  return service.isUserBlocked(userId);
});

