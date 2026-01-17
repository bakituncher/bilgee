import 'dart:convert';
import 'package:taktik/core/services/planning/topic_scorer.dart';
import 'package:taktik/core/services/planning/weekly_scheduler.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/models/performance_summary.dart';
import 'package:taktik/data/models/plan_document.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/models/user_model.dart';

class LocalPlanningService {
  final TopicScorer _scorer = TopicScorer();
  final WeeklyScheduler _scheduler = WeeklyScheduler();

  Future<String> generatePlanJson({
    required UserModel user,
    required List<TestModel> tests,
    required PerformanceSummary performance,
    required PlanDocument? planDoc,
    required String pacing,
  }) async {
    try {
      if (user.selectedExam == null) {
        return jsonEncode({'error': 'Sınav seçimi yapılmamış.'});
      }

      if (user.weeklyAvailability.values.every((list) => list.isEmpty)) {
        return jsonEncode({'error': 'Strateji oluşturmadan önce en az bir tane müsait zaman dilimi seçmelisiniz.'});
      }

      final examType = ExamType.values.byName(user.selectedExam!);
      final exam = await ExamData.getExamByType(examType);

      // 1. Score Topics
      final weightedTopics = _scorer.scoreTopics(
        examModel: exam,
        performance: performance,
        recentTests: tests,
        selectedSection: user.selectedExamSection,
      );

      // 2. Generate Schedule
      final weeklyPlan = _scheduler.generateSchedule(
        prioritizedTopics: weightedTopics,
        user: user,
        startDate: DateTime.now(),
      );

      // 3. Convert to Map/JSON
      // We wrap it in a structure that the UI expects: { 'weeklyPlan': ... }
      // WeeklyPlan.fromJson expects the inner map.
      // But the UI (StrategyGenerationNotifier) expects:
      // { 'weeklyPlan': { ... } }

      // Let's look at WeeklyPlan.fromJson, it takes a Map.
      // So we need to serialize WeeklyPlan to Map.
      // WeeklyPlan doesn't seem to have a toJson method in the file I read earlier.
      // I need to check if I can construct the map manually or if I need to add toJson to WeeklyPlan.

      // Checking PlanModel again... I read it earlier.
      // It has fromJson but NO toJson.
      // I should add a toJson method to WeeklyPlan or manually construct the map here.
      // Manual construction is safer than modifying shared models if not needed, but toJson is standard.
      // For now, I will manually construct it here to avoid touching too many files if possible.

      final planMap = {
        'planTitle': weeklyPlan.planTitle,
        'strategyFocus': weeklyPlan.strategyFocus,
        'creationDate': weeklyPlan.creationDate.toIso8601String(),
        'motivationalQuote': weeklyPlan.motivationalQuote,
        'plan': weeklyPlan.plan.map((daily) => {
          'day': daily.day,
          'schedule': daily.schedule.map((item) => {
            'id': item.id,
            'time': item.time,
            'activity': item.activity,
            'type': item.type,
          }).toList(),
        }).toList(),
      };

      final result = {
        'weeklyPlan': planMap,
      };

      return jsonEncode(result);

    } catch (e, s) {
      // Fallback or error handling
      print('Plan Generation Error: $e');
      print(s);
      return jsonEncode({'error': 'Plan oluşturulurken bir hata oluştu: $e'});
    }
  }
}
