// lib/data/repositories/ai_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/models/topic_performance_model.dart';
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

  // --- Kalıcı sohbet hafızası (Firestore) ---
  Future<String> _getChatMemory(String userId, String mode) async {
    try {
      final svc = _ref.read(firestoreServiceProvider);
      final snap = await svc.usersCollection.doc(userId).collection('state').doc('ai_memory').get();
      final data = snap.data() ?? const <String, dynamic>{};
      final key = '${mode}_summary';
      final v = data[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      final g = data['globalSummary'];
      return (g is String) ? g.trim() : '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _updateChatMemory(String userId, String mode, {required String lastUserMessage, required String aiResponse, String previous = ''}) async {
    try {
      // AKILLI ÖZET: Önceki özet + son tur (Kullanıcı/AI), başlangıcı ve sonu koruyarak ~1200 karaktere indir.
      final newTurn = [
        if (lastUserMessage.trim().isNotEmpty) 'Kullanıcı: ${lastUserMessage.trim().replaceAll('\n', ' ')}',
        if (aiResponse.trim().isNotEmpty) 'AI: ${aiResponse.trim().replaceAll('\n', ' ')}',
      ].join(' | ');

      String updatedHistory = previous.trim().isEmpty ? newTurn : '${previous.trim()} | $newTurn';

      const int maxChars = 1200;
      if (updatedHistory.length > maxChars) {
        const int preserveStart = 300;
        const int preserveEnd = maxChars - preserveStart - 5; // " ... " için 5 karakter
        if (preserveEnd > 0) {
          final start = updatedHistory.substring(0, preserveStart);
          final end = updatedHistory.substring(updatedHistory.length - preserveEnd);
          updatedHistory = '$start ... $end';
        } else {
          // Eğer maxChars çok küçükse, sadece sonu al.
          updatedHistory = updatedHistory.substring(updatedHistory.length - maxChars);
        }
      }

      final svc = _ref.read(firestoreServiceProvider);
      await svc.usersCollection.doc(userId).collection('state').doc('ai_memory').set({
        '${mode}_summary': updatedHistory,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // sessiz geç
    }
  }

  String _preprocessAiTextForJson(String input) {
    return JsonTextCleaner.cleanString(input);
  }

  // YENI: Düz metin sanitizasyonu (markdown ve madde işaretlerini temizle)
  String _sanitizePlainText(String input) {
    var out = input;
    // code-fence ve backtick temizliği
    out = out.replaceAll('```', '');
    out = out.replaceAll('`', '');
    // kalın/italik vurguları kaldır (** __ * _)
    out = out.replaceAll('**', '');
    out = out.replaceAll('__', '');
    out = out.replaceAllMapped(RegExp(r"(^|\s)[*_]([^*_]+)[*_](?=\s|\.|,|!|\?|$)"), (match) => '${match.group(1)}${match.group(2)}');
    // Satır başındaki madde işaretleri (-, *, •, # başlık, 1) 2) ..) kaldır
    final lines = out.split('\n').map((l) {
      var line = l;
      line = line.replaceFirst(RegExp(r'^\s*[-*•]\s+'), '');
      line = line.replaceFirst(RegExp(r'^\s*#{1,6}\s*'), '');
      line = line.replaceFirst(RegExp(r'^\s*\d+\)\s*'), '');
      return line;
    }).toList();
    out = lines.join('\n');
    // Fazla boşluk ve boş satırları sadeleştir
    out = out.replaceAll(RegExp(r'[ \t]+'), ' ').replaceAll(RegExp(r'\s*\n\s*\n+'), '\n');
    return out.trim();
  }

  // YENI: Koçvari üslubu korumak için bazı ifadeleri nötralize et
  String _enforceToneGuard(String input) {
    var out = input;
    final replacements = <RegExp, String>{
      RegExp(r'küçük hedef(?:ler)?', caseSensitive: false): 'kararlı ilerleme',
      RegExp(r'mikro\s+(görev|adım|hedef|ödül)', caseSensitive: false): 'kararlı ilerleme',
      RegExp(r'mini\s+(görev|hedef|ödül)', caseSensitive: false): 'kararlı ilerleme',
      RegExp(r'küçük\s+ödül', caseSensitive: false): '',
      RegExp(r'\bstreak\b', caseSensitive: false): 'seri',
    };
    replacements.forEach((k, v) => out = out.replaceAll(k, v));
    // Temizlemeden sonra fazla boşlukları toparla
    out = out.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return out;
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

  Future<String> _callGemini(String prompt, {bool expectJson = false, double? temperature, String? model}) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('ai-generateGemini');
      final payload = {
        'prompt': prompt,
        'expectJson': expectJson,
        if (model != null && model.isNotEmpty) 'model': model,
      };
      if (temperature != null) {
        payload['temperature'] = temperature;
      }
      final result = await callable.call(payload).timeout(const Duration(seconds: 70));
      final data = result.data;
      final rawResponse = (data is Map && data['raw'] is String) ? (data['raw'] as String).trim() : '';
      if (rawResponse.isEmpty) {
        return expectJson ? jsonEncode({'error': 'Boş yanıt alındı'}) : 'Hata: Boş yanıt alındı';
      }
      String? extracted = _extractJsonFromFencedBlock(rawResponse);
      extracted ??= _extractJsonByBracesFallback(rawResponse);
      String candidate = (extracted ?? rawResponse);
      final cleaned = _preprocessAiTextForJson(candidate);
      if (expectJson) {
        return _parseAndNormalizeJsonOrError(cleaned);
      }
      final plain = _sanitizePlainText(cleaned.isNotEmpty ? cleaned : rawResponse);
      final guarded = _enforceToneGuard(plain);
      return guarded.isNotEmpty ? guarded : _enforceToneGuard(_sanitizePlainText(rawResponse));
    } on FirebaseFunctionsException catch (e) {
      final msg = 'Sunucu hata: ${e.code} ${e.message ?? ''}'.trim();
      return expectJson ? jsonEncode({'error': msg}) : 'Hata: $msg';
    } catch (e) {
      final msg = 'Sunucuya erişilemedi: ${e.toString()}';
      return expectJson ? jsonEncode({'error': msg}) : 'Hata: $msg';
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

  Future<String> generateStudyGuideAndQuiz(UserModel user, List<TestModel> tests, PerformanceSummary performance, {Map<String, String>? topicOverride, String difficulty = 'normal', int attemptCount = 1, double? temperature}) async {
    // Eğer test yoksa hemen hata döndürme: bazı yeni hesaplarda konu performansı (ör. manuel veri) olabilir.
    if (tests.isEmpty) {
      final hasTopicData = performance.topicPerformances.values.any((subjectMap) => subjectMap.values.any((t) => (t.questionCount ?? 0) > 0));
      if (!hasTopicData && topicOverride == null) {
        return '{"error":"Analiz için en az bir deneme sonucu gereklidir."}';
      }
      // tests boş ama konu performansı varsa devam et; AI yine zayıf konuyu bulmaya çalışır.
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

    // temperature parametresini _callGemini'ye geçir
    return _callGemini(prompt, expectJson: true, temperature: temperature);
  }

  Future<String> getPersonalizedMotivation({
    required UserModel user,
    required List<TestModel> tests,
    required PerformanceSummary performance,
    required String promptType,
    required String? emotion,
    Map<String, dynamic>? workshopContext,
    // YENI: sohbet geçmişi ve son kullanıcı mesajı
    String conversationHistory = '',
    String lastUserMessage = '',
  }) async {
    final examType = user.selectedExam != null ? ExamType.values.byName(user.selectedExam!) : null;
    // KALDIRILDI: examData kullanılmıyordu
    // Önbellekli analiz (varsa)
    final analysis = _ref.read(overallStatsAnalysisProvider).value;

    // Kalıcı bellek: mod bazlı kısa özet yükle ve mevcut geçmişle birleştir
    final mem = await _getChatMemory(user.id, promptType);
    final combinedHistory = [
      if (mem.trim().isNotEmpty) mem.trim(),
      if (conversationHistory.trim().isNotEmpty) conversationHistory.trim(),
    ].join(mem.isNotEmpty && conversationHistory.isNotEmpty ? ' | ' : '');

    // Yeni: Dört mod için özel promptlar + default akışın modüler hali
    String prompt;
    int maxSentences = 3;
    switch (promptType) {
      case 'trial_review':
        prompt = MotivationSuitePrompts.trialReview(
          user: user,
          tests: tests,
          analysis: analysis,
          performance: performance,
          examName: examType?.displayName,
          conversationHistory: combinedHistory,
          lastUserMessage: lastUserMessage,
        );
        maxSentences = 5;
        break;
      case 'strategy_consult':
        prompt = MotivationSuitePrompts.strategyConsult(
          user: user,
          tests: tests,
          analysis: analysis,
          performance: performance,
          examName: examType?.displayName,
          conversationHistory: combinedHistory,
          lastUserMessage: lastUserMessage,
        );
        maxSentences = 5;
        break;
      case 'psych_support':
        prompt = MotivationSuitePrompts.psychSupport(
          user: user,
          examName: examType?.displayName,
          emotion: emotion,
          conversationHistory: combinedHistory,
          lastUserMessage: lastUserMessage,
        );
        maxSentences = 5;
        break;
      case 'motivation_corner':
        prompt = MotivationSuitePrompts.motivationCorner(
          user: user,
          examName: examType?.displayName,
          conversationHistory: combinedHistory,
          lastUserMessage: lastUserMessage,
        );
        maxSentences = 5;
        break;
      case 'welcome':
        prompt = DefaultMotivationPrompts.welcome(
          user: user,
          tests: tests,
          analysis: analysis,
          examName: examType?.displayName,
          conversationHistory: combinedHistory,
          lastUserMessage: lastUserMessage,
        );
        break;
      case 'new_test_bad':
        prompt = DefaultMotivationPrompts.newTestBad(
          user: user,
          tests: tests,
          analysis: analysis,
          examName: examType?.displayName,
          conversationHistory: combinedHistory,
          lastUserMessage: lastUserMessage,
        );
        break;
      case 'new_test_good':
        prompt = DefaultMotivationPrompts.newTestGood(
          user: user,
          tests: tests,
          analysis: analysis,
          examName: examType?.displayName,
          conversationHistory: combinedHistory,
          lastUserMessage: lastUserMessage,
        );
        break;
      case 'proactive_encouragement':
        prompt = DefaultMotivationPrompts.proactiveEncouragement(
          user: user,
          tests: tests,
          analysis: analysis,
          examName: examType?.displayName,
          conversationHistory: combinedHistory,
          lastUserMessage: lastUserMessage,
        );
        break;
      case 'workshop_review':
        prompt = DefaultMotivationPrompts.workshopReview(
          user: user,
          tests: tests,
          analysis: analysis,
          examName: examType?.displayName,
          workshopContext: workshopContext,
          conversationHistory: combinedHistory,
          lastUserMessage: lastUserMessage,
        );
        break;
      case 'user_chat':
        prompt = DefaultMotivationPrompts.userChat(
          user: user,
          tests: tests,
          analysis: analysis,
          examName: examType?.displayName,
          conversationHistory: combinedHistory,
          lastUserMessage: lastUserMessage,
        );
        break;
      default:
        prompt = DefaultMotivationPrompts.userChat(
          user: user,
          tests: tests,
          analysis: analysis,
          examName: examType?.displayName,
          conversationHistory: combinedHistory,
          lastUserMessage: lastUserMessage,
        );
        break;
    }

    // Daha deterministik yanıtlar için sıcaklık düşürüldü
    final raw = await _callGemini(
      prompt,
      expectJson: false,
      temperature: 0.4,
      // SADECE sohbet için PRO modeli kullan
      model: 'gemini-1.5-pro-latest',
    );

    // Belleği güncelle (son tur)
    unawaited(_updateChatMemory(user.id, promptType, lastUserMessage: lastUserMessage, aiResponse: raw, previous: mem));

    return raw;
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