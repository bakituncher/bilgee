import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final analyticsLoggerProvider = Provider<AnalyticsLogger>((ref) => AnalyticsLogger(FirebaseFirestore.instance));

class AnalyticsLogger {
  final FirebaseFirestore _firestore;
  AnalyticsLogger(this._firestore);

  Future<void> logQuestEvent({required String userId, required String event, required Map<String,dynamic> data}) async {
    try {
      await _firestore.collection('analytics_events').add({
        // Firestore rules ile uyumlu alanlar
        'type': event, // event adı -> type
        'ts': FieldValue.serverTimestamp(), // timestamp
        'meta': {
          'userId': userId,
          'payload': data,
          'v': 1,
        },
      });
    } catch (_){/* sessiz geç */}
  }
}
