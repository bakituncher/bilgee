// lib/data/repositories/ai_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/data/models/exam_model.dart';
import 'package:bilge_ai/data/models/topic_performance_model.dart';
import 'package:bilge_ai/core/prompts/strategy_prompts.dart';
import 'package:bilge_ai/core/prompts/workshop_prompts.dart';
import 'package:bilge_ai/core/prompts/motivation_prompts.dart';
import 'package:bilge_ai/features/stats/logic/stats_analysis.dart';
import 'package:bilge_ai/features/stats/logic/stats_analysis_provider.dart';
import 'package:bilge_ai/core/utils/json_text_cleaner.dart';
import 'package:bilge_ai/data/models/performance_summary.dart';
import 'package:bilge_ai/data/models/plan_document.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage(this.text, {required this.isUser});
}

final aiServiceProvider = Provider<AiService>((ref) {
  // DÜZELTME: Artık ref'i alıyor.
  return AiService(ref);
});

class AiService {
  final Ref _ref;
  AiService(this._ref);

  String _preprocessAiTextForJson(String input) {
    return JsonTextCleaner.cleanString(input);
  }

  String? _extractJsonFromFencedBlock(String text) {
    final jsonFence = RegExp(r"```json\s*([\s\S]*?)\s*```", multiLine: true).firstMatch(text);
    if (jsonFence != null) return jsonFence.group(1)!.trim();
    final anyFence = RegExp(r"```\s*([\s\S]*?)\s*```", multiLine: true).firstMatch(text);
    if (anyFence != null) return anyFence.group(1)!.trim();
    return null;
  }

  String? _extractJsonByBracesFallback(String text) {
    final startIndex = text.indexOf('{');
    final endIndex = text.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      return text.substring(startIndex, endIndex + 1);
    }
    return null;
  }

  String _parseAndNormalizeJsonOrError(String src) {
    try {
      var parsed = jsonDecode(src);
      if (parsed is String) {
        try {
          parsed = jsonDecode(parsed);
        } catch (_) {}
      }
      return jsonEncode(parsed);
    } catch (_) {
      return jsonEncode({'error': 'Yapay zeka yanıtı anlaşılamadı, lütfen tekrar deneyin.'});
    }
  }

  // Son N günün tamamlanan görevlerini Firestore'dan topla (YYYY-MM-DD -> [taskId])
  Future<Map<String, List<String>>> _loadRecentCompletedTasks(String userId, {int days = 28}) async {
    try {
      final svc = _ref.read(firestoreServiceProvider);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = today.subtract(Duration(days: days - 1));
      final dates = List<DateTime>.generate(days, (i) => start.add(Duration(days: i)));
      final lists = await Future.wait(dates.map((d) => svc.getCompletedTasksForDate(userId, d)));
      final Map<String, List<String>> acc = {};
      for (int i = 0; i < dates.length; i++) {
        final list = lists[i];
        if (list.isNotEmpty) acc[_yyyyMmDd(dates[i])] = list;
      }
      return acc;
    } catch (_) {
      return {};
    }
  }

  String _yyyyMmDd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<String> _callGemini(String prompt, {bool expectJson = false}) async {
    // Yeni yaklaşım: Sunucudaki Firebase Function generateGemini çağrılır.
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('generateGemini');
      final result = await callable.call({
        'prompt': prompt,
        'expectJson': expectJson,
      }).timeout(const Duration(seconds: 70));
      final data = result.data;
      final rawResponse = (data is Map && data['raw'] is String) ? (data['raw'] as String).trim() : '';
      if (rawResponse.isEmpty) {
        return expectJson ? jsonEncode({'error': 'Boş yanıt alındı'}) : 'Boş yanıt alındı';
      }
      String? extracted = _extractJsonFromFencedBlock(rawResponse);
      extracted ??= _extractJsonByBracesFallback(rawResponse);
      String candidate = (extracted ?? rawResponse);
      final cleaned = _preprocessAiTextForJson(candidate);
      if (expectJson) {
        return _parseAndNormalizeJsonOrError(cleaned);
      }
      return cleaned.isNotEmpty ? cleaned : rawResponse;
    } on FirebaseFunctionsException catch (e) {
      final msg = 'Sunucu hata: ${e.code} ${e.message ?? ''}'.trim();
      return expectJson ? jsonEncode({'error': msg}) : '**HATA:** $msg';
    } catch (e) {
      final msg = 'Sunucuya erişilemedi: ${e.toString()}';
      return expectJson ? jsonEncode({'error': msg}) : '**HATA:** $msg';
    }
  }

  int _getDaysUntilExam(ExamType examType) {
    final now = DateTime.now();
    DateTime examDate;
    switch (examType) {
      case ExamType.lgs:
        examDate = DateTime(now.year, 6, 2);
        break;
      case ExamType.yks:
        examDate = DateTime(now.year, 6, 15);
        break;
      case ExamType.kpssLisans:
        examDate = DateTime(now.year, 7, 14);
        break;
      case ExamType.kpssOnlisans:
        examDate = DateTime(now.year, 9, 7);
        break;
      case ExamType.kpssOrtaogretim:
        examDate = DateTime(now.year, 9, 21);
        break;
    }
    if (now.isAfter(examDate)) {
      examDate = DateTime(now.year + 1, examDate.month, examDate.day);
    }
    return examDate.difference(now).inDays;
  }

  String _encodeTopicPerformances(Map<String, Map<String, TopicPerformanceModel>> performances) {
    final encodableMap = performances.map(
          (subjectKey, topicMap) => MapEntry(
        subjectKey,
        topicMap.map(
              (topicKey, model) => MapEntry(topicKey, model.toMap()),
        ),
      ),
    );
    return jsonEncode(encodableMap);
  }

  Future<String> generateGrandStrategy({
    required UserModel user,
    required List<TestModel> tests,
    required PerformanceSummary performance,
    required PlanDocument? planDoc,
    required String pacing,
    String? revisionRequest,
  }) async {
    if (user.selectedExam == null) {
      return '{"error":"Analiz için önce bir sınav seçmelisiniz."}';
    }
    if (user.weeklyAvailability.values.every((list) => list.isEmpty)) {
      return '{"error":"Strateji oluşturmadan önce en az bir tane müsait zaman dilimi seçmelisiniz."}';
    }
    final examType = ExamType.values.byName(user.selectedExam!);
    final daysUntilExam = _getDaysUntilExam(examType);

    // Önbellekli analiz varsa kullan
    final cachedAnalysis = _ref.read(overallStatsAnalysisProvider).value;
    final String avgNet = (cachedAnalysis?.averageNet ?? _quickAverageNet(tests)).toStringAsFixed(2);
    final Map<String, double> subjectAverages = cachedAnalysis?.subjectAverages ?? _computeSubjectAveragesQuick(tests);

    final topicPerformancesJson = _encodeTopicPerformances(performance.topicPerformances);
    final availabilityJson = jsonEncode(user.weeklyAvailability);
    final weeklyPlanJson = planDoc?.weeklyPlan != null ? jsonEncode(planDoc!.weeklyPlan!) : null;

    // ESKİ: jsonEncode(user.completedDailyTasks) her zaman {} dönüyordu.
    // YENİ: Son 28 günün tamamlanan görevlerini oku ve gönder.
    final recentCompleted = await _loadRecentCompletedTasks(user.id, days: 28);
    final completedTasksJson = jsonEncode(recentCompleted);

    String prompt;
    switch (examType) {
      case ExamType.yks:
        prompt = StrategyPrompts.getYksPrompt(
            userId: user.id, selectedExamSection: user.selectedExamSection ?? '',
            daysUntilExam: daysUntilExam, goal: user.goal ?? '',
            challenges: user.challenges, pacing: pacing,
            testCount: user.testCount, avgNet: avgNet,
            subjectAverages: subjectAverages, topicPerformancesJson: topicPerformancesJson,
            availabilityJson: availabilityJson, weeklyPlanJson: weeklyPlanJson,
            completedTasksJson: completedTasksJson,
            revisionRequest: revisionRequest
        );
        break;
      case ExamType.lgs:
        prompt = StrategyPrompts.getLgsPrompt(
            user: user,
            avgNet: avgNet, subjectAverages: subjectAverages,
            pacing: pacing, daysUntilExam: daysUntilExam,
            topicPerformancesJson: topicPerformancesJson, availabilityJson: availabilityJson,
            weeklyPlanJson: weeklyPlanJson,
            completedTasksJson: completedTasksJson,
            revisionRequest: revisionRequest
        );
        break;
      default:
        prompt = StrategyPrompts.getKpssPrompt(
            user: user,
            avgNet: avgNet, subjectAverages: subjectAverages,
            pacing: pacing, daysUntilExam: daysUntilExam,
            topicPerformancesJson: topicPerformancesJson, availabilityJson: availabilityJson,
            examName: examType.displayName,
            weeklyPlanJson: weeklyPlanJson,
            completedTasksJson: completedTasksJson,
            revisionRequest: revisionRequest
        );
        break;
    }
    return _callGemini(prompt, expectJson: true);
  }

  Future<String> generateStudyGuideAndQuiz(UserModel user, List<TestModel> tests, PerformanceSummary performance, {Map<String, String>? topicOverride, String difficulty = 'normal', int attemptCount = 1}) async {
    if (tests.isEmpty) {
      return '{"error":"Analiz için en az bir deneme sonucu gereklidir."}';
    }
    if (user.selectedExam == null) {
      return '{"error":"Sınav türü bulunamadı."}';
    }

    String weakestSubject;
    String weakestTopic;

    if (topicOverride != null) {
      weakestSubject = topicOverride['subject']!;
      weakestTopic = topicOverride['topic']!;
    } else {
      // Önce önbellekli analizden faydalan
      final cachedAnalysis = _ref.read(overallStatsAnalysisProvider).value;
      final info = cachedAnalysis?.getWeakestTopicWithDetails();
      if (info != null) {
        weakestSubject = info['subject']!;
        weakestTopic = info['topic']!;
      } else {
        // Gerekirse eski yol: tek seferlik hesapla (daha ağır ama nadir)
        final examType = ExamType.values.byName(user.selectedExam!);
        final examData = await ExamData.getExamByType(examType);
        final analysis = StatsAnalysis(tests, performance, examData, _ref.read(firestoreServiceProvider), user: user);
        final weakestTopicInfo = analysis.getWeakestTopicWithDetails();

        if (weakestTopicInfo == null) {
          return '{"error":"Analiz için zayıf bir konu bulunamadı. Lütfen önce konu performans verilerinizi girin."}';
        }
        weakestSubject = weakestTopicInfo['subject']!;
        weakestTopic = weakestTopicInfo['topic']!;
      }
    }

    final prompt = getStudyGuideAndQuizPrompt(weakestSubject, weakestTopic, user.selectedExam, difficulty, attemptCount);

    return _callGemini(prompt, expectJson: true);
  }

  Future<String> getPersonalizedMotivation({
    required UserModel user,
    required List<TestModel> tests,
    required PerformanceSummary performance,
    required String promptType,
    required String? emotion,
    Map<String, dynamic>? workshopContext,
  }) async {
    final examType = user.selectedExam != null ? ExamType.values.byName(user.selectedExam!) : null;
    // KALDIRILDI: examData kullanılmıyordu
    // Önbellekli analiz (varsa)
    final analysis = _ref.read(overallStatsAnalysisProvider).value;

    final prompt = getMotivationPrompt(
      user: user,
      tests: tests,
      analysis: analysis,
      examName: examType?.displayName,
      promptType: promptType,
      emotion: emotion,
      workshopContext: workshopContext,
    );
    return _callGemini(prompt, expectJson: false);
  }

  // Hafif yardımcılar: UI dış�� tek seferlik hesaplamalarda kullanılabilir
  double _quickAverageNet(List<TestModel> tests) {
    if (tests.isEmpty) return 0.0;
    final total = tests.fold<double>(0.0, (acc, t) => acc + t.totalNet);
    return total / tests.length;
  }

  Map<String, double> _computeSubjectAveragesQuick(List<TestModel> tests) {
    final Map<String, List<double>> subjectNets = {};
    for (final t in tests) {
      t.scores.forEach((subject, scores) {
        final net = (scores['dogru'] ?? 0) - ((scores['yanlis'] ?? 0) * t.penaltyCoefficient);
        subjectNets.putIfAbsent(subject, () => []).add(net);
      });
    }
    return subjectNets.map((k, v) => MapEntry(k, v.isEmpty ? 0.0 : v.reduce((a, b) => a + b) / v.length));
  }
}