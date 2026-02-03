// lib/core/prompts/strategy_prompts.dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:taktik/core/prompts/prompt_remote.dart';

class StrategyPrompts {
  static String? _yksTemplate;
  static String? _lgsTemplate;
  static String? _kpssTemplate;
  static String? _agsTemplate;

  /// Prompt şablonlarını önbelleğe alır (Remote Config veya Local Asset)
  static Future<void> preload() async {
    _yksTemplate = RemotePrompts.get('yks_prompt') ?? await rootBundle.loadString('assets/prompts/yks_prompt.md');
    _lgsTemplate = RemotePrompts.get('lgs_prompt') ?? await rootBundle.loadString('assets/prompts/lgs_prompt.md');
    _kpssTemplate = RemotePrompts.get('kpss_prompt') ?? await rootBundle.loadString('assets/prompts/kpss_prompt.md');
    _agsTemplate = RemotePrompts.get('ags_prompt') ?? await rootBundle.loadString('assets/prompts/ags_prompt.md');
  }

  /// Revizyon talebi varsa prompt'un en başına eklenir.
  static String _revisionBlock(String? revisionRequest) {
    if (revisionRequest != null && revisionRequest.isNotEmpty) {
      return """
\n
⚠️ **REVİZYON TALEBİ (ÖNEMLİ)**
Kullanıcı mevcut plandan memnun değil ve şu değişikliği istiyor:
"$revisionRequest"

Lütfen bu isteği önceliklendirerek planı GÜNCELLE.
\n
""";
    }
    return '';
  }

  static String _fillTemplate(String template, Map<String, String> values) {
    String out = template;
    values.forEach((k, v) {
      // Değer null ise boş string, değilse kendisi
      out = out.replaceAll('{{$k}}', v);
    });
    return out;
  }

  // --- YKS PROMPT ---
  // Not: Artık istatistikler (Netler, Test Sayısı vb.) buradan gitmiyor.
  // Backend (ai.js) bunları analiz edip ekliyor.
  static String getYksPrompt({
    required String selectedExamSection, // Örn: SAYISAL, EŞİT AĞIRLIK
    required int daysUntilExam,
    required String pacing, // Örn: Yoğun, Dengeli
    required String availabilityJson, // Günlük müsaitlik saatleri
    String? revisionRequest,
  }) {
    assert(_yksTemplate != null, 'StrategyPrompts.preload() çağrılmalı');
    final template = _yksTemplate!;
    final currentDate = DateTime.now().toIso8601String();

    final replacements = <String, String>{
      'REVISION_BLOCK': _revisionBlock(revisionRequest),
      'AVAILABILITY_JSON': availabilityJson,
      'SELECTED_EXAM_SECTION': selectedExamSection,
      'DAYS_UNTIL_EXAM': daysUntilExam.toString(),
      'PACING': pacing,
      'CURRENT_DATE': currentDate,
      // Backend tarafından analiz edildiği için aşağıdaki veri alanları kaldırıldı:
      // USER_ID, TEST_COUNT, AVG_NET, SUBJECT_AVERAGES, CURRICULUM_JSON, GUARDRAILS_JSON
    };
    return _fillTemplate(template, replacements);
  }

  // --- LGS PROMPT ---
  static String getLgsPrompt({
    required String pacing,
    required int daysUntilExam,
    required String availabilityJson,
    String? revisionRequest,
  }) {
    assert(_lgsTemplate != null, 'StrategyPrompts.preload() çağrılmalı');
    final template = _lgsTemplate!;
    final currentDate = DateTime.now().toIso8601String();

    final replacements = <String, String>{
      'REVISION_BLOCK': _revisionBlock(revisionRequest),
      'AVAILABILITY_JSON': availabilityJson,
      'DAYS_UNTIL_EXAM': daysUntilExam.toString(),
      'PACING': pacing,
      'CURRENT_DATE': currentDate,
    };
    return _fillTemplate(template, replacements);
  }

  // --- KPSS PROMPT ---
  static String getKpssPrompt({
    required String examName, // Örn: KPSS Lisans
    required String pacing,
    required int daysUntilExam,
    required String availabilityJson,
    String? revisionRequest,
  }) {
    assert(_kpssTemplate != null, 'StrategyPrompts.preload() çağrılmalı');
    final template = _kpssTemplate!;
    final currentDate = DateTime.now().toIso8601String();

    final replacements = <String, String>{
      'REVISION_BLOCK': _revisionBlock(revisionRequest),
      'AVAILABILITY_JSON': availabilityJson,
      'EXAM_NAME': examName,
      'DAYS_UNTIL_EXAM': daysUntilExam.toString(),
      'PACING': pacing,
      'CURRENT_DATE': currentDate,
    };
    return _fillTemplate(template, replacements);
  }

  // --- AGS PROMPT ---
  static String getAgsPrompt({
    required String pacing,
    required int daysUntilExam,
    required String availabilityJson,
    String? revisionRequest,
  }) {
    assert(_agsTemplate != null, 'StrategyPrompts.preload() çağrılmalı');
    final template = _agsTemplate!;
    final currentDate = DateTime.now().toIso8601String();

    final replacements = <String, String>{
      'REVISION_BLOCK': _revisionBlock(revisionRequest),
      'AVAILABILITY_JSON': availabilityJson,
      'DAYS_UNTIL_EXAM': daysUntilExam.toString(),
      'PACING': pacing,
      'CURRENT_DATE': currentDate,
    };
    return _fillTemplate(template, replacements);
  }
}