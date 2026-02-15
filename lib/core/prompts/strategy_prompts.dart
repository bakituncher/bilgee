// lib/core/prompts/strategy_prompts.dart
import 'dart:convert';
import 'dart:async'; // Future.wait için gerekli
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart'; // Debug logları için
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/core/prompts/prompt_remote.dart';

class StrategyPrompts {
  static String? _yksTemplate;
  static String? _lgsTemplate;
  static String? _kpssTemplate;
  static String? _agsTemplate;

  /// Uygulama açılışında çağrılır (main.dart)
  static Future<void> preload() async {
    try {
      // Future.wait ile tüm dosyaları aynı anda (paralel) okuyoruz.
      // Bu, uygulama açılışını hızlandırır ve Firestore'a gitmez.
      await Future.wait([
        _load('yks_prompt', 'assets/prompts/yks_prompt.md').then((v) => _yksTemplate = v),
        _load('lgs_prompt', 'assets/prompts/lgs_prompt.md').then((v) => _lgsTemplate = v),
        _load('kpss_prompt', 'assets/prompts/kpss_prompt.md').then((v) => _kpssTemplate = v),
        _load('ags_prompt', 'assets/prompts/ags_prompt.md').then((v) => _agsTemplate = v),
      ]);
    } catch (e) {
      debugPrint('⚠️ StrategyPrompts Yükleme Hatası: $e');
      // Kritik hata: Eğer dosyalar yüklenemezse varsayılan boş string atanabilir
      // ancak production'da assets klasöründe dosyalar olduğu sürece buraya düşmez.
    }
  }

  /// Önce RemotePrompts'a bakar (eğer ileride açarsanız), yoksa Asset'ten okur.
  static Future<String> _load(String key, String path) async {
    final cached = RemotePrompts.get(key);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    return await rootBundle.loadString(path);
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
    // Eğer preload hata verdiyse veya çağrılmadıysa güvenli bir hata mesajı veya boş dön
    if (_yksTemplate == null) {
      debugPrint('HATA: YKS Prompt şablonu yüklenmemiş. Lütfen uygulamayı yeniden başlatın.');
      return '';
    }

    final template = _yksTemplate!;
    final currentDate = DateTime.now().toIso8601String();
    final currentWeek = '1';

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
    if (_lgsTemplate == null) return '';

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
    if (_kpssTemplate == null) return '';

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
    if (_agsTemplate == null) return '';

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