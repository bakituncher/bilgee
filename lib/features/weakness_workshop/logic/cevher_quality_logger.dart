// lib/features/weakness_workshop/logic/cevher_quality_logger.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/features/weakness_workshop/models/study_guide_model.dart';
import 'package:taktik/features/weakness_workshop/logic/quiz_quality_guard.dart';

/// Logger for Cevher Atölyesi quality metrics and validation results
/// This helps monitor the effectiveness of AI model upgrades and quality controls
class CevherQualityLogger {
  final FirebaseFirestore _firestore;

  CevherQualityLogger(this._firestore);

  /// Log quality metrics for a generated workshop session
  Future<void> logWorkshopQuality({
    required String userId,
    required String subject,
    required String topic,
    required QuizQualityGuardResult guardResult,
    required String difficulty,
    required int attemptCount,
  }) async {
    try {
      final logData = {
        'userId': userId,
        'subject': subject,
        'topic': topic,
        'difficulty': difficulty,
        'attemptCount': attemptCount,
        'timestamp': FieldValue.serverTimestamp(),
        'modelVersion': 'gemini-2.5-flash', // Upgraded model for Cevher Atölyesi
        'qualityMetrics': guardResult.qualityMetrics,
        'issuesDetected': guardResult.issues,
        'questionsGenerated': guardResult.material.quiz.length,
        'validationPassed': true, // Only successful ones are logged
      };

      // Store in a dedicated collection for monitoring
      await _firestore
          .collection('cevher_quality_logs')
          .add(logData);

      // Also update user-specific stats
      final userStatsRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('cevher_stats')
          .doc('quality_summary');

      await userStatsRef.set({
        'totalWorkshops': FieldValue.increment(1),
        'totalQuestionsGenerated': FieldValue.increment(guardResult.material.quiz.length),
        'lastWorkshopDate': FieldValue.serverTimestamp(),
        'avgQualityScore': guardResult.qualityMetrics['averageQualityScore'],
      }, SetOptions(merge: true));
    } catch (e) {
      // Non-blocking: log errors but don't fail the main flow
      print('Failed to log Cevher quality metrics: $e');
    }
  }

  /// Log validation failures for analysis and improvement
  Future<void> logValidationFailure({
    required String userId,
    required String subject,
    required String topic,
    required String difficulty,
    required List<String> issues,
    required int attemptNumber,
  }) async {
    try {
      final failureData = {
        'userId': userId,
        'subject': subject,
        'topic': topic,
        'difficulty': difficulty,
        'attemptNumber': attemptNumber,
        'timestamp': FieldValue.serverTimestamp(),
        'modelVersion': 'gemini-2.5-flash',
        'issues': issues,
        'validationPassed': false,
      };

      await _firestore
          .collection('cevher_validation_failures')
          .add(failureData);
    } catch (e) {
      print('Failed to log validation failure: $e');
    }
  }

  /// Get quality statistics for monitoring dashboard
  static Future<Map<String, dynamic>> getQualityStats(
    FirebaseFirestore firestore,
    String userId,
  ) async {
    try {
      final statsDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('cevher_stats')
          .doc('quality_summary')
          .get();

      if (statsDoc.exists) {
        return statsDoc.data() ?? {};
      }
      return {};
    } catch (e) {
      print('Failed to fetch quality stats: $e');
      return {};
    }
  }
}
