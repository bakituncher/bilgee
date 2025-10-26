// lib/core/prompts/strategy_prompts.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/core/prompts/prompt_remote.dart';

class StrategyPrompts {
  static String? _yksTemplate;
  static String? _lgsTemplate;
  static String? _kpssTemplate;

  static Future<void> preload() async {
    // Önce Firestore’daki uzaktan içerikleri dene; yoksa asset’e geri dön
    _yksTemplate = RemotePrompts.get('yks_prompt') ?? await rootBundle.loadString('assets/prompts/yks_prompt.md');
    // Tüm sınavlar için YKS şablonunu temel al
    _lgsTemplate = _yksTemplate;
    _kpssTemplate = _yksTemplate;
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

  static String _rulesBlock({
    required String curriculumJson,
    required int daysUntilExam,
    required String pacing,
    required String guardrailsJson,
  }) {
    final urgency = daysUntilExam <= 14 ? 'kritik' : daysUntilExam <= 30 ? 'yüksek' : daysUntilExam <= 90 ? 'orta' : 'uzun-vade';

    return '''
// KISITLAR:
// Guardrails: $guardrailsJson
// - Backlog doluysa yeni konu yok
// - Kırmızı/sarı konuları öncelikle
// - Unknown konularda kısa tanılayıcı set
// Müfredat sırası: $curriculumJson
// Tempo (pacing=$pacing): relaxed=düşük, moderate=dengeli, intense=yüksek
// Aciliyet (days=$daysUntilExam, level=$urgency)
// JSON format: weeklyPlan {planTitle, strategyFocus, creationDate, plan[{day, schedule[{time, activity, type}]}]}
// Activity örnekleri: "Türev - 40 soru", type: study/practice/test/review/break
''';
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
    required String curriculumJson,
    required String guardrailsJson,
    String? revisionRequest,
  }) {
    assert(_yksTemplate != null, 'StrategyPrompts.preload() çağrılmalı');
    final template = _yksTemplate!;
    final phase2Start = daysUntilExam > 90 ? (daysUntilExam - 60) : 30;
    final rules = _rulesBlock(curriculumJson: curriculumJson, daysUntilExam: daysUntilExam, pacing: pacing, guardrailsJson: guardrailsJson);
    final base = '$rules\n$template';
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
    return _fillTemplate(base, replacements);
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
    required String completedTasksJson,
    required String curriculumJson,
    required String guardrailsJson,
    String? revisionRequest,
  }) {
    // LGS de YKS şablonunun uyarlanmış sürümünü kullan
    assert(_yksTemplate != null, 'StrategyPrompts.preload() çağrılmalı');
    final template = _yksTemplate!;
    final rules = _rulesBlock(curriculumJson: curriculumJson, daysUntilExam: daysUntilExam, pacing: pacing, guardrailsJson: guardrailsJson);
    final base = '$rules\n$template';
    final phase2Start = daysUntilExam > 90 ? (daysUntilExam - 60) : 30;
    final replacements = <String, String>{
      'REVISION_BLOCK': _revisionBlock(revisionRequest),
      'AVAILABILITY_JSON': availabilityJson,
      'USER_ID': user.id,
      // LGS için bölüm bilgisi olmayabilir; boş geç
      'SELECTED_EXAM_SECTION': user.selectedExamSection ?? '',
      'DAYS_UNTIL_EXAM': daysUntilExam.toString(),
      'GOAL': user.goal ?? '',
      'CHALLENGES': (user.challenges ?? []).join(', '),
      'PACING': pacing,
      'TEST_COUNT': user.testCount.toString(),
      'AVG_NET': avgNet,
      'SUBJECT_AVERAGES': jsonEncode(subjectAverages),
      'TOPIC_PERFORMANCES_JSON': topicPerformancesJson,
      'WEEKLY_PLAN_TEXT': weeklyPlanJson ?? 'YOK. HAREKÂT BAŞLIYOR.',
      'COMPLETED_TASKS_JSON': completedTasksJson,
      'PHASE2_START': phase2Start.toString(),
      // Uyumlu olması için isim geçilebilir; YKS şablonu kullanmayabilir
      'EXAM_NAME': 'LGS',
    };
    return _fillTemplate(base, replacements);
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
    required String completedTasksJson,
    required String curriculumJson,
    required String guardrailsJson,
    String? revisionRequest,
  }) {
    // KPSS de YKS şablonunun uyarlanmış sürümünü kullan
    assert(_yksTemplate != null, 'StrategyPrompts.preload() çağrılmalı');
    final template = _yksTemplate!;
    final rules = _rulesBlock(curriculumJson: curriculumJson, daysUntilExam: daysUntilExam, pacing: pacing, guardrailsJson: guardrailsJson);
    final base = '$rules\n$template';
    final phase2Start = daysUntilExam > 90 ? (daysUntilExam - 60) : 30;
    final replacements = <String, String>{
      'REVISION_BLOCK': _revisionBlock(revisionRequest),
      'AVAILABILITY_JSON': availabilityJson,
      'USER_ID': user.id,
      'SELECTED_EXAM_SECTION': user.selectedExamSection ?? '',
      'DAYS_UNTIL_EXAM': daysUntilExam.toString(),
      'GOAL': user.goal ?? '',
      'CHALLENGES': (user.challenges ?? []).join(', '),
      'PACING': pacing,
      'TEST_COUNT': user.testCount.toString(),
      'AVG_NET': avgNet,
      'SUBJECT_AVERAGES': jsonEncode(subjectAverages),
      'TOPIC_PERFORMANCES_JSON': topicPerformancesJson,
      'WEEKLY_PLAN_TEXT': weeklyPlanJson ?? 'YOK. PLANLAMA BAŞLIYOR.',
      'COMPLETED_TASKS_JSON': completedTasksJson,
      'PHASE2_START': phase2Start.toString(),
      'EXAM_NAME': examName,
    };
    return _fillTemplate(base, replacements);
  }
}
