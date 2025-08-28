// lib/core/prompts/strategy_prompts.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/data/models/performance_summary.dart';
import 'package:bilge_ai/data/models/plan_document.dart';

class StrategyPrompts {
  static String? _yksTemplate;
  static String? _lgsTemplate;
  static String? _kpssTemplate;

  static Future<void> preload() async {
    _yksTemplate = await rootBundle.loadString('assets/prompts/yks_prompt.md');
    _lgsTemplate = await rootBundle.loadString('assets/prompts/lgs_prompt.md');
    _kpssTemplate = await rootBundle.loadString('assets/prompts/kpss_prompt.md');
  }

  static String _revisionBlock(String? revisionRequest) {
    if (revisionRequest != null && revisionRequest.isNotEmpty) {
      return """
      // REVİZYON EMRİ:
      // BU ÇOK ÖNEMLİ! KULLANICI MEVCUT PLANDAN MEMNUN DEĞİL VE AŞAĞIDAKİ DEĞİŞİKLİKLERİ İSTİYOR.
      // YENİ PLANI BU TALEPLERİ MERKEZE ALARAK, SIFIRDAN OLUŞTUR.
      // KULLANICI TALEPLERİ:
      $revisionRequest
      """;
    }
    return '';
  }

  static String _fillTemplate(String template, Map<String, String> values) {
    String out = template;
    values.forEach((k, v) {
      out = out.replaceAll('{{$k}}', v);
    });
    return out;
  }

  static String getYksPrompt({
    required String userId,
    required String selectedExamSection,
    required int daysUntilExam,
    required String goal,
    required List<String>? challenges,
    required String pacing,
    required int testCount,
    required String avgNet,
    required Map<String, double> subjectAverages,
    required String topicPerformancesJson,
    required String availabilityJson,
    required String? weeklyPlanJson,
    required String completedTasksJson,
    String? revisionRequest,
  }) {
    assert(_yksTemplate != null, 'StrategyPrompts.preload() çağrılmalı');
    final template = _yksTemplate!;
    final phase2Start = daysUntilExam > 90 ? (daysUntilExam - 60) : 30;
    final replacements = <String, String>{
      'REVISION_BLOCK': _revisionBlock(revisionRequest),
      'AVAILABILITY_JSON': availabilityJson,
      'USER_ID': userId,
      'SELECTED_EXAM_SECTION': selectedExamSection,
      'DAYS_UNTIL_EXAM': daysUntilExam.toString(),
      'GOAL': goal,
      'CHALLENGES': challenges?.join(', ') ?? '—',
      'PACING': pacing,
      'TEST_COUNT': testCount.toString(),
      'AVG_NET': avgNet,
      'SUBJECT_AVERAGES': jsonEncode(subjectAverages),
      'TOPIC_PERFORMANCES_JSON': topicPerformancesJson,
      'WEEKLY_PLAN_TEXT': weeklyPlanJson ?? 'YOK. BU İLK HAFTA. TAARRUZ BAŞLIYOR.',
      'COMPLETED_TASKS_JSON': completedTasksJson,
      'PHASE2_START': phase2Start.toString(),
    };
    return _fillTemplate(template, replacements);
  }

  static String getLgsPrompt({
    required UserModel user,
    required String avgNet,
    required Map<String, double> subjectAverages,
    required String pacing,
    required int daysUntilExam,
    required String topicPerformancesJson,
    required String availabilityJson,
    required String? weeklyPlanJson,
    String? revisionRequest,
  }) {
    assert(_lgsTemplate != null, 'StrategyPrompts.preload() çağrılmalı');
    final template = _lgsTemplate!;
    final replacements = <String, String>{
      'REVISION_BLOCK': _revisionBlock(revisionRequest),
      'AVAILABILITY_JSON': availabilityJson,
      'USER_ID': user.id,
      'DAYS_UNTIL_EXAM': daysUntilExam.toString(),
      'GOAL': user.goal ?? '',
      'CHALLENGES': (user.challenges ?? []).join(', '),
      'PACING': pacing,
      'TEST_COUNT': user.testCount.toString(),
      'AVG_NET': avgNet,
      'SUBJECT_AVERAGES': jsonEncode(subjectAverages),
      'TOPIC_PERFORMANCES_JSON': topicPerformancesJson,
      'WEEKLY_PLAN_TEXT': weeklyPlanJson ?? 'YOK. HAREKÂT BAŞLIYOR.',
    };
    return _fillTemplate(template, replacements);
  }

  static String getKpssPrompt({
    required UserModel user,
    required String avgNet,
    required Map<String, double> subjectAverages,
    required String pacing,
    required int daysUntilExam,
    required String topicPerformancesJson,
    required String availabilityJson,
    required String examName,
    required String? weeklyPlanJson,
    String? revisionRequest,
  }) {
    assert(_kpssTemplate != null, 'StrategyPrompts.preload() çağrılmalı');
    final template = _kpssTemplate!;
    final replacements = <String, String>{
      'REVISION_BLOCK': _revisionBlock(revisionRequest),
      'AVAILABILITY_JSON': availabilityJson,
      'USER_ID': user.id,
      'EXAM_NAME': examName,
      'DAYS_UNTIL_EXAM': daysUntilExam.toString(),
      'GOAL': user.goal ?? '',
      'CHALLENGES': (user.challenges ?? []).join(', '),
      'PACING': pacing,
      'TEST_COUNT': user.testCount.toString(),
      'AVG_NET': avgNet,
      'SUBJECT_AVERAGES': jsonEncode(subjectAverages),
      'TOPIC_PERFORMANCES_JSON': topicPerformancesJson,
      'WEEKLY_PLAN_TEXT': weeklyPlanJson ?? 'YOK. PLANLAMA BAŞLIYOR.',
    };
    return _fillTemplate(template, replacements);
  }
}