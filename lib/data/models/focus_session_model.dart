// lib/data/models/focus_session_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FocusSessionModel {
  final String id;
  final String userId;
  final DateTime date;
  final int durationInSeconds; // Odaklanma süresi (saniye cinsinden)
  final String task; // Üzerinde çalışılan konu veya görev

  FocusSessionModel({
    this.id = '',
    required this.userId,
    required this.date,
    required this.durationInSeconds,
    required this.task,
  });

  factory FocusSessionModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return FocusSessionModel(
      id: doc.id,
      userId: data['userId'],
      date: (data['date'] as Timestamp).toDate(),
      durationInSeconds: data['durationInSeconds'],
      task: data['task'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'durationInSeconds': durationInSeconds,
      'task': task,
    };
  }
}