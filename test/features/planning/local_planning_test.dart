import 'package:flutter_test/flutter_test.dart';
import 'package:taktik/core/services/planning/topic_scorer.dart';
import 'package:taktik/core/services/planning/weekly_scheduler.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/models/performance_summary.dart';
import 'package:taktik/data/models/topic_performance_model.dart';
import 'package:taktik/data/models/user_model.dart';

void main() {
  group('Local Planning System Tests', () {
    late TopicScorer scorer;
    late WeeklyScheduler scheduler;
    late Exam dummyExam;

    setUp(() {
      scorer = TopicScorer();
      scheduler = WeeklyScheduler();

      // Create a dummy Exam
      dummyExam = Exam(
        type: ExamType.yks,
        name: 'Test Exam',
        sections: [
          ExamSection(
            name: 'TYT',
            subjects: {
              'Matematik': SubjectDetails(
                questionCount: 10,
                topics: [
                  SubjectTopic(name: 'Sayılar'),
                  SubjectTopic(name: 'Üslü Sayılar'),
                  SubjectTopic(name: 'Köklü Sayılar'),
                ],
              ),
              'Fizik': SubjectDetails(
                questionCount: 10,
                topics: [
                  SubjectTopic(name: 'Vektörler'),
                  SubjectTopic(name: 'Hareket'),
                ],
              )
            },
          )
        ],
      );
    });

    test('TopicScorer correctly prioritizes weak topics (Red)', () {
      // Setup Performance: "Sayılar" is weak (< 50% accuracy)
      final performance = PerformanceSummary(
        topicPerformances: {
          'Matematik': {
            'Sayılar': TopicPerformanceModel(
              questionCount: 20,
              correctCount: 8, // 40% -> Red
              wrongCount: 12,
            ),
            'Üslü Sayılar': TopicPerformanceModel(
              questionCount: 20,
              correctCount: 18, // 90% -> Green
              wrongCount: 2,
            ),
          }
        },
      );

      final scored = scorer.scoreTopics(
        examModel: dummyExam,
        performance: performance,
        recentTests: [],
        selectedSection: null,
      );

      // Expect "Sayılar" to have higher score than "Üslü Sayılar"
      final sayilar = scored.firstWhere((t) => t.topic == 'Sayılar');
      final uslu = scored.firstWhere((t) => t.topic == 'Üslü Sayılar');
      final koklu = scored.firstWhere((t) => t.topic == 'Köklü Sayılar'); // New topic

      expect(sayilar.status, 'red');
      expect(uslu.status, 'green');
      expect(koklu.status, 'new');

      expect(sayilar.score, greaterThan(uslu.score));
      expect(sayilar.score, greaterThan(koklu.score));
    });

    test('WeeklyScheduler distributes topics into slots', () {
      final topics = [
        WeightedTopic(subject: 'Matematik', topic: 'Sayılar', score: 90, status: 'red', reason: 'Weak'),
        WeightedTopic(subject: 'Fizik', topic: 'Vektörler', score: 60, status: 'new', reason: 'Next'),
        WeightedTopic(subject: 'Matematik', topic: 'Köklü Sayılar', score: 50, status: 'new', reason: 'Next'),
      ];

      final user = UserModel(
        id: '1',
        email: 'test@test.com',
        username: 'test',
        firstName: 'Test',
        lastName: 'User',
        createdAt: DateTime.now(), // Not in constructor actually?
        // Wait, UserModel doesn't have createdAt. Checking fields...
        weeklyAvailability: {
          'Pazartesi': ['09:00', '10:00'],
          'Salı': ['09:00'],
          'Cumartesi': ['09:00', '13:00'], // Mock Exam Day
        },
        goal: 'Win',
        testCount: 0,
        streak: 0,
        // lastActive: DateTime.now(), // Not in constructor
        // onboardingCompleted: true, // profileCompleted?
        profileCompleted: true,
        isPremium: true, challenges: [],
      );

      final plan = scheduler.generateSchedule(
        prioritizedTopics: topics,
        user: user,
        startDate: DateTime.now(),
      );

      // Check Mock Exam
      final saturday = plan.plan.firstWhere((d) => d.day == 'Cumartesi');
      expect(saturday.schedule.any((i) => i.type == 'exam'), true);

      // Check Study Slots
      final monday = plan.plan.firstWhere((d) => d.day == 'Pazartesi');
      expect(monday.schedule.length, 2);
      // Logic puts Fix (Red) first usually
      expect(monday.schedule.first.activity, contains('Sayılar'));
      expect(monday.schedule.first.type, 'fix');

      // Check Interleaving
      expect(monday.schedule[1].activity, contains('Fizik'));
      expect(monday.schedule[1].activity, contains('Vektörler'));
    });
  });
}
