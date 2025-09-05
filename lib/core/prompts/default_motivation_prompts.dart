// lib/core/prompts/default_motivation_prompts.dart
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:bilge_ai/features/stats/logic/stats_analysis.dart';
import 'tone_utils.dart';

class DefaultMotivationPrompts {
  static String _commonHeader(String? examName) =>
      "Sen BilgeAI'sin; kısa, net ve yetişkin bir koç gibi konuşursun. ${ToneUtils.toneByExam(examName)}\nKurallar: Duyguyu 1 cümlede yansıt; kullanıcının cümlelerini kelime kelime tekrarlama, kendi sözlerinle kısaca özetle. Konu dışına çıkma, abartı ve mikro hedef/ödül telkini verme. Düz metin; emoji/markdown yok.";

  static String welcome({
    required UserModel user,
    required List<TestModel> tests,
    required StatsAnalysis? analysis,
    required String? examName,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    final userName = user.name ?? 'Komutan';
    final avgNet = (analysis?.averageNet ?? 0).toStringAsFixed(2);
    return '''
${_commonHeader(examName)}
Amaç: Hoş geldin. Kısa tanışma ve güçlü bir motivasyon cümlesi.
Bağlam: Kullanıcı: $userName | Sınav: $examName | Ortalama Net: $avgNet | Son Mesaj: ${lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim()}
Cevap:
''';
  }

  static String newTestBad({
    required UserModel user,
    required List<TestModel> tests,
    required StatsAnalysis? analysis,
    required String? examName,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    final last = tests.isNotEmpty ? tests.first.totalNet.toStringAsFixed(2) : '—';
    final avgNet = (analysis?.averageNet ?? 0).toStringAsFixed(2);
    return '''
${_commonHeader(examName)}
Amaç: Ortalama altı deneme sonrası toparlama; saygılı, net, yüceltici üslup.
Bağlam: Son Net: $last | Ortalama Net: $avgNet | Son Mesaj: ${lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim()}
Cevap:
''';
  }

  static String newTestGood({
    required UserModel user,
    required List<TestModel> tests,
    required StatsAnalysis? analysis,
    required String? examName,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    final last = tests.isNotEmpty ? tests.first.totalNet.toStringAsFixed(2) : '—';
    final avgNet = (analysis?.averageNet ?? 0).toStringAsFixed(2);
    return '''
${_commonHeader(examName)}
Amaç: Ortalama üstü deneme sonrası pekiştirme; kısa kutlama ve kararlılığı artırma.
Bağlam: Son Net: $last | Ortalama Net: $avgNet | Son Mesaj: ${lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim()}
Cevap:
''';
  }

  static String proactiveEncouragement({
    required UserModel user,
    required List<TestModel> tests,
    required StatsAnalysis? analysis,
    required String? examName,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    final streak = user.streak;
    return '''
${_commonHeader(examName)}
Amaç: Tempo düşüşünde nazik ama net hatırlatma; yüceltici koç üslubu.
Bağlam: Günlük Seri: $streak | Son Mesaj: ${lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim()}
Cevap:
''';
  }

  static String workshopReview({
    required UserModel user,
    required List<TestModel> tests,
    required StatsAnalysis? analysis,
    required String? examName,
    required Map<String, dynamic>? workshopContext,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    final subject = (workshopContext?['subject'] ?? '—').toString();
    final topic = (workshopContext?['topic'] ?? '—').toString();
    final score = (workshopContext?['score'] ?? '—').toString();
    return '''
${_commonHeader(examName)}
Amaç: Cevher Atölyesi sonrası kısa değerlendirme; 1 güçlü vurgu ve net bir pekiştirme cümlesi.
Bağlam: Ders: $subject | Konu: $topic | Başarı: %$score | Son Mesaj: ${lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim()}
Cevap:
''';
  }

  static String userChat({
    required UserModel user,
    required List<TestModel> tests,
    required StatsAnalysis? analysis,
    required String? examName,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    final userName = user.name ?? 'Komutan';
    return '''
${_commonHeader(examName)}
Amaç: Serbest sohbet. Kısa, net, doğrudan yanıt; konu dışına çıkma.
Bağlam: Kullanıcı: $userName | Son Mesaj: ${lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim()}
Cevap:
''';
  }
}
