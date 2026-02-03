// lib/data/repositories/ai_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/models/topic_performance_model.dart';
import 'package:taktik/core/prompts/strategy_consult_prompt.dart';
import 'package:taktik/core/prompts/psych_support_prompt.dart';
import 'package:taktik/core/prompts/motivation_corner_prompt.dart';
import 'package:taktik/core/prompts/trial_review_prompt.dart';
import 'package:taktik/core/prompts/strategy_prompts.dart';
import 'package:taktik/core/prompts/workshop_prompts.dart';
import 'package:taktik/core/prompts/motivation_suite_prompts.dart';
import 'package:taktik/core/prompts/default_motivation_prompts.dart';
import 'package:taktik/features/stats/logic/stats_analysis.dart';
import 'package:taktik/features/stats/logic/stats_analysis_provider.dart';
import 'package:taktik/core/utils/json_text_cleaner.dart';
import 'package:taktik/data/models/performance_summary.dart';
import 'package:taktik/data/models/plan_document.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/data/repositories/exam_schedule.dart';
import 'package:taktik/core/utils/app_info_provider.dart'; // Gerekirse versiyon kontrolü için

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage(this.text, {required this.isUser});
}

final aiServiceProvider = Provider<AiService>((ref) {
  return AiService(ref);
});

class AiService {
  final Ref _ref;
  AiService(this._ref);

  // --- Kalıcı sohbet hafızası (Firestore) ---
  Future<String> _getChatMemory(String userId, String mode) async {
    try {
      final svc = _ref.read(firestoreServiceProvider);
      final snap = await svc.usersCollection.doc(userId).collection('state').doc('ai_memory').get();
      final data = snap.data() ?? const <String, dynamic>{};
      final key = '${mode}_summary';

      final v = data[key];
      if (v is String) return v.trim();

      final g = data['globalSummary'];
      return (g is String) ? g.trim() : '';
    } catch (_) {
      return '';
    }
  }

  // Rolling Window Memory: Son ~8000 karakteri tutar.
  Future<void> _updateChatMemory(
      String userId,
      String mode, {
        required String lastUserMessage,
        required String aiResponse,
        String previous = '',
      }) async {
    try {
      final newTurn = [
        if (lastUserMessage.trim().isNotEmpty) 'Kullanıcı: ${lastUserMessage.trim().replaceAll('\n', ' ')}',
        if (aiResponse.trim().isNotEmpty) 'AI: ${aiResponse.trim().replaceAll('\n', ' ')}',
      ].join(' | ');

      String updatedHistory = previous.trim().isEmpty ? newTurn : '${previous.trim()} | $newTurn';

      const int maxChars = 8000;
      if (updatedHistory.length > maxChars) {
        updatedHistory = updatedHistory.substring(updatedHistory.length - maxChars);
        final firstPipe = updatedHistory.indexOf('|');
        if (firstPipe != -1 && firstPipe < 100) {
          updatedHistory = updatedHistory.substring(firstPipe + 1).trim();
        }
      }

      final svc = _ref.read(firestoreServiceProvider);
      await svc.usersCollection.doc(userId).collection('state').doc('ai_memory').set({
        '${mode}_summary': updatedHistory,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Hata sessizce geçilir
    }
  }

  Future<void> clearChatMemory(String userId, String mode) async {
    try {
      final svc = _ref.read(firestoreServiceProvider);
      await svc.usersCollection.doc(userId).collection('state').doc('ai_memory').update({
        '${mode}_summary': FieldValue.delete(),
      });
    } catch (_) {}
  }

  String _preprocessAiTextForJson(String input) {
    return JsonTextCleaner.cleanString(input);
  }

  String _sanitizePlainText(String input) {
    var out = input;
    out = out.replaceAll('```', '').replaceAll('`', '').replaceAll('**', '').replaceAll('__', '');

    final lines = out.split('\n').map((l) {
      var line = l;
      line = line.replaceFirst(RegExp(r'^\s*[-*•]\s+'), '');
      line = line.replaceFirst(RegExp(r'^\s*#{1,6}\s*'), '');
      line = line.replaceFirst(RegExp(r'^\s*\d+\)\s*'), '');
      return line;
    }).toList();
    out = lines.join('\n');

    out = out.replaceAll(RegExp(r'[ \t]+'), ' ').replaceAll(RegExp(r'\s*\n\s*\n+'), '\n');
    return out.trim();
  }

  String _enforceToneGuard(String input) {
    return input.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
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
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('unexpected end') || errorMsg.contains('unterminated')) {
        return jsonEncode({'error': 'Plan oluşturulurken yanıt yarım kaldı. Lütfen tekrar deneyin veya tempo ayarını "Rahat" seçerek daha kısa bir plan oluşturun.'});
      }
      return jsonEncode({'error': 'Yapay zeka yanıtı anlaşılamadı, lütfen tekrar deneyin.'});
    }
  }

  /// Tamamlanan görev ID'lerini Set olarak döndürür (hızlı arama için)
  Future<Set<String>> _loadRecentCompletedTaskIdsOnly(String userId, {int days = 365}) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      final svc = _ref.read(firestoreServiceProvider);
      final snap = await svc.usersCollection
          .doc(userId)
          .collection('completedTasks')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
          .get();

      final Set<String> taskIds = {};
      for (var doc in snap.docs) {
        final data = doc.data();
        final taskId = data['taskId'] as String?;
        if (taskId != null && taskId.isNotEmpty) {
          taskIds.add(taskId);
        } else {
          taskIds.add(doc.id);
        }
      }
      return taskIds;
    } catch (_) {
      return {};
    }
  }

  // --- Cloud Function Çağrısı ---
  Future<String> _callGemini(
      String prompt, {
        bool expectJson = false,
        double? temperature,
        String? model,
        int retryCount = 0,
        required String requestType,
      }) async {
    const int maxRetries = 3;
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('generateGemini'); // Fonksiyon adı backend ile eşleşmeli
      final payload = {
        'prompt': prompt,
        'expectJson': expectJson,
        'requestType': requestType,
        'temperature': temperature ?? 0.7,
        if (model != null && model.isNotEmpty) 'model': model,
      };

      final result = await callable.call(payload).timeout(const Duration(seconds: 150));
      final data = result.data;
      final rawResponse = (data is Map && data['raw'] is String) ? (data['raw'] as String).trim() : '';

      if (rawResponse.isEmpty) {
        return expectJson ? jsonEncode({'error': 'Boş yanıt alındı'}) : 'Hmm, bir an daldım. Tekrar söyler misin?';
      }

      String? extracted = _extractJsonFromFencedBlock(rawResponse);
      extracted ??= _extractJsonByBracesFallback(rawResponse);
      final candidate = (extracted ?? rawResponse);

      if (expectJson) {
        return _parseAndNormalizeJsonOrError(_preprocessAiTextForJson(candidate));
      }

      return _enforceToneGuard(_sanitizePlainText(rawResponse));
    } on FirebaseFunctionsException catch (e) {
      final isRateLimit = e.code == 'resource-exhausted' || e.code == 'unavailable' || (e.message?.contains('429') ?? false);
      final isQuotaExceeded = e.message?.contains('limitinize') ?? false;

      if (isRateLimit && !isQuotaExceeded && retryCount < maxRetries) {
        final delaySeconds = (retryCount + 1) * 2;
        await Future.delayed(Duration(seconds: delaySeconds));
        return _callGemini(prompt, expectJson: expectJson, temperature: temperature, model: model, requestType: requestType, retryCount: retryCount + 1);
      }

      String msg;
      if (e.code == 'resource-exhausted') {
        msg = e.message ?? 'İstek limitiniz doldu.';
      } else if (isRateLimit) {
        msg = 'AI sistemi çok yoğun. Lütfen birkaç saniye bekleyip tekrar deneyin.';
      } else if (e.code == 'unauthenticated') {
        msg = 'Oturum süresi doldu. Lütfen tekrar giriş yapın.';
      } else if (e.code == 'permission-denied') {
        msg = e.message ?? 'Bu özelliğe erişim izniniz yok.';
      } else {
        msg = 'AI hizmeti hatası. Lütfen tekrar deneyin.';
      }
      return expectJson ? jsonEncode({'error': msg}) : msg;
    } on TimeoutException {
      if (retryCount < maxRetries) {
        final delaySeconds = (retryCount + 1) * 2;
        await Future.delayed(Duration(seconds: delaySeconds));
        return _callGemini(prompt, expectJson: expectJson, temperature: temperature, model: model, requestType: requestType, retryCount: retryCount + 1);
      }
      final msg = 'AI yanıtı çok uzun sürdü. Lütfen tekrar deneyin.';
      return expectJson ? jsonEncode({'error': msg}) : msg;
    } catch (_) {
      final msg = 'Şu an bağlantıda bir sorun var sanırım. Birazdan tekrar deneyelim mi?';
      return expectJson ? jsonEncode({'error': msg}) : msg;
    }
  }

  int _getDaysUntilExam(ExamType examType) {
    return ExamSchedule.daysUntilExam(examType);
  }

  /// 🚀 CORE FONKSİYON: HAFTALIK PLANLAMA
  /// Bu fonksiyon backend'deki optimizasyona güvenerek çalışır.
  /// Prompt'a ham test verisi eklenmez, requestType='weekly_plan' ile backend uyarılır.
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

    // Hızlı yerel istatistik (Prompt içinde placeholder olarak kullanılırsa diye)
    final String avgNet = _quickAverageNet(tests).toStringAsFixed(2);
    final Map<String, double> subjectAverages = _computeSubjectAveragesQuick(tests);

    final availabilityJson = jsonEncode(user.weeklyAvailability);

    // Tamamlanan konu ID'lerini al (Müfredat filtreleme için)
    final completedTopicIds = await _loadRecentCompletedTaskIdsOnly(user.id, days: 365);

    // AI'a sadece "Sıradaki Aday Konular" gönderilir (Token tasarrufu)
    final candidateTopicsJson = await _buildNextStudyTopicsJson(
        examType,
        user.selectedExamSection,
        completedTopicIds
    );

    // Guardrails: Kullanıcının sıkışıp sıkışmadığını kontrol et
    final guardrailsJson = _buildGuardrailsJson(planDoc?.weeklyPlan, completedTopicIds, performance);

    String prompt;
    switch (examType) {
      case ExamType.yks:
        String displaySection = user.selectedExamSection ?? '';
        if (displaySection == 'YDT') {
          displaySection = 'TYT ve YDT';
        }

        prompt = StrategyPrompts.getYksPrompt(
            userId: user.id, selectedExamSection: displaySection,
            daysUntilExam: daysUntilExam, pacing: pacing,
            testCount: user.testCount, avgNet: avgNet,
            subjectAverages: subjectAverages,
            availabilityJson: availabilityJson,
            curriculumJson: candidateTopicsJson,
            guardrailsJson: guardrailsJson,
            revisionRequest: revisionRequest
        );
        break;
      case ExamType.lgs:
        prompt = StrategyPrompts.getLgsPrompt(
            user: user,
            avgNet: avgNet, subjectAverages: subjectAverages,
            pacing: pacing, daysUntilExam: daysUntilExam,
            availabilityJson: availabilityJson,
            curriculumJson: candidateTopicsJson,
            guardrailsJson: guardrailsJson,
            revisionRequest: revisionRequest
        );
        break;
      case ExamType.ags:
        prompt = StrategyPrompts.getAgsPrompt(
            user: user,
            avgNet: avgNet, subjectAverages: subjectAverages,
            pacing: pacing, daysUntilExam: daysUntilExam,
            availabilityJson: availabilityJson,
            curriculumJson: candidateTopicsJson,
            guardrailsJson: guardrailsJson,
            revisionRequest: revisionRequest
        );
        break;
      default:
        prompt = StrategyPrompts.getKpssPrompt(
            user: user,
            avgNet: avgNet, subjectAverages: subjectAverages,
            pacing: pacing, daysUntilExam: daysUntilExam,
            availabilityJson: availabilityJson,
            examName: examType.displayName,
            curriculumJson: candidateTopicsJson,
            guardrailsJson: guardrailsJson,
            revisionRequest: revisionRequest
        );
        break;
    }

    // AI önbellek kırıcı
    prompt += "\n\n[System: Generate a UNIQUE plan. Variation: ${DateTime.now().millisecondsSinceEpoch}]";
    prompt += "\n\nÖNEMLİ: Yanıtını mutlaka geçerli ve KAPALI bir JSON objesi olarak döndür. JSON'un sonunda tüm süslü parantezleri kapat.";

    // Gün sıralaması düzeltmesi (Planı bugünden başlat)
    final trDays = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    final todayIndex = DateTime.now().weekday - 1;
    final todayName = trDays[todayIndex];
    List<String> orderedDays = [];
    for(int i=0; i<7; i++) {
      orderedDays.add(trDays[(todayIndex + i) % 7]);
    }
    final orderString = orderedDays.join(', ');

    prompt += """

[SİSTEM AYARI 1: TAKVİM YAPISI]
Bugün günlerden: $todayName.
Lütfen oluşturacağın 'weeklyPlan' içindeki 'plan' dizisini KESİNLİKLE **$todayName** gününden başlat.
Plan dizisindeki günlerin sırası tam olarak şu sırayla olmalıdır: $orderString.
""";

    // Kapasite ve doluluk talimatı
    String densityInstruction = "";
    if (pacing == 'intense' || pacing == 'yoğun') {
      densityInstruction = """

[SİSTEM AYARI 2: KAPASİTE VE DOLULUK (CRITICAL)]
Kullanıcı Modu: **INTENSE (YOĞUN)**.
'weeklyAvailability' içinde "true" olan **HER BİR SAAT DİLİMİNİ** doldur. Boşluk bırakma.
Konu biterse soru çözümü veya tekrar ekle. HEDEF DOLULUK: %100.
""";
    } else if (pacing == 'moderate' || pacing == 'dengeli') {
      densityInstruction = """
[SİSTEM AYARI 2: KAPASİTE]
Kullanıcı Modu: **MODERATE (DENGELİ)**.
Müsait zamanların %80'ini doldur.
""";
    } else {
      densityInstruction = """
[SİSTEM AYARI 2: KAPASİTE]
Kullanıcı Modu: **RELAXED (RAHAT)**.
Müsait zamanın %50-60'ını doldurman yeterli.
""";
    }
    prompt += densityInstruction;

    // Backend'e 'weekly_plan' tipinde istek gönderiyoruz. Backend veriyi kendisi çekip prompt'a ekleyecek.
    return _callGemini(prompt, expectJson: true, requestType: 'weekly_plan');
  }

  /// Müfredattan sıradaki konuları seçer (Token tasarrufu)
  Future<String> _buildNextStudyTopicsJson(
      ExamType examType,
      String? selectedSection,
      Set<String> completedTopicIds
      ) async {
    try {
      final exam = await ExamData.getExamByType(examType);
      List<ExamSection> sections = [];

      if (examType == ExamType.ags) {
        sections.addAll(exam.sections.where((s) => s.name == 'AGS'));
        if (selectedSection != null && selectedSection.isNotEmpty) {
          sections.addAll(exam.sections.where((s) => s.name.toLowerCase() == selectedSection.toLowerCase()));
        }
      } else if (examType == ExamType.yks) {
        sections.addAll(exam.sections.where((s) => s.name == 'TYT'));
        if (selectedSection != null && selectedSection.isNotEmpty && selectedSection != 'TYT') {
          sections.addAll(exam.sections.where((s) => s.name.toLowerCase() == selectedSection.toLowerCase()));
        }
      } else {
        sections = (selectedSection != null && selectedSection.isNotEmpty)
            ? exam.sections.where((s) => s.name.toLowerCase() == selectedSection.toLowerCase()).toList()
            : exam.sections;
      }

      final Map<String, List<String>> candidateTopics = {};

      for (final sec in sections) {
        sec.subjects.forEach((subjectName, subjectDetails) {
          final allTopics = subjectDetails.topics.map((t) => t.name).toList();
          final remainingTopics = allTopics.where((t) => !completedTopicIds.contains(t)).toList();
          if (remainingTopics.isEmpty) return;

          // Her dersten sıradaki 3 konuyu al
          final nextBatch = remainingTopics.take(3).toList();
          candidateTopics[subjectName] = nextBatch;
        });
      }

      return jsonEncode({
        'candidates': candidateTopics,
        'note': 'Sadece bu listedeki konuları planlayabilirsin. Müfredat sırasını takip et.'
      });
    } catch (e) {
      return jsonEncode({
        'candidates': {},
        'note': 'Müfredat yüklenemedi, genel konulardan plan oluştur.'
      });
    }
  }

  String _buildGuardrailsJson(Map<String, dynamic>? weeklyPlanRaw, Set<String> completedTopicIds, PerformanceSummary performance){
    final backlogActivities = <String>[];
    if (weeklyPlanRaw != null) {
      try {
        final planList = (weeklyPlanRaw['plan'] as List? ) ?? const [];
        for (final day in planList) {
          if (day is Map && day['schedule'] is List) {
            for (final item in (day['schedule'] as List)) {
              if (item is Map) {
                final time = (item['time'] ?? '').toString();
                final activity = (item['activity'] ?? '').toString();
                final id = '$time-$activity';
                if (!completedTopicIds.contains(id)) {
                  backlogActivities.add(activity);
                }
              } else if (item is String) {
                final id = 'Görev-$item';
                if (!completedTopicIds.contains(id)) backlogActivities.add(item);
              }
            }
          }
        }
      } catch (_) {}
    }

    final topicStatus = <String, Map<String, dynamic>>{};
    int redCount = 0;
    performance.topicPerformances.forEach((subject, topics){
      final map = <String, String>{};
      topics.forEach((topic, tp){
        final attempts = tp.correctCount + tp.wrongCount;
        String status;
        if (tp.questionCount < 8 || attempts < 6) {
          status = 'unknown';
        } else {
          final denom = attempts == 0 ? 1 : attempts;
          final acc = tp.correctCount / denom;
          if (acc < 0.5 || tp.wrongCount >= tp.correctCount) { status = 'red'; redCount++; }
          else if (acc < 0.7) { status = 'yellow'; }
          else { status = 'green'; }
        }
        map[topic] = status;
      });
      if (map.isNotEmpty) topicStatus[subject] = map;
    });

    final bool isOverwhelmed = backlogActivities.length >= 3 || redCount >= 2;

    final policy = <String, dynamic>{
      'allowNewTopics': !isOverwhelmed,
      'priorities': isOverwhelmed
          ? ['backlog', 'red', 'yellow', 'curriculum']
          : ['curriculum', 'yellow', 'backlog', 'red'],
      'notes': isOverwhelmed
          ? 'Kullanıcı geride kalmaya başladı (Yığılma var). Yeni konu açma, öncelik borçları temizlemek.'
          : 'Durum stabil. Ufak eksikleri araya sıkıştır ama ana odak müfredatta ilerlemek olsun.'
    };

    return jsonEncode({
      'backlogCount': backlogActivities.length,
      'backlogSample': backlogActivities.take(5).toList(),
      'topicStatus': topicStatus,
      'policy': policy,
    });
  }

  Future<String> generateStudyGuideAndQuiz(
      UserModel user,
      List<TestModel> tests,
      PerformanceSummary performance, {
        Map<String, String>? topicOverride,
        String difficulty = 'normal',
        int attemptCount = 1,
        double? temperature,
        dynamic contentType,
      }) async {
    if (tests.isEmpty) {
      final hasTopicData = performance.topicPerformances.values.any((subjectMap) => subjectMap.values.any((t) => (t.questionCount ?? 0) > 0));
      if (!hasTopicData && topicOverride == null) {
        return '{"error":"Analiz için en az bir deneme sonucu gereklidir."}';
      }
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
      final cachedAnalysis = _ref.read(overallStatsAnalysisProvider).value;
      final info = cachedAnalysis?.getWeakestTopicWithDetails();
      if (info != null) {
        weakestSubject = info['subject']!;
        weakestTopic = info['topic']!;
      } else {
        final examType = ExamType.values.byName(user.selectedExam!);
        final examData = await ExamData.getExamByType(examType);
        final analysis = StatsAnalysis(tests, examData, _ref.read(firestoreServiceProvider), user: user);
        final weakestTopicInfo = analysis.getWeakestTopicWithDetails();

        if (weakestTopicInfo == null) {
          return '{"error":"Analiz için zayıf bir konu bulunamadı."}';
        }
        weakestSubject = weakestTopicInfo['subject']!;
        weakestTopic = weakestTopicInfo['topic']!;
      }
    }

    String contentTypeStr = 'both';
    if (contentType != null) {
      contentTypeStr = contentType.toString().split('.').last;
    }

    final prompt = getStudyGuideAndQuizPrompt(
      weakestSubject,
      weakestTopic,
      user.selectedExam,
      difficulty,
      attemptCount,
      contentType: contentTypeStr,
    );

    return _callGemini(prompt, expectJson: true, temperature: temperature, requestType: 'workshop');
  }

  Future<String> getPersonalizedMotivation({
    required UserModel user,
    required List<TestModel> tests,
    required PerformanceSummary performance,
    required String promptType,
    required String? emotion,
    Map<String, dynamic>? workshopContext,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) async {
    final examType = user.selectedExam != null ? ExamType.values.byName(user.selectedExam!) : null;
    final analysis = _ref.read(overallStatsAnalysisProvider).value;

    final bool shouldUseMemory = ['strategy_consult', 'psych_support', 'user_chat', 'trial_review', 'motivation_corner'].contains(promptType);

    String historyToUse = conversationHistory;
    String mem = '';
    if (shouldUseMemory && historyToUse.trim().isEmpty) {
      mem = await _getChatMemory(user.id, promptType);
      historyToUse = mem;
    }

    String prompt;
    double chatTemperature = 0.75;

    switch (promptType) {
      case 'trial_review':
        prompt = TrialReviewPrompt.build(
          user: user,
          tests: tests,
          analysis: analysis,
          performance: performance,
          examName: examType?.displayName,
          conversationHistory: historyToUse,
          lastUserMessage: lastUserMessage,
        );
        chatTemperature = 0.65;
        break;
      case 'strategy_consult':
        prompt = StrategyConsultPrompt.build(
          user: user,
          tests: tests,
          analysis: analysis,
          performance: performance,
          examName: examType?.displayName,
          conversationHistory: historyToUse,
          lastUserMessage: lastUserMessage,
        );
        chatTemperature = 0.6;
        break;
      case 'psych_support':
        prompt = PsychSupportPrompt.build(
          user: user,
          examName: examType?.displayName,
          emotion: emotion,
          conversationHistory: historyToUse,
          lastUserMessage: lastUserMessage,
        );
        chatTemperature = 1.0;
        break;
      case 'motivation_corner':
        prompt = MotivationCornerPrompt.build(
          user: user,
          examName: examType?.displayName,
          conversationHistory: historyToUse,
          lastUserMessage: lastUserMessage,
        );
        chatTemperature = 0.95;
        break;
      default:
        prompt = DefaultMotivationPrompts.userChat(
          user: user,
          tests: tests,
          analysis: analysis,
          examName: examType?.displayName,
          conversationHistory: historyToUse,
          lastUserMessage: lastUserMessage,
        );
        break;
    }

    final raw = await _callGemini(
      prompt,
      expectJson: false,
      temperature: chatTemperature,
      requestType: 'chat',
    );

    if (shouldUseMemory) {
      unawaited(
        _updateChatMemory(
          user.id,
          promptType,
          lastUserMessage: lastUserMessage,
          aiResponse: raw,
          previous: mem,
        ),
      );
    }

    return raw;
  }

  double _quickAverageNet(List<TestModel> tests) {
    if (tests.isEmpty) return 0.0;
    final total = tests.fold<double>(0.0, (acc, t) => acc + t.totalNet);
    return total / tests.length;
  }

  Map<String, double> _computeSubjectAveragesQuick(List<TestModel> tests) {
    if (tests.isEmpty) return {};
    final Map<String, List<double>> subjectNets = {};
    for (final t in tests) {
      t.scores.forEach((subject, scores) {
        final net = (scores['dogru'] ?? 0) - ((scores['yanlis'] ?? 0) * t.penaltyCoefficient);
        subjectNets.putIfAbsent(subject, () => []).add(net);
      });
    }
    return subjectNets.map((k, v) => MapEntry(k, v.isEmpty ? 0.0 : v.reduce((a, b) => a + b) / v.length));
  }

  Future<Map<String, dynamic>> computeGuardrailsForDisplay({
    required PlanDocument? planDoc,
    required PerformanceSummary performance,
    int daysWindow = 28,
  }) async {
    final user = _ref.read(userProfileProvider).value;
    if (user == null) return {};
    final completedTaskIds = await _loadRecentCompletedTaskIdsOnly(user.id, days: daysWindow);
    final guardrailsJson = _buildGuardrailsJson(planDoc?.weeklyPlan, completedTaskIds, performance);
    try {
      final decoded = jsonDecode(guardrailsJson);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }
}