// lib/features/mind_map/models/saved_mind_map_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SavedMindMapModel {
  final String id;
  final String userId;
  final String topic;
  final String subject;
  final Map<String, dynamic> mindMapData; // JSON olarak saklanacak
  final DateTime createdAt;
  final DateTime? updatedAt;

  SavedMindMapModel({
    required this.id,
    required this.userId,
    required this.topic,
    required this.subject,
    required this.mindMapData,
    required this.createdAt,
    this.updatedAt,
  });

  factory SavedMindMapModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SavedMindMapModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      topic: data['topic'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      mindMapData: Map<String, dynamic>.from(data['mindMapData'] as Map? ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'topic': topic,
      'subject': subject,
      'mindMapData': mindMapData,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  SavedMindMapModel copyWith({
    String? id,
    String? userId,
    String? topic,
    String? subject,
    Map<String, dynamic>? mindMapData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedMindMapModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      topic: topic ?? this.topic,
      subject: subject ?? this.subject,
      mindMapData: mindMapData ?? this.mindMapData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

