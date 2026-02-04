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
    final testCount = tests.length;

    // Ortalama net hesaplama
    final avgNet = testCount > 0
        ? (tests.fold<double>(0, (sum, t) => sum + t.totalNet) / testCount).toStringAsFixed(1)
        : '0';

    // Trend analizi (son 3 deneme vs önceki 3 deneme)
    String trend = 'henüz yeterli veri yok';
    String trendDetail = '';
    if (tests.length >= 2) {
      final diff = tests[0].totalNet - tests[1].totalNet;
      if (diff > 3) {
        trend = 'güçlü yükseliş 📈';
        trendDetail = '+${diff.toStringAsFixed(1)} net artış';
      } else if (diff > 0) {
        trend = 'hafif yükseliş 📈';
        trendDetail = '+${diff.toStringAsFixed(1)} net artış';
      } else if (diff < -3) {
        trend = 'düşüş 📉';
        trendDetail = '${diff.toStringAsFixed(1)} net';
      } else if (diff < 0) {
        trend = 'hafif düşüş 📉';
        trendDetail = '${diff.toStringAsFixed(1)} net';
      } else {
        trend = 'stabil ➡️';
      }
    }

    String examContext = "Genel Deneme";
    if (lastTest != null && lastTest.isBranchTest) {
      final lessonName = lastTest.scores.keys.isNotEmpty ? lastTest.scores.keys.first : 'Tek Ders';
      examContext = "Branş Denemesi ($lessonName)";
    }

    // Zayıf konu detayları
    final weakTopicInfo = analysis?.getWeakestTopicWithDetails();
    final weakTopic = weakTopicInfo != null
        ? '${weakTopicInfo['topic']} (${weakTopicInfo['subject']})'
        : 'Belirlenmedi';

    // Ders bazlı performans özeti
    String subjectBreakdown = '';
    if (lastTest != null && lastTest.scores.isNotEmpty) {
      final subjectNets = lastTest.scores.entries.map((e) {
        final dogru = e.value['dogru'] ?? 0;
        final yanlis = e.value['yanlis'] ?? 0;
        final net = dogru - (yanlis * lastTest.penaltyCoefficient);
        return '${e.key}: ${net.toStringAsFixed(1)} net';
      }).join(', ');
      subjectBreakdown = subjectNets;
    }

    return '''
Sen $firstName'in $examName deneme koçusun. Türk eğitim sistemini (TYT/AYT/LGS/KPSS) biliyorsun.

VERİLER: Son Net: $lastNet | Ort: $avgNet ($testCount deneme) | Trend: $trend $trendDetail | Güçlü: $bestSubject | Zayıf: $worstSubject | Zayıf Konu: $weakTopic
${subjectBreakdown.isNotEmpty ? 'Ders Dağılımı: $subjectBreakdown' : ''}
${conversationHistory.isNotEmpty ? 'Geçmiş: $conversationHistory' : ''}

$firstName: "$lastUserMessage"

KURALLAR:
- Gereksiz sorular YASAK, elinde veri var direkt analiz yap
- "Daha çok çalış" gibi boş laflar YASAK, somut öneriler ver
- Verilere referans ver, spesifik konu/kaynak/soru sayısı belirt
- Türk genci gibi samimi konuş
- 5-6 CÜMLE YAZ, fazlası kesilir
''';
  }
}
