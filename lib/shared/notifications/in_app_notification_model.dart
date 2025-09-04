// lib/shared/notifications/in_app_notification_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class InAppNotification {
  final String id;
  final String title;
  final String body;
  final String route;
  final String? imageUrl;
  final bool read;
  final Timestamp? createdAt;
  final Timestamp? readAt;
  final String? type;
  final String? campaignId;

  InAppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.route,
    this.imageUrl,
    required this.read,
    this.createdAt,
    this.readAt,
    this.type,
    this.campaignId,
  });

  factory InAppNotification.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return InAppNotification(
      id: doc.id,
      title: (d['title'] ?? '').toString(),
      body: (d['body'] ?? '').toString(),
      route: (d['route'] ?? '/home').toString(),
      imageUrl: (d['imageUrl'] as String?)?.isNotEmpty == true ? d['imageUrl'] as String : null,
      read: (d['read'] as bool?) ?? false,
      createdAt: d['createdAt'] as Timestamp?,
      readAt: d['readAt'] as Timestamp?,
      type: d['type'] as String?,
      campaignId: d['campaignId'] as String?,
    );
  }
}
