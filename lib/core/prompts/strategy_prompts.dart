// lib/core/prompts/strategy_prompts.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:taktik/data/models/user_model.dart';

class StrategyPrompts {
  static String? _yksTemplate;
  static String? _lgsTemplate;
  static String? _kpssTemplate;
  static String? _agsTemplate;

  static Future<void> preload() async {
    _yksTemplate = await rootBundle.loadString('assets/prompts/yks_prompt.md');
    _lgsTemplate = await rootBundle.loadString('assets/prompts/lgs_prompt.md');
    _kpssTemplate = await rootBundle.loadString('assets/prompts/kpss_prompt.md');
    _agsTemplate = await rootBundle.loadString('assets/prompts/ags_prompt.md');
  }

  static String _revisionBlock(String? revisionRequest) {
    if (revisionRequest != null && revisionRequest.isNotEmpty) {
      return """

## ⚠️ KRİTİK REVİZYON TALEBİ

Kullanıcının Geri Bildirimi:
"$revisionRequest"

**AKSİYON:** Planı tamamen YENİDEN oluştur. Önceki planı unut.
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

  // --- YKS PROMPT ---
  static String getYksPrompt({
    required String userId,
    required String selectedExamSection,
    required int daysUntilExam,
    required String pacing,
    required int testCount,
    required String avgNet,
    required Map<String, double> subjectAverages,
    required String availabilityJson,
    required String curriculumJson,
    required String guardrailsJson,
    String? revisionRequest,
  }) {
    assert(_yksTemplate != null, 'StrategyPrompts.preload() çağrılmalı');
    final template = _yksTemplate!;
    final currentDate = DateTime.now().toIso8601String();
    final currentWeek = '1'; // Basitleştirilmiş hafta takibi

    final replacements = <String, String>{
      'REVISION_BLOCK': _revisionBlock(revisionRequest),
      'AVAILABILITY_JSON': availabilityJson,
      'USER_ID': userId,
      'SELECTED_EXAM_SECTION': selectedExamSection,
      'DAYS_UNTIL_EXAM': daysUntilExam.toString(),
      'PACING': pacing,
      'TEST_COUNT': testCount.toString(),
      'AVG_NET': avgNet,
      'SUBJECT_AVERAGES': jsonEncode(subjectAverages),
      'CURRICULUM_JSON': curriculumJson,
      'GUARDRAILS_JSON': guardrailsJson,
      'CURRENT_DATE': currentDate,
      'CURRENT_WEEK': currentWeek,
    };
    return _fillTemplate(template, replacements);
  }

  // --- LGS PROMPT ---
  static String getLgsPrompt({
    required UserModel user,
    required String avgNet,
    required Map<String, double> subjectAverages,
    required String pacing,
    required int daysUntilExam,
    required String availabilityJson,
    required String curriculumJson,
    required String guardrailsJson,
    String? revisionRequest,
  }) {
    assert(_lgsTemplate != null, 'StrategyPrompts.preload() çağrılmalı');
    final template = _lgsTemplate!;
    final currentDate = DateTime.now().toIso8601String();
    final currentWeek = '1';

    final replacements = <String, String>{
      'REVISION_BLOCK': _revisionBlock(revisionRequest),
      'AVAILABILITY_JSON': availabilityJson,
      'USER_ID': user.id,
      'DAYS_UNTIL_EXAM': daysUntilExam.toString(),
      'PACING': pacing,
      'TEST_COUNT': user.testCount.toString(),
      'AVG_NET': avgNet,
      'SUBJECT_AVERAGES': jsonEncode(subjectAverages),
      'TOPIC_PERFORMANCES_JSON': '[]',
      'CURRICULUM_JSON': curriculumJson,
      'GUARDRAILS_JSON': guardrailsJson,
      'CURRENT_DATE': currentDate,
      'CURRENT_WEEK': currentWeek,
    };
    return _fillTemplate(template, replacements);
  }

  // --- KPSS PROMPT ---
  static String getKpssPrompt({
    required UserModel user,
    required String avgNet,
    required Map<String, double> subjectAverages,
    required String pacing,
    required int daysUntilExam,
    required String availabilityJson,
    required String examName,
    required String curriculumJson,
    required String guardrailsJson,
    String? revisionRequest,
  }) {
    assert(_kpssTemplate != null, 'StrategyPrompts.preload() çağrılmalı');
    final template = _kpssTemplate!;
    final currentDate = DateTime.now().toIso8601String();
    final currentWeek = '1';

    final replacements = <String, String>{
      'REVISION_BLOCK': _revisionBlock(revisionRequest),
      'AVAILABILITY_JSON': availabilityJson,
      'USER_ID': user.id,
      'EXAM_NAME': examName,
      'DAYS_UNTIL_EXAM': daysUntilExam.toString(),
      'PACING': pacing,
      'TEST_COUNT': user.testCount.toString(),
      'AVG_NET': avgNet,
      'SUBJECT_AVERAGES': jsonEncode(subjectAverages),
      'TOPIC_PERFORMANCES_JSON': '[]',
      'CURRICULUM_JSON': curriculumJson,
      'GUARDRAILS_JSON': guardrailsJson,
      'CURRENT_DATE': currentDate,
      'CURRENT_WEEK': currentWeek,
    };
    return _fillTemplate(template, replacements);
  }

  // --- AGS PROMPT ---
  static String getAgsPrompt({
    required UserModel user,
    required String avgNet,
    required Map<String, double> subjectAverages,
    required String pacing,
    required int daysUntilExam,
    required String availabilityJson,
    required String curriculumJson,
    required String guardrailsJson,
    String? revisionRequest,
  }) {
    assert(_agsTemplate != null, 'StrategyPrompts.preload() çağrılmalı');
    final template = _agsTemplate!;
    final currentDate = DateTime.now().toIso8601String();
    final currentWeek = '1';

    final replacements = <String, String>{
      'REVISION_BLOCK': _revisionBlock(revisionRequest),
      'AVAILABILITY_JSON': availabilityJson,
      'USER_ID': user.id,
      'DAYS_UNTIL_EXAM': daysUntilExam.toString(),
      'PACING': pacing,
      'TEST_COUNT': user.testCount.toString(),
      'AVG_NET': avgNet,
      'SUBJECT_AVERAGES': jsonEncode(subjectAverages),
      'CURRICULUM_JSON': curriculumJson,
      'GUARDRAILS_JSON': guardrailsJson,
      'CURRENT_DATE': currentDate,
      'CURRENT_WEEK': currentWeek,
    };
    return _fillTemplate(template, replacements);
  }
}
