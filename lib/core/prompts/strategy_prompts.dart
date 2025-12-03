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
    // Önce Firestore'daki uzaktan içerikleri dene; yoksa asset'e geri dön
    _yksTemplate = RemotePrompts.get('yks_prompt') ?? await rootBundle.loadString('assets/prompts/yks_prompt.md');
    _lgsTemplate = RemotePrompts.get('lgs_prompt') ?? await rootBundle.loadString('assets/prompts/lgs_prompt.md');
    _kpssTemplate = RemotePrompts.get('kpss_prompt') ?? await rootBundle.loadString('assets/prompts/kpss_prompt.md');
  }

  static String _revisionBlock(String? revisionRequest) {
    if (revisionRequest != null && revisionRequest.isNotEmpty) {
      return """

## ⚠️ KRİTİK REVİZYON TALEBİ

**KULLANICI MEVCUT PLANDAN MEMNUN DEĞİL!**

Kullanıcının Geri Bildirimi:
"$revisionRequest"

**AKSİYON:**
1. Yukarıdaki geri bildirimi DİKKATLE oku
2. Planı TAMAMEN YENİDEN oluştur
3. Önceki planı ASLA tekrarlama
4. Kullanıcı talebini MERKEZE al
5. Tüm günleri YENİDEN düzenle

NOT: Bu bir revizyon talebidir, önceki planı unutun!
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

  // ✅ Hafta numarasını dinamik hesapla: Eğer weeklyPlanJson varsa ve creationDate içeriyorsa
  // eski planın tarihine göre kaç hafta geçtiğini hesapla
  static String _calculateCurrentWeek(String? weeklyPlanJson) {
    if (weeklyPlanJson == null || weeklyPlanJson.isEmpty || weeklyPlanJson.contains('YOK')) {
      return '1'; // İlk hafta
    }

    try {
      final decoded = jsonDecode(weeklyPlanJson);
      if (decoded is Map && decoded.containsKey('creationDate')) {
        final creationDate = DateTime.parse(decoded['creationDate']);
        final now = DateTime.now();
        final weeksPassed = now.difference(creationDate).inDays ~/ 7;
        return (weeksPassed + 1).toString(); // Şu anki hafta = geçen haftalar + 1
      }
    } catch (_) {
      // Parse hatası olursa varsayılan
    }

    return '1'; // Varsayılan: 1. hafta
  }

  // Rules block artık yeni prompt dosyalarında var, burada gereksiz

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
    final currentDate = DateTime.now().toIso8601String();
    final currentWeek = _calculateCurrentWeek(weeklyPlanJson); // 👈 Dinamik hafta
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
      'CURRICULUM_JSON': curriculumJson,
      'GUARDRAILS_JSON': guardrailsJson,
      'CURRENT_DATE': currentDate,
      'CURRENT_WEEK': currentWeek, // 👈 Hafta numarası prompt'a gidiyor
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
    required String completedTasksJson,
    required String curriculumJson,
    required String guardrailsJson,
    String? revisionRequest,
  }) {
    assert(_lgsTemplate != null, 'StrategyPrompts.preload() çağrılmalı');
    final template = _lgsTemplate!;
    final currentDate = DateTime.now().toIso8601String();
    final currentWeek = _calculateCurrentWeek(weeklyPlanJson); // 👈 Dinamik hafta
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
      'COMPLETED_TASKS_JSON': completedTasksJson,
      'CURRICULUM_JSON': curriculumJson,
      'GUARDRAILS_JSON': guardrailsJson,
      'CURRENT_DATE': currentDate,
      'CURRENT_WEEK': currentWeek, // 👈 Hafta numarası prompt'a gidiyor
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
    required String completedTasksJson,
    required String curriculumJson,
    required String guardrailsJson,
    String? revisionRequest,
  }) {
    assert(_kpssTemplate != null, 'StrategyPrompts.preload() çağrılmalı');
    final template = _kpssTemplate!;
    final currentDate = DateTime.now().toIso8601String();
    final currentWeek = _calculateCurrentWeek(weeklyPlanJson); // 👈 Dinamik hafta
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
      'COMPLETED_TASKS_JSON': completedTasksJson,
      'CURRICULUM_JSON': curriculumJson,
      'GUARDRAILS_JSON': guardrailsJson,
      'CURRENT_DATE': currentDate,
      'CURRENT_WEEK': currentWeek, // 👈 Hafta numarası prompt'a gidiyor
    };
    return _fillTemplate(template, replacements);
  }
}
