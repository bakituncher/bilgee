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
    // Currently relying on general performance accumulation via PerformanceSummary.
    // Ideally, we would parse recentTests to find "Hot" topics where user failed recently.

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
        } else if (selectedSection == 'TYT ve YDT' && (section.name == 'TYT' || section.name == 'YDT')) {
             isRelevant = true;
        }

        if (!isRelevant) continue;
      }

      section.subjects.forEach((subjectName, subjectData) {
        // Iterate topics with index to calculate "Prerequisite Score"
        // Topics earlier in the list are foundational.
        for (var i = 0; i < subjectData.topics.length; i++) {
          final topic = subjectData.topics[i];
          // Determine relative position (0.0 to 1.0), where 0.0 is beginning (foundation)
          final relativePosition = i / (subjectData.topics.length > 0 ? subjectData.topics.length : 1);

          final score = _calculateScore(
            subjectName,
            topic.name,
            performance,
            relativePosition
          );
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
    double relativePosition,
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
          // RED TOPIC (Urgent Fix)
          score = 90.0;
          status = 'red';
          reason = 'Düşük başarı oranı (%${accuracy.toStringAsFixed(0)})';

          // Boost: If this is a foundational topic (early in list), it's critical.
          // relativePosition 0.0 -> Boost +10
          // relativePosition 1.0 -> Boost +0
          score += (1.0 - relativePosition) * 10.0;

          // Boost: Frequency of error
          score += (p.wrongCount * 1.5).clamp(0, 10);

        } else if (accuracy < yellowThreshold) {
          // YELLOW TOPIC (Improve)
          score = 75.0;
          status = 'yellow';
          reason = 'Geliştirilmeli (%${accuracy.toStringAsFixed(0)})';

          // Slight boost for foundational
          score += (1.0 - relativePosition) * 5.0;

        } else {
          // GREEN TOPIC (Review)
          score = 30.0;
          status = 'green';
          reason = 'Konu hakimiyeti iyi';

          // Decay factor (Spaced Repetition placeholder)
          // If we had "lastStudiedDate", we would boost score as time passes.
        }
      } else {
        // Started but not enough data -> Treat as New/In-Progress
        score = 60.0;
        status = 'new';
        reason = 'Yeni başlandı';
        // Boost earlier topics to encourage finishing foundations first
        score += (1.0 - relativePosition) * 5.0;
      }
    } else {
      // NOT STARTED (New)
      score = 50.0;
      status = 'new';

      // Boost: Order matters heavily here. We want the user to start from Topic 1, then 2.
      // So relativePosition 0.0 should have much higher score than 1.0
      score += (1.0 - relativePosition) * 40.0; // Max score 90 for the very first topic
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
