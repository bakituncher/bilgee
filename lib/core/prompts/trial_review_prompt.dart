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

    String trend = 'sabit';
    if (tests.length >= 2) {
      if (tests[0].totalNet > tests[1].totalNet) trend = 'yükseliş';
      else if (tests[0].totalNet < tests[1].totalNet) trend = 'düşüş';
    }

    String examContext = "Genel Deneme";
    if (lastTest != null && lastTest.isBranchTest) {
      final lessonName = lastTest.scores.keys.isNotEmpty ? lastTest.scores.keys.first : 'Tek Ders';
      examContext = "Branş Denemesi ($lessonName)";
    }

    return '''
Sen Türkiye'de $examName sınavına hazırlanan $firstName'in deneme koçusun.

Veri: Net: $lastNet | Trend: $trend | Güçlü: $bestSubject | Zayıf: $worstSubject | Tür: $examContext
${conversationHistory.isNotEmpty ? 'Geçmiş: $conversationHistory\n' : ''}
$firstName: $lastUserMessage

Kurallar:
- "Gel konuşalım", "detay ver", "anlat" gibi gereksiz sorular YASAK. Direkt cevap ver.
- Somut öneri ver: hangi konu, hangi kaynak, kaç soru
- Türk eğitim sistemini bil (TYT/AYT/LGS, dershane, kaynak kitaplar)
- 2-3 cümle, boş laf yok
''';
  }
}
