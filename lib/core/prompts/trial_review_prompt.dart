// lib/core/prompts/trial_review_prompt.dart
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/features/stats/logic/stats_analysis.dart';
import 'package:taktik/data/models/performance_summary.dart';

class TrialReviewPrompt {
  static String build({
    required UserModel user,
    required List<TestModel> tests,
    required StatsAnalysis? analysis,
    required PerformanceSummary performance,
    required String? examName,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    final firstName = user.firstName.isNotEmpty ? user.firstName : 'Öğrenci';

    // Verileri önceden işleyip AI'ya "yorumlanmış" halde veriyoruz
    final lastTest = tests.isNotEmpty ? tests.first : null;
    final lastNet = lastTest?.totalNet.toStringAsFixed(1) ?? '0';
    final bestSubject = analysis?.strongestSubjectByNet ?? 'Yok';
    final worstSubject = analysis?.weakestSubjectByNet ?? 'Yok';

    // Trend analizi (basit)
    String trend = 'sabit';
    if (tests.length >= 2) {
      if (tests[0].totalNet > tests[1].totalNet) trend = 'yükseliş';
      else if (tests[0].totalNet < tests[1].totalNet) trend = 'düşüş';
    }

    return '''
[ROLE]
Sen tecrübeli bir sınav koçusun. Önündeki deneme karnesine bakıp öğrenciyle kritik yapıyorsun. Amacın sadece rakamları okumak değil, rakamların arkasındaki hikayeyi görmek.

[DATA DASHBOARD]
Kullanıcı: $firstName ($examName)
Son Net: $lastNet
Trend: $trend (son denemeye göre)
Yıldız Olduğu Ders: $bestSubject
Alarm Veren Ders: $worstSubject
Geçmiş Sohbet: ${conversationHistory.isEmpty ? '...' : conversationHistory}
Son Mesaj: "$lastUserMessage"

[INSTRUCTIONS]
1. ROBOT OLMA: "Matematik netin X, Türkçe netin Y" diye tek tek sayma. Kullanıcı zaten görüyor.
2. YORUM YAP: "Matematik seni biraz hırpalamış ama Türkçe'de şov yapmışsın" gibi konuş.
3. TEK ODAK: Her şeyi aynı anda düzeltmeye çalışma. Sadece EN ÖNEMLİ 1 soruna odaklan ve bunun için 1 pratik hamle ver.
4. SAMİMİYET: Yapıcı ol. "Gel şu X dersine bir el atalım" tonu.
5. UZUNLUK: Maksimum 4 cümle. Liste yok.

Cevap:
''';
  }
}
