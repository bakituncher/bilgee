// lib/core/prompts/strategy_prompts.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/exam_model.dart';
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
    final urgency = daysUntilExam <= 14
        ? 'kritik-son-2-hafta'
        : daysUntilExam <= 30
            ? 'yüksek-önem'
            : daysUntilExam <= 90
                ? 'orta-önem'
                : 'uzun-vade';

    return '''
// PLAN KISITLARI — MUTLAKA UY:
// 0) GUARDRAILS: ${guardrailsJson}
//    - backlog doluysa YENİ KONU AÇMA. Önce backlog'daki konuları bitir.
//    - konuStatus kırmızı/sarı olanları önceliklendir; kırmızıya daha fazla pratik (soru) ve tekrar koy.
//    - unknown (veri az) konularda önce tanılayıcı kısa setler uygula, sonra yoğunluğu artır.
// KURALLAR VE STANDARTLAR — MUTLAKA UY:
// 1) MÜFREDAT SIRASI: Aşağıdaki konu sırasını temel al ve mümkün oldukça bu sırayı koru.
//    curriculum_order_json: ${curriculumJson}
// 2) TEKRAR ÖNLEME: Geçmiş hafta planı, tamamlanan görevler ve konu performanslarını analiz et. 
//    Aynı konuyu gereksiz yere tekrarlama; gerekirse "hafif pekiştirme" olarak kısalt.
// 3) ÇIKTI FORMAT STANDARDI: Haftalık plan JSON olmalı ve alanlar şu şekilde:
//    weeklyPlan: { planTitle, strategyFocus, creationDate, plan: [ {day, schedule: [ {time, activity, type} ]} ] }
//    - schedule.activity içinde, konu adını yaz ve ardından pratik/soru sayısını açıkça belirt (örn: "Denklemler - 40 soru" ).
//    - type study/practice/test/review/break değerlerinden biri olmalı.
// 4) YOĞUNLUK (pacing=${pacing}):
//    - relaxed: konu sayısı ve soru adetleri düşük (gün başı 1-2 konu, 20-30 soru)
//    - moderate: dengeli (gün başı 2-3 konu, 30-50 soru)
//    - intense: yüksek tempo (gün başı 3-4 konu, 50-80 soru)
//    Duruma göre süre/slotları dağıt.
// 5) SINAV ACİLİYETİ (days=${daysUntilExam}, level=${urgency}): Gün azaldıkça genel tekrar ve deneme ağırlığını artır, yeni konu sayısını kademeli azalt.
// 6) MÜFREDAT UYUMU: Yeni konu açmadan önce gerekli ön koşul konular tamamlanmış olmalı.
// 7) Tüm metinler Türkçe, net ve emir kipinde; gereksiz açıklama yazma.
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
    final base = rules + '\n' + template;
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
    final base = rules + '\n' + template;
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
    final base = rules + '\n' + template;
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
