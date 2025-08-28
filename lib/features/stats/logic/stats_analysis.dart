// lib/features/stats/logic/stats_analysis.dart
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:bilge_ai/data/models/exam_model.dart';
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/models/performance_summary.dart';
import 'package:bilge_ai/data/repositories/firestore_service.dart';

class TacticalAdvice {
  final String text;
  final IconData icon;
  final Color color;
  TacticalAdvice(this.text, {required this.icon, required this.color});
}

class SubjectAnalysis {
  final String subjectName;
  final double averageNet;
  final double bestNet;
  final double worstNet;
  final double trend;
  final int questionCount;
  final double penaltyCoefficient;
  final List<TestModel> subjectTests;
  final List<FlSpot> netSpots;

  SubjectAnalysis({
    required this.subjectName,
    required this.averageNet,
    required this.bestNet,
    required this.worstNet,
    required this.trend,
    required this.questionCount,
    required this.penaltyCoefficient,
    required this.subjectTests,
    required this.netSpots,
  });
}

class StatsAnalysis {
  final List<TestModel> tests;
  final PerformanceSummary performanceSummary;
  final Exam examData;
  final FirestoreService firestoreService;
  final UserModel? user;

  late List<TestModel> sortedTests;
  late List<FlSpot> netSpots;
  late double warriorScore;
  late double accuracy;
  late double consistency;
  late double trend;
  late Map<String, double> subjectAverages;
  late List<MapEntry<String, double>> sortedSubjects;
  late List<TacticalAdvice> tacticalAdvice;
  late double averageNet;
  late String weakestSubjectByNet;
  late String strongestSubjectByNet;

  StatsAnalysis(this.tests, this.performanceSummary, this.examData, this.firestoreService, {this.user}) {
    if (tests.isEmpty && performanceSummary.topicPerformances.isEmpty) {
      _initializeEmpty();
      return;
    }

    if(tests.isNotEmpty) {
      sortedTests = List.from(tests)..sort((a, b) => a.date.compareTo(b.date));
      final allNets = sortedTests.map((t) => t.totalNet).toList();
      averageNet = allNets.average;
      final totalQuestionsAttempted = sortedTests.map((t) => t.totalCorrect + t.totalWrong).sum;
      final totalCorrectAnswers = sortedTests.map((t) => t.totalCorrect).sum;
      if (averageNet.abs() > 0.001) {
        final double stdDev = sqrt(allNets.map((n) => pow(n - averageNet, 2)).sum / allNets.length);
        consistency = max(0, (1 - (stdDev / averageNet.abs())) * 100);
      } else {
        consistency = 0.0;
      }
      accuracy = totalQuestionsAttempted > 0 ? (totalCorrectAnswers / totalQuestionsAttempted) * 100 : 0.0;
      trend = _calculateTrend(allNets);
      netSpots = List.generate(sortedTests.length, (i) => FlSpot(i.toDouble(), sortedTests[i].totalNet));
      final netComponent = (averageNet / (sortedTests.first.totalQuestions * 1.0)) * 50;
      final accuracyComponent = (accuracy / 100) * 25;
      final consistencyComponent = (consistency / 100) * 15;
      final trendComponent = (atan(trend) / (pi / 2)) * 10;
      warriorScore = (netComponent + accuracyComponent + consistencyComponent + trendComponent).clamp(0, 100);
      final subjectNets = <String, List<double>>{};
      for (var test in sortedTests) {
        test.scores.forEach((subject, scores) {
          final net = (scores['dogru'] ?? 0) - ((scores['yanlis'] ?? 0) * test.penaltyCoefficient);
          subjectNets.putIfAbsent(subject, () => []).add(net);
        });
      }

      if (subjectNets.isNotEmpty) {
        subjectAverages = subjectNets.map((subject, nets) => MapEntry(subject, nets.average));
        sortedSubjects = subjectAverages.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        weakestSubjectByNet = sortedSubjects.last.key;
        strongestSubjectByNet = sortedSubjects.first.key;
      } else {
        _initializeEmptySubjects();
      }
      tacticalAdvice = _generateTacticalAdvice();
    } else {
      _initializeEmptyFromTopics();
    }
  }

  // YENI: Özet veriden minimal StatsAnalysis oluşturur
  factory StatsAnalysis.fromSummary(
    Map<String, dynamic> data,
    Exam examData,
    FirestoreService firestoreService, {
    UserModel? user,
  }) {
    final analysis = StatsAnalysis(
      const <TestModel>[],
      const PerformanceSummary(),
      examData,
      firestoreService,
      user: user,
    );
    // Varsayılan boşları oluşturduktan sonra özet alanları üzerine yaz
    analysis.averageNet = (data['averageNet'] as num?)?.toDouble() ?? 0.0;
    analysis.trend = (data['trend'] as num?)?.toDouble() ?? 0.0;
    analysis.warriorScore = (data['warriorScore'] as num?)?.toDouble() ?? 0.0;
    analysis.weakestSubjectByNet = (data['weakestSubjectByNet'] as String?) ?? 'Belirlenemedi';
    analysis.strongestSubjectByNet = (data['strongestSubjectByNet'] as String?) ?? 'Belirlenemedi';
    // Diğer alanları minimal tut
    analysis.accuracy = 0.0;
    analysis.consistency = 0.0;
    analysis.subjectAverages = {};
    analysis.sortedSubjects = [];
    analysis.sortedTests = const <TestModel>[];
    analysis.netSpots = const <FlSpot>[];
    analysis.tacticalAdvice = const <TacticalAdvice>[];
    return analysis;
  }

  double _calculateTrend(List<double> data) {
    if (data.length < 2) return 0.0;
    final n = data.length;
    final sumX = (n * (n - 1)) / 2;
    final sumY = data.sum;
    final sumXY = List.generate(n, (i) => i * data[i]).sum;
    final sumX2 = List.generate(n, (i) => i * i).sum;
    final numerator = (n * sumXY) - (sumX * sumY);
    final denominator = (n * sumX2) - (sumX * sumX);
    return denominator == 0 ? 0.0 : numerator / denominator;
  }

  SubjectAnalysis getAnalysisForSubject(String subjectName) {
    final subjectTests = sortedTests.where((t) => t.scores.containsKey(subjectName)).toList();
    if (subjectTests.isEmpty) {
      return SubjectAnalysis(subjectName: subjectName, averageNet: 0, bestNet: 0, worstNet: 0, trend: 0, questionCount: 0, penaltyCoefficient: 0.25, subjectTests: [], netSpots: []);
    }

    final subjectNets = subjectTests.map((t) {
      final scores = t.scores[subjectName]!;
      return (scores['dogru'] ?? 0) - ((scores['yanlis'] ?? 0) * t.penaltyCoefficient);
    }).toList();

    final netSpots = List.generate(subjectNets.length, (i) => FlSpot(i.toDouble(), subjectNets[i]));

    return SubjectAnalysis(
      subjectName: subjectName,
      averageNet: subjectNets.average,
      bestNet: subjectNets.reduce(max),
      worstNet: subjectNets.reduce(min),
      trend: _calculateTrend(subjectNets),
      questionCount: getQuestionCountForSubject(subjectName),
      penaltyCoefficient: subjectTests.first.penaltyCoefficient,
      subjectTests: subjectTests,
      netSpots: netSpots,
    );
  }

  List<TacticalAdvice> _generateTacticalAdvice() {
    final adviceList = <TacticalAdvice>[];
    if (sortedSubjects.isEmpty) return adviceList;

    if (warriorScore > 75) {
      adviceList.add(TacticalAdvice("MUHAREBE DURUMU: MÜKEMMEL. Kalen sarsılmaz, stratejin kusursuz. Zirveyi koru.", icon: Icons.workspace_premium, color: Colors.amber));
    } else {
      adviceList.add(TacticalAdvice("MUHAREBE DURUMU: İYİ. Güçlüsün ama zafiyetlerin var. Zayıf cepheleri güçlendirerek hakimiyetini pekiştir.", icon: Icons.shield_rounded, color: AppTheme.successColor));
    }

    adviceList.add(TacticalAdvice("TAARRUZ EMRİ: '$weakestSubjectByNet' cephesi en zayıf halkan. Tüm gücünle bu hedefe yüklen. Bu kaleyi fethetmek, zaferi getirecek.", icon: Icons.radar_rounded, color: AppTheme.accentColor));

    return adviceList;
  }

  List<Map<String, dynamic>> _getRankedTopics() {
    final List<Map<String, dynamic>> allTopics = [];
    final relevantSections = examData.sections;

    performanceSummary.topicPerformances.forEach((sanitizedSubjectKey, topics) {
      String originalSubjectName = "";
      SubjectDetails? subjectDetails;

      for (var section in relevantSections) {
        for (var entry in section.subjects.entries) {
          if (firestoreService.sanitizeKey(entry.key) == sanitizedSubjectKey) {
            originalSubjectName = entry.key;
            subjectDetails = entry.value;
            break;
          }
        }
        if (originalSubjectName.isNotEmpty) break;
      }
      if (originalSubjectName.isEmpty) return;

      final penalty = relevantSections
          .firstWhere((s) => s.subjects.containsKey(originalSubjectName))
          .penaltyCoefficient;

      topics.forEach((sanitizedTopicKey, performance) {
        final originalTopicName = subjectDetails?.topics
            .firstWhere((t) => firestoreService.sanitizeKey(t.name) == sanitizedTopicKey, orElse: () => SubjectTopic(name: ''))
            .name ?? '';
        if (originalTopicName.isEmpty) return;

        if (performance.questionCount > 3) {
          final mastery = (performance.correctCount - (performance.wrongCount * penalty)) / performance.questionCount;
          final weightedScore = mastery - (performance.questionCount / 1000);
          allTopics.add({
            'subject': originalSubjectName,
            'topic': originalTopicName,
            'mastery': mastery.clamp(0.0, 1.0),
            'weightedScore': weightedScore,
          });
        }
      });
    });

    allTopics.sort((a, b) => a['weightedScore'].compareTo(b['weightedScore']));
    return allTopics;
  }

  List<Map<String, dynamic>> getWorkshopSuggestions({int count = 3}) {
    final rankedTopics = _getRankedTopics();

    final unmasteredTopics = rankedTopics.where((topic) {
      final sanitizedSubject = firestoreService.sanitizeKey(topic['subject']);
      final sanitizedTopic = firestoreService.sanitizeKey(topic['topic']);
      final uniqueIdentifier = '$sanitizedSubject-$sanitizedTopic';
      return !(performanceSummary.masteredTopics.contains(uniqueIdentifier));
    }).toList();

    if (unmasteredTopics.isNotEmpty) {
      return unmasteredTopics.take(count).toList();
    }

    final suggestions = <Map<String, dynamic>>[];
    final random = Random();

    final primarySubjects = examData.sections.expand((s) => s.subjects.entries).toList();
    if (primarySubjects.isEmpty) return [];

    while (suggestions.length < count && primarySubjects.isNotEmpty) {
      final randomSubjectEntry = primarySubjects[random.nextInt(primarySubjects.length)];
      final subjectName = randomSubjectEntry.key;
      final subjectDetails = randomSubjectEntry.value;

      if (subjectDetails.topics.isNotEmpty) {
        final randomTopic = subjectDetails.topics[random.nextInt(subjectDetails.topics.length)];
        final alreadyExists = suggestions.any((s) => s['topic'] == randomTopic.name);
        if (!alreadyExists) {
          suggestions.add({
            'subject': subjectName,
            'topic': randomTopic.name,
            'mastery': -0.1,
            'isSuggestion': true,
          });
        }
      }
    }
    return suggestions;
  }

  Map<String, String>? getWeakestTopicWithDetails() {
    final ranked = _getRankedTopics();
    if (ranked.isNotEmpty) {
      final weakest = ranked.first;
      return {
        'subject': weakest['subject'].toString(),
        'topic': weakest['topic'].toString(),
      };
    }
    return null;
  }

  void _initializeEmptySubjects() {
    subjectAverages = {};
    sortedSubjects = [];
    weakestSubjectByNet = "Belirlenemedi";
    strongestSubjectByNet = "Belirlenemedi";
  }

  void _initializeEmpty() {
    sortedTests = [];
    netSpots = [];
    warriorScore = 0.0;
    accuracy = 0.0;
    consistency = 0.0;
    trend = 0.0;
    averageNet = 0.0;
    tacticalAdvice = [];
    _initializeEmptySubjects();
  }

  void _initializeEmptyFromTopics() {
    sortedTests = [];
    netSpots = [];
    warriorScore = 0.0;
    accuracy = 0.0;
    consistency = 0.0;
    trend = 0.0;
    averageNet = 0.0;
    tacticalAdvice = [];
    _initializeEmptySubjects();
  }

  int getQuestionCountForSubject(String subjectName) {
    if (tests.isEmpty) return 40;
    final sectionName = tests.first.sectionName;
    final section = examData.sections.firstWhere((s) => s.name == sectionName, orElse: () => examData.sections.first);
    return section.subjects[subjectName]?.questionCount ?? 40;
  }
}