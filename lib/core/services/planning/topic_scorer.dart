import 'package:taktik/data/models/performance_summary.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/models/exam_model.dart';

class WeightedTopic {
  final String subject;
  final String topic;
  final double score;
  final String status; // 'red', 'yellow', 'green', 'new', 'review'
  final String reason;

  WeightedTopic({
    required this.subject,
    required this.topic,
    required this.score,
    required this.status,
    required this.reason,
  });

  @override
  String toString() => '$subject - $topic ($score) [$status]';
}

class TopicScorer {
  /// Topics with accuracy below this are 'Red'
  static const double redThreshold = 50.0;

  /// Topics with accuracy below this are 'Yellow'
  static const double yellowThreshold = 75.0;

  /// Main method to prioritize topics
  List<WeightedTopic> scoreTopics({
    required Exam examModel,
    required PerformanceSummary performance,
    required List<TestModel> recentTests,
    required String? selectedSection,
  }) {
    final List<WeightedTopic> scoredTopics = [];

    // 1. Identify Weaknesses from Mock Exams (Last 3 tests)
    // Currently relying on general performance accumulation.

    // 2. Iterate Curriculum
    for (var section in examModel.sections) {
      // Filter by selected section if applicable
      if (selectedSection != null && selectedSection.isNotEmpty) {
        bool isRelevant = false;

        // Always include common sections (TYT, AGS, etc.)
        if (section.name == 'TYT' || section.name == 'AGS' || section.name == 'Genel Yetenek - Genel Kültür') {
          isRelevant = true;
        } else if (section.name.toLowerCase() == selectedSection.toLowerCase()) {
          isRelevant = true;
        } else if (selectedSection == 'TYT ve YDT' && (section.name == 'TYT' || section.name == 'YDT')) { // Special case for YDT
             isRelevant = true;
        }

        if (!isRelevant) continue;
      }

      section.subjects.forEach((subjectName, subjectData) {
        for (var topic in subjectData.topics) {
          final score = _calculateScore(subjectName, topic.name, performance);
          scoredTopics.add(score);
        }
      });
    }

    // Sort by score descending
    scoredTopics.sort((a, b) => b.score.compareTo(a.score));

    return scoredTopics;
  }

  WeightedTopic _calculateScore(
    String subject,
    String topic,
    PerformanceSummary performance,
  ) {
    double score = 50.0; // Base score
    String status = 'new';
    String reason = 'Müfredat sırası';

    // Check performance data
    final subjectPerf = performance.topicPerformances[subject];
    if (subjectPerf != null && subjectPerf.containsKey(topic)) {
      final p = subjectPerf[topic]!;
      final total = p.correctCount + p.wrongCount;

      if (total > 5) {
        final accuracy = (p.correctCount / total) * 100;

        if (accuracy < redThreshold) {
          score = 90.0; // Urgent Fix
          status = 'red';
          reason = 'Düşük başarı oranı (%${accuracy.toStringAsFixed(0)})';
          // Boost based on wrong count (frequency of error)
          score += (p.wrongCount * 1.5).clamp(0, 10);
        } else if (accuracy < yellowThreshold) {
          score = 75.0; // Improve
          status = 'yellow';
          reason = 'Geliştirilmeli (%${accuracy.toStringAsFixed(0)})';
        } else {
          score = 30.0; // Maintenance
          status = 'green';
          reason = 'Konu hakimiyeti iyi';
        }
      } else {
        // Started but not enough data
        score = 60.0;
        status = 'new';
        reason = 'Yeni başlandı';
      }
    } else {
      // Not started (New)
      score = 50.0;
      status = 'new';
    }

    return WeightedTopic(
      subject: subject,
      topic: topic,
      score: score,
      status: status,
      reason: reason,
    );
  }
}
