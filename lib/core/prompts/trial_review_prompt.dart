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

    // [YENİ EKLENEN KISIM] Branş Denemesi Tespiti
    // AI'ın elma ile armudu karıştırmaması için ona bağlam veriyoruz.
    String examContext = "Genel Deneme (Tüm Dersler)";
    if (lastTest != null && lastTest.isBranchTest) {
      // Branş denemesi ise dersin adını bul (örn: Matematik)
      final lessonName = lastTest.scores.keys.isNotEmpty ? lastTest.scores.keys.first : 'Tek Ders';
      examContext = "BRANŞ DENEMESİ ($lessonName) - (DİKKAT: Bu sadece tek bir dersin sonucudur)";
    }

    return '''
[ROLE]
Sen tecrübeli bir sınav koçusun. Önündeki deneme karnesine bakıp öğrenciyle kritik yapıyorsun. Amacın sadece rakamları okumak değil, rakamların arkasındaki hikayeyi görmek.

[DATA DASHBOARD]
Kullanıcı: $firstName ($examName)
Sınav Türü: $examContext
Son Net: $lastNet
Trend: $trend (son denemeye göre)
Yıldız Olduğu Ders: $bestSubject
Alarm Veren Ders: $worstSubject
Geçmiş Sohbet: ${conversationHistory.isEmpty ? '...' : conversationHistory}
Son Mesaj: "$lastUserMessage"

[INSTRUCTIONS]
1. BAĞLAM FARKINDALIĞI (ÇOK ÖNEMLİ): Eğer "Sınav Türü" BRANŞ DENEMESİ ise; sakın "Genel netin düşmüş" veya "Puanın azalmış" gibi yorumlar yapma. Çünkü bu sadece tek bir ders. O dersin kendi içindeki başarısını yorumla.
2. ROBOT OLMA: "Matematik netin X" diye sayma. Yorum kat.
3. TEK ODAK: Her şeyi düzeltmeye çalışma. En önemli 1 soruna odaklan.
4. SAMİMİYET: Yapıcı ve motive edici ol.
5. UZUNLUK: Maksimum 4 cümle. Liste yapma.

Cevap:
''';
  }
}
