// lib/data/models/blocked_user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Engellenmiş kullanıcı modeli
class BlockedUserModel {
  final String id; // Engellenen kullanıcının ID'si
  final String blockedBy; // Engelleyen kullanıcının ID'si
  final Timestamp blockedAt; // Engellenme zamanı
  final String? reason; // Opsiyonel: Engelleme nedeni

  BlockedUserModel({
    required this.id,
    required this.blockedBy,
    required this.blockedAt,
    this.reason,
  });

  factory BlockedUserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BlockedUserModel(
      id: doc.id,
      blockedBy: data['blockedBy'] as String? ?? '',
      blockedAt: data['blockedAt'] as Timestamp? ?? Timestamp.now(),
      reason: data['reason'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'blockedBy': blockedBy,
      'blockedAt': blockedAt,
      if (reason != null) 'reason': reason,
    };
  }

  BlockedUserModel copyWith({
    String? id,
    String? blockedBy,
    Timestamp? blockedAt,
    String? reason,
  }) {
    return BlockedUserModel(
      id: id ?? this.id,
      blockedBy: blockedBy ?? this.blockedBy,
      blockedAt: blockedAt ?? this.blockedAt,
      reason: reason ?? this.reason,
    );
  }
}

