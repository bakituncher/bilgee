// lib/data/repositories/moderation_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:taktik/data/models/blocked_user_model.dart';
import 'package:taktik/data/models/user_report_model.dart';

/// Kullanıcı engelleme ve raporlama servisi
class ModerationService {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  ModerationService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
        _auth = auth ?? FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Kullanıcıyı engelle
  Future<void> blockUser(String targetUserId, {String? reason}) async {
    if (_currentUserId == null) {
      throw Exception('Kullanıcı giriş yapmamış');
    }

    try {
      final callable = _functions.httpsCallable('moderation-blockUser');
      final result = await callable.call<Map<String, dynamic>>({
        'targetUserId': targetUserId,
        'reason': reason,
      });

      if (kDebugMode) {
        debugPrint('[ModerationService] Block successful: ${result.data}');
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('[ModerationService] Block error: ${e.code} - ${e.message}');
      }
      throw _handleFunctionsError(e);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ModerationService] Unexpected error: $e');
      }
      rethrow;
    }
  }

  /// Kullanıcı engelini kaldır
  Future<void> unblockUser(String targetUserId) async {
    if (_currentUserId == null) {
      throw Exception('Kullanıcı giriş yapmamış');
    }

    try {
      final callable = _functions.httpsCallable('moderation-unblockUser');
      final result = await callable.call<Map<String, dynamic>>({
        'targetUserId': targetUserId,
      });

      if (kDebugMode) {
        debugPrint('[ModerationService] Unblock successful: ${result.data}');
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('[ModerationService] Unblock error: ${e.code} - ${e.message}');
      }
      throw _handleFunctionsError(e);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ModerationService] Unexpected error: $e');
      }
      rethrow;
    }
  }

  /// Kullanıcıyı raporla
  Future<void> reportUser({
    required String targetUserId,
    required UserReportReason reason,
    String? details,
  }) async {
    if (_currentUserId == null) {
      throw Exception('Kullanıcı giriş yapmamış');
    }

    try {
      final callable = _functions.httpsCallable('moderation-reportUser');

      // Timeout ekle - 30 saniye
      final result = await callable.call<Map<String, dynamic>>({
        'reportedUserId': targetUserId,
        'reason': reason.value,
        'details': details,
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('İstek zaman aşımına uğradı. Lütfen tekrar deneyin.');
        },
      );

      if (kDebugMode) {
        debugPrint('[ModerationService] Report successful: ${result.data}');
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('[ModerationService] Report error: ${e.code} - ${e.message}');
        debugPrint('[ModerationService] Report error details: ${e.details}');
      }
      throw _handleFunctionsError(e);
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        debugPrint('[ModerationService] Timeout error: $e');
      }
      throw Exception('İstek zaman aşımına uğradı. Lütfen tekrar deneyin.');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ModerationService] Unexpected error: $e');
        debugPrint('[ModerationService] Error type: ${e.runtimeType}');
      }
      // Genel hata mesajı yerine daha spesifik hata ver
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Raporlama sırasında beklenmeyen bir hata oluştu: $e');
    }
  }

  /// Engellenen kullanıcıları dinle (Stream)
  Stream<List<BlockedUserModel>> streamBlockedUsers() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('blocked_users')
        .orderBy('blockedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BlockedUserModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Engellenen kullanıcıları getir (bir kere)
  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    if (_currentUserId == null) {
      throw Exception('Kullanıcı giriş yapmamış');
    }

    try {
      final callable = _functions.httpsCallable('moderation-getBlockedUsers');

      // Timeout ekle - 30 saniye
      final result = await callable.call<Map<String, dynamic>>().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('İstek zaman aşımına uğradı. Lütfen tekrar deneyin.');
        },
      );

      if (kDebugMode) {
        debugPrint('[ModerationService] getBlockedUsers result: ${result.data}');
      }

      final data = result.data;
      if (data != null && data['success'] == true) {
        final blockedUsers = data['blockedUsers'] as List<dynamic>?;
        if (blockedUsers != null) {
          return blockedUsers.map((user) {
            if (user is Map<String, dynamic>) {
              return user;
            } else if (user is Map) {
              return Map<String, dynamic>.from(user);
            }
            return <String, dynamic>{};
          }).toList();
        }
      }

      return [];
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('[ModerationService] Get blocked users error: ${e.code} - ${e.message}');
      }
      throw _handleFunctionsError(e);
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        debugPrint('[ModerationService] Timeout error: $e');
      }
      throw Exception('İstek zaman aşımına uğradı. Lütfen tekrar deneyin.');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ModerationService] Unexpected error: $e');
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Engellenen kullanıcılar alınırken hata oluştu: $e');
    }
  }

  /// Kullanıcının engellenip engellenmediğini kontrol et
  Future<BlockStatus> checkIfBlocked(String targetUserId) async {
    if (_currentUserId == null) {
      return BlockStatus(
        isBlockedByMe: false,
        isBlockingMe: false,
        isBlocked: false,
      );
    }

    try {
      final callable = _functions.httpsCallable('moderation-checkIfBlocked');
      final result = await callable.call<Map<String, dynamic>>({
        'targetUserId': targetUserId,
      });

      final data = result.data;
      if (data != null && data['success'] == true) {
        return BlockStatus(
          isBlockedByMe: data['isBlockedByMe'] as bool? ?? false,
          isBlockingMe: data['isBlockingMe'] as bool? ?? false,
          isBlocked: data['isBlocked'] as bool? ?? false,
        );
      }

      return BlockStatus(
        isBlockedByMe: false,
        isBlockingMe: false,
        isBlocked: false,
      );
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('[ModerationService] Check block error: ${e.code} - ${e.message}');
      }
      // Hata durumunda güvenli varsayım
      return BlockStatus(
        isBlockedByMe: false,
        isBlockingMe: false,
        isBlocked: false,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ModerationService] Unexpected error: $e');
      }
      return BlockStatus(
        isBlockedByMe: false,
        isBlockingMe: false,
        isBlocked: false,
      );
    }
  }

  /// Belirli bir kullanıcının engellenip engellenmediğini cache ile kontrol et
  /// (Performans için, UI'da çok sayıda kullanıcı listeleniyorsa)
  Future<bool> isUserBlocked(String targetUserId) async {
    if (_currentUserId == null) return false;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('blocked_users')
          .doc(targetUserId)
          .get();

      return doc.exists;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ModerationService] Error checking if user blocked: $e');
      }
      return false;
    }
  }

  /// Engellenen kullanıcıları filtrele (kullanıcı listelerinde)
  Future<List<T>> filterBlockedUsers<T>(
    List<T> users,
    String Function(T) getUserId,
  ) async {
    if (_currentUserId == null || users.isEmpty) return users;

    try {
      // Tüm engellenen kullanıcıları bir kerede al
      final blockedSnapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('blocked_users')
          .get();

      final blockedIds = blockedSnapshot.docs.map((doc) => doc.id).toSet();

      // Engellenen kullanıcıları filtrele
      return users.where((user) => !blockedIds.contains(getUserId(user))).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ModerationService] Error filtering blocked users: $e');
      }
      // Hata durumunda orijinal listeyi döndür
      return users;
    }
  }

  /// Firebase Functions hata işleyicisi
  Exception _handleFunctionsError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return Exception('Lütfen giriş yapın');
      case 'permission-denied':
        return Exception('Bu işlem için yetkiniz yok');
      case 'invalid-argument':
        return Exception(e.message ?? 'Geçersiz parametre');
      case 'not-found':
        return Exception('Kullanıcı bulunamadı');
      case 'already-exists':
        return Exception(e.message ?? 'İşlem zaten yapılmış');
      case 'resource-exhausted':
        return Exception(e.message ?? 'Çok fazla istek. Lütfen bekleyin');
      case 'failed-precondition':
        return Exception(e.message ?? 'İşlem gerçekleştirilemedi');
      case 'internal':
        return Exception('Sunucu hatası. Lütfen tekrar deneyin');
      default:
        return Exception(e.message ?? 'Bilinmeyen hata oluştu');
    }
  }
}

/// Engelleme durumu
class BlockStatus {
  final bool isBlockedByMe; // Ben engelledim mi?
  final bool isBlockingMe; // O beni engelledi mi?
  final bool isBlocked; // Herhangi bir yönde engel var mı?

  BlockStatus({
    required this.isBlockedByMe,
    required this.isBlockingMe,
    required this.isBlocked,
  });

  @override
  String toString() {
    return 'BlockStatus(isBlockedByMe: $isBlockedByMe, isBlockingMe: $isBlockingMe, isBlocked: $isBlocked)';
  }
}

