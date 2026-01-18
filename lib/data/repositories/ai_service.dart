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

      // Varsa direkt stringi döndür (artık içinde ham mesajlar da olabilir)
      final v = data[key];
      if (v is String) return v.trim();

      // Geriye dönük uyumluluk / global fallback
      final g = data['globalSummary'];
      return (g is String) ? g.trim() : '';
    } catch (_) {
      return '';
    }
  }

  // INDUSTRY STANDARD MEMORY: Rolling Window (Kayan Pencere)
  // Eski yöntem: Her şeyi özetle -> Robotlaşır.
  // Yeni yöntem: Son ~4000 karakteri (yaklaşık 10-15 mesaj) olduğu gibi tut. Eskileri at.
  Future<void> _updateChatMemory(
    String userId,
    String mode, {
    required String lastUserMessage,
    required String aiResponse,
    String previous = '',
  }) async {
    try {
      // 1) Yeni turu formatla
      final newTurn = [
        if (lastUserMessage.trim().isNotEmpty) 'Kullanıcı: ${lastUserMessage.trim().replaceAll('\n', ' ')}',
        if (aiResponse.trim().isNotEmpty) 'AI: ${aiResponse.trim().replaceAll('\n', ' ')}',
      ].join(' | ');

      // 2) Geçmişe ekle
      String updatedHistory = previous.trim().isEmpty ? newTurn : '${previous.trim()} | $newTurn';

      // 3) Limit Kontrolü (4000 Karakter ~ son turlar)
      const int maxChars = 8000;
      if (updatedHistory.length > maxChars) {
        // sondan maxChars kadarını al (en taze sohbet kalsın)
        updatedHistory = updatedHistory.substring(updatedHistory.length - maxChars);

        // kesilen yerin başındaki yarım parça/turn’ü temizle
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
      // sessiz geç
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

  // YENI: Düz metin sanitizasyonu (markdown ve madde işaretlerini temizle)
  // Not: Motivasyon modlarında emoji/enerji öldürmemek için sadece agressif markdown’ı temizleyeceğiz.
  String _sanitizePlainText(String input) {
    var out = input;
    out = out.replaceAll('```', '');
    out = out.replaceAll('`', '');
    out = out.replaceAll('**', '');
    out = out.replaceAll('__', '');

    // Satır başı bullet temizliği (çok robotik liste cevapları kırmak için)
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

  // YENI: Koçvari üslubu korumak için bazen fazla “kelime değiştirme” robotikleşiyor.
  // Bu işi daha çok prompt’a bırakıyoruz.
  String _enforceToneGuard(String input) {
    return input.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  String? _extractJsonFromFencedBlock(String text) {
    // 1. ```json ... ``` bloklarını ara
    final jsonFence = RegExp(r"```json\s*([\s\S]*?)\s*```", multiLine: true).firstMatch(text);
    if (jsonFence != null) return jsonFence.group(1)!.trim();

    // 2. Herhangi bir ``` ... ``` bloğunu ara
    final anyFence = RegExp(r"```\s*([\s\S]*?)\s*```", multiLine: true).firstMatch(text);
    if (anyFence != null) return anyFence.group(1)!.trim();

    return null;
  }

  String? _extractJsonByBracesFallback(String text) {
    // İlk { ve son } arasındaki her şeyi al (Regex cerrahi müdahale - Sorunun 1. çözümü)
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
      // JSON parse hatası - muhtemelen yarım JSON veya kirli format
      final errorMsg = e.toString().toLowerCase();

      // Yarım JSON tespiti (token limiti nedeniyle kesilme)
      if (errorMsg.contains('unexpected end') || errorMsg.contains('unterminated')) {
        return jsonEncode({'error': 'Plan oluşturulurken yanıt yarım kaldı. Lütfen tekrar deneyin veya tempo ayarını "Rahat" seçerek daha kısa bir plan oluşturun.'});
      }

      // Genel parse hatası
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
        // taskId key'i ile kayıtlıysa:
        final taskId = data['taskId'] as String?;
        if (taskId != null && taskId.isNotEmpty) {
          taskIds.add(taskId);
        } else {
          // Doküman ID'si görev ID'si ise:
          taskIds.add(doc.id);
        }
      }
      return taskIds;
    } catch (_) {
      return {};
    }
  }

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
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('ai-generateGemini');
      final payload = {
        'prompt': prompt,
        'expectJson': expectJson,
        'requestType': requestType,
        'temperature': temperature ?? 0.7, // Default artık daha insani
        if (model != null && model.isNotEmpty) 'model': model,
      };
      final result = await callable.call(payload).timeout(const Duration(seconds: 70));
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

      // Sohbet için basit temizlik
      return _enforceToneGuard(_sanitizePlainText(rawResponse));
    } on FirebaseFunctionsException catch (e) {
      // Backend'den "resource-exhausted" gelirse (kota doldu), mesajı kullanıcıya göster
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
    // Merkezî takvimden hesapla
    return ExamSchedule.daysUntilExam(examType);
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

    // DÜZELTME 1: Önbellek yerine anlık hesap; yeni denemeler hemen yansısın.
    final String avgNet = _quickAverageNet(tests).toStringAsFixed(2);
    final Map<String, double> subjectAverages = _computeSubjectAveragesQuick(tests);

    final availabilityJson = jsonEncode(user.weeklyAvailability);

    // Tamamlanan konu ID'lerini al (Müfredat filtreleme için)
    final completedTopicIds = await _loadRecentCompletedTaskIdsOnly(user.id, days: 365);

    // YENİ SEKTÖR STANDARDI: Tüm müfredat yerine sadece "Sıradaki Aday Konular"
    // Bu sayede yeni kullanıcı için otomatik olarak ilk konular, ileri kullanıcı için kaldığı yerden devam
    final candidateTopicsJson = await _buildNextStudyTopicsJson(
      examType,
      user.selectedExamSection,
      completedTopicIds
    );

    // GUARDRAILS: backlog + konu renkleri + politika
    final guardrailsJson = _buildGuardrailsJson(planDoc?.weeklyPlan, completedTopicIds, performance);

    String prompt;
    switch (examType) {
      case ExamType.yks:
      // FIX: YDT öğrencileri için başlığı "TYT ve YDT" olarak güncelle ki AI her ikisini de kapsasın
        String displaySection = user.selectedExamSection ?? '';
        if (displaySection == 'YDT') {
          displaySection = 'TYT ve YDT';
        }

        prompt = StrategyPrompts.getYksPrompt(
            userId: user.id, selectedExamSection: displaySection,
            daysUntilExam: daysUntilExam, goal: user.goal ?? '',
            challenges: user.challenges, pacing: pacing,
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

    // DÜZELTME 3: AI cache kırıcı varyasyon etiketi ekle
    prompt += "\n\n[System: Generate a UNIQUE plan. Variation: ${DateTime.now().millisecondsSinceEpoch}]";

    // TOKEN LİMİTİ UYARISI: AI'a JSON'u tam olarak kapatmasını hatırlat (Sorunun 2. çözümü)
    prompt += "\n\nÖNEMLİ: Yanıtını mutlaka geçerli ve KAPALI bir JSON objesi olarak döndür. JSON'un sonunda tüm süslü parantezleri kapat. Yanıt kesilirse kısa tut ama yapıyı koru.";

    // ====================================================================================
    // DÜZELTME 4: GÜN SIRALAMASI SORUNUNU ÇÖZME (Cumartesi bile olsa o günden başla)
    // ====================================================================================
    final trDays = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    final todayIndex = DateTime.now().weekday - 1; // 0=Pzt, 6=Paz
    final todayName = trDays[todayIndex];

    // Günleri bugünden başlayarak sırala (örn: Cmt, Paz, Pzt, Sal...)
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

ÖNEMLİ: Haftanın planlamasını yaparken "Pazartesi başlar" kuralını YOK SAY. Kullanıcı stratejiyi bugün ($todayName) oluşturuyor, bu yüzden ilk gün ($todayName) en yoğun ve motive edici başlangıç günü olmalı. Geçmiş günleri (örneğin dünkü Cuma) planlama, onları döngünün sonuna (gelecek hafta) at.
""";

    // ====================================================================================
    // ÇÖZÜM 2: KAPASİTE KULLANIMI VE BOŞLUK DOLDURMA
    // ====================================================================================
    // Sorun: Kullanıcı "Yoğun" seçiyor ve tüm saatleri açıyor ama AI boşluk bırakıyor.
    // Çözüm: Pacing moduna göre "Doluluk Oranı" talimatı veriyoruz.

    String densityInstruction = "";

    if (pacing == 'intense' || pacing == 'yoğun') {
      densityInstruction = """

[SİSTEM AYARI 2: KAPASİTE VE DOLULUK (CRITICAL)]
Kullanıcı Modu: **INTENSE (YOĞUN)**.

TALİMATLAR:
1. 'weeklyAvailability' içinde "true" (müsait) olarak işaretlenmiş **HER BİR SAAT DİLİMİNİ** doldurmak ZORUNDASIN.
2. Asla "kullanıcı yorulur" diye düşünüp inisiyatif alma ve boşluk bırakma. Kullanıcı sınırlarını zorlamak istiyor.
3. Konu çalışması biterse; "Zor Soru Çözümü", "Branş Denemesi", "Paragraf/Problem Rutini" veya "Genel Tekrar" ile slotu doldur.
4. HEDEF DOLULUK ORANI: %100. Müsait olan hiçbir slot boş kalmamalı.
""";
    } else if (pacing == 'moderate' || pacing == 'dengeli') {
      densityInstruction = """

[SİSTEM AYARI 2: KAPASİTE]
Kullanıcı Modu: **MODERATE (DENGELİ)**.
Müsait zamanların yaklaşık %80'ini doldur. %20'lik kısmı esneklik payı olarak boş bırakabilirsin.
""";
    } else {
      densityInstruction = """

[SİSTEM AYARI 2: KAPASİTE]
Kullanıcı Modu: **RELAXED (RAHAT)**.
Sadece en kritik konulara odaklan. Müsait zamanın %50-60'ını doldurman yeterli.
""";
    }

    prompt += densityInstruction;
    // ====================================================================================

    return _callGemini(prompt, expectJson: true, requestType: 'weekly_plan');
  }

  /// YENİ SEKTÖR STANDARDI FONKSİYON: Tüm müfredatı değil, sadece çalışılması gereken "ADAY" konuları hazırlar.
  /// Bu sayede AI'a token israfı olmaz ve yeni kullanıcılar için otomatik olarak doğru konular seçilir.
  Future<String> _buildNextStudyTopicsJson(
    ExamType examType,
    String? selectedSection,
    Set<String> completedTopicIds // Kullanıcının bitirdiği konuların ID listesi
  ) async {
    try {
      // 1. Tüm müfredatı yerelden çek (Bu işlem token harcamaz, cihazda yapılır)
      final exam = await ExamData.getExamByType(examType);

      List<ExamSection> sections = [];

      // 2. Kullanıcının bölümüne göre dersleri filtrele
      // AGS MANTIĞI: Her zaman "AGS" (Ortak) + Seçilen Branş
      if (examType == ExamType.ags) {
        sections.addAll(exam.sections.where((s) => s.name == 'AGS'));
        if (selectedSection != null && selectedSection.isNotEmpty) {
          sections.addAll(exam.sections.where((s) => s.name.toLowerCase() == selectedSection.toLowerCase()));
        }
      }
      // YKS MANTIĞI: Her zaman "TYT" + Seçilen Alan (AYT-Sayısal, YDT vb.)
      else if (examType == ExamType.yks) {
        sections.addAll(exam.sections.where((s) => s.name == 'TYT'));
        if (selectedSection != null && selectedSection.isNotEmpty && selectedSection != 'TYT') {
          sections.addAll(exam.sections.where((s) => s.name.toLowerCase() == selectedSection.toLowerCase()));
        }
      }
      // DİĞERLERİ (LGS, KPSS)
      else {
        sections = (selectedSection != null && selectedSection.isNotEmpty)
            ? exam.sections.where((s) => s.name.toLowerCase() == selectedSection.toLowerCase()).toList()
            : exam.sections;
      }

      final Map<String, List<String>> candidateTopics = {};

      // 3. KRİTİK NOKTA: Her ders için "Sıradaki 3 Konuyu" bul
      for (final sec in sections) {
        sec.subjects.forEach((subjectName, subjectDetails) {
          // Bu dersteki tüm konular (Sıralı halde gelir)
          final allTopics = subjectDetails.topics.map((t) => t.name).toList();

          // Bitmemiş olanları bul (Sırayı bozmadan)
          final remainingTopics = allTopics.where((t) => !completedTopicIds.contains(t)).toList();

          // Eğer hiç konu kalmadıysa (Ders bitmişse) boş geç
          if (remainingTopics.isEmpty) return;

          // SEKTÖR STANDARDI AYAR:
          // Her dersten önümüzdeki "3" konuyu seç. AI bunlardan birini veya ikisini seçecek.
          // Hepsini birden göndermiyoruz - Token tasarrufu + Odaklanma
          final nextBatch = remainingTopics.take(3).toList();

          candidateTopics[subjectName] = nextBatch;
        });
      }

      // Çıktı Örneği:
      // {
      //   "candidates": {
      //     "Matematik": ["Temel Kavramlar", "Sayı Basamakları", "Bölünebilme"],
      //     "Fizik": ["Fizik Bilimine Giriş", "Madde ve Özellikleri"]
      //   },
      //   "note": "Sadece bu listedeki konuları planlayabilirsin. Sırayı bozma."
      // }
      return jsonEncode({
        'candidates': candidateTopics,
        'note': 'Sadece bu listedeki konuları planlayabilirsin. Müfredat sırasını takip et.'
      });
    } catch (e) {
      // Hata durumunda boş liste döndür
      return jsonEncode({
        'candidates': {},
        'note': 'Müfredat yüklenemedi, genel konulardan plan oluştur.'
      });
    }
  }

  Future<String> _buildCurriculumOrderJson(ExamType examType, String? selectedSection) async {
    try {
      final exam = await ExamData.getExamByType(examType);

      List<ExamSection> sections = [];

      // 1. AGS MANTIĞI: Her zaman "AGS" (Ortak) + Seçilen Branş
      if (examType == ExamType.ags) {
        // Ortak bölümü ekle (Adı genellikle 'AGS' olarak parse ediliyor)
        sections.addAll(exam.sections.where((s) => s.name == 'AGS'));

        // Seçilen branşı ekle (Eğer varsa)
        if (selectedSection != null && selectedSection.isNotEmpty) {
          sections.addAll(exam.sections.where((s) => s.name.toLowerCase() == selectedSection.toLowerCase()));
        }
      }
      // 2. YKS MANTIĞI: Her zaman "TYT" + Seçilen Alan (AYT-Sayısal, YDT vb.)
      else if (examType == ExamType.yks) {
        // TYT her zaman eklenir
        sections.addAll(exam.sections.where((s) => s.name == 'TYT'));

        if (selectedSection != null && selectedSection.isNotEmpty && selectedSection != 'TYT') {
          // Eğer seçilen alan 'AYT - Sayısal' ise onu ekle
          sections.addAll(exam.sections.where((s) => s.name.toLowerCase() == selectedSection.toLowerCase()));
        }
      }
      // 3. DİĞERLERİ (LGS, KPSS)
      else {
        sections = (selectedSection != null && selectedSection.isNotEmpty)
            ? exam.sections.where((s) => s.name.toLowerCase() == selectedSection.toLowerCase()).toList()
            : exam.sections;
      }

      final Map<String, List<String>> subjects = {};
      for (final sec in sections) {
        sec.subjects.forEach((subject, details) {
          subjects[subject] = details.topics.map((t) => t.name).toList();
        });
      }
      final payload = {
        'section': selectedSection ?? 'all',
        'subjects': subjects,
      };
      return jsonEncode(payload);
    } catch (_) {
      return jsonEncode({'section': selectedSection ?? 'all', 'subjects': {}});
    }
  }

  String _buildGuardrailsJson(Map<String, dynamic>? weeklyPlanRaw, Set<String> completedTopicIds, PerformanceSummary performance){
    // Backlog: geçen haftanın planından tamamlanmamış görevler
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
      } catch (_) {
        // yoksay
      }
    }

    // Konu renkleri: kırmızı/sarı/yeşil/unknown
    final topicStatus = <String, Map<String, dynamic>>{}; // subject -> { topic -> status }
    int redCount = 0, yellowCount = 0, unknownCount = 0;
    performance.topicPerformances.forEach((subject, topics){
      final map = <String, String>{};
      topics.forEach((topic, tp){
        final attempts = tp.correctCount + tp.wrongCount;
        String status;
        if (tp.questionCount < 8 || attempts < 6) {
          status = 'unknown';
          unknownCount++;
        } else {
          final denom = attempts == 0 ? 1 : attempts;
          final acc = tp.correctCount / denom;
          if (acc < 0.5 || tp.wrongCount >= tp.correctCount) { status = 'red'; redCount++; }
          else if (acc < 0.7) { status = 'yellow'; yellowCount++; }
          else { status = 'green'; }
        }
        map[topic] = status;
      });
      // Sadece içi dolu olan subject'leri ekle
      if (map.isNotEmpty) {
        topicStatus[subject] = map;
      }
    });

    // Politika: ne zaman müfredat vs metrik
    final policy = <String, dynamic>{
      'allowNewTopics': backlogActivities.isEmpty && redCount == 0,
      'priorities': backlogActivities.isNotEmpty
          ? ['backlog','red','yellow','curriculum']
          : (redCount>0 ? ['red','yellow','curriculum'] : ['curriculum','yellow','red']),
      'notes': 'Backlog veya kırmızı konular varsa yeni konu açma; önce bunları bitir. Unknown konularda kısa tanılayıcı set uygula.'
    };

    final guardrails = {
      'backlogCount': backlogActivities.length,
      'backlogSample': backlogActivities.take(10).toList(),
      'topicStatus': topicStatus,
      'policy': policy,
    };

    return jsonEncode(guardrails);
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
        final analysis = StatsAnalysis(tests, examData, _ref.read(firestoreServiceProvider), user: user);
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

    // Eğer UI'dan history gelmediyse, DB'den çek
    String historyToUse = conversationHistory;
    String mem = '';
    if (shouldUseMemory && historyToUse.trim().isEmpty) {
      mem = await _getChatMemory(user.id, promptType);
      historyToUse = mem;
    }

    String prompt;

    // Chat türüne göre dinamik temperature
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
        chatTemperature = 0.9;
        break;
      case 'motivation_corner':
        prompt = MotivationCornerPrompt.build(
          user: user,
          examName: examType?.displayName,
          conversationHistory: historyToUse,
          lastUserMessage: lastUserMessage,
        );
        chatTemperature = 0.9;
        break;
      default:
        // Diğer durumlar için fallback
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

  // Hafif yardımcılar: UI dış tek seferlik hesaplamalarda kullanılabilir
  double _quickAverageNet(List<TestModel> tests) {
    if (tests.isEmpty) return 0.0;
    final total = tests.fold<double>(0.0, (acc, t) => acc + t.totalNet);
    return total / tests.length;
  }

  Map<String, double> _computeSubjectAveragesQuick(List<TestModel> tests) {
    if (tests.isEmpty) return {}; // Boş liste ise boş map döndür (NaN önleme)
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
    // Set kullan (daha hızlı ve güncel metod)
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

