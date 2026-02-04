// lib/core/prompts/strategy_consult_prompt.dart
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/features/stats/logic/stats_analysis.dart';
import 'package:taktik/data/models/performance_summary.dart';

class StrategyConsultPrompt {
  static String build({
    required UserModel user,
    required List<TestModel> tests,
    required StatsAnalysis? analysis,
    required PerformanceSummary performance,
    required String? examName,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    final firstName = user.firstName.isNotEmpty ? user.firstName : 'Dostum';

    // Performans verilerini hazırla
    final testCount = tests.length;
    final avgNet = testCount > 0
        ? (tests.fold<double>(0, (sum, t) => sum + t.totalNet) / testCount).toStringAsFixed(1)
        : 'Veri yok';
    final strongSubject = analysis?.strongestSubjectByNet ?? 'Henüz belirlenmedi';
    final weakSubject = analysis?.weakestSubjectByNet ?? 'Henüz belirlenmedi';

    // Trend analizi
    String trendInfo = 'Trend verisi yok';
    if (testCount >= 2) {
      final recent = tests.take(3).map((t) => t.totalNet).toList();
      final oldest = tests.skip(testCount > 5 ? testCount - 3 : 0).take(3).map((t) => t.totalNet).toList();
      final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
      final oldAvg = oldest.reduce((a, b) => a + b) / oldest.length;
      if (recentAvg > oldAvg + 2) trendInfo = 'Yükseliş trendinde 📈';
      else if (recentAvg < oldAvg - 2) trendInfo = 'Düşüş trendinde 📉';
      else trendInfo = 'Stabil seyir ➡️';
    }

    return '''
Sen $firstName'in $examName strateji koçusun. Türk eğitim sistemini, kaynak kitapları (3D, Tonguç, Palme vb.) ve çalışma tekniklerini biliyorsun.

VERİLER: Deneme: $testCount | Ort Net: $avgNet | Güçlü: $strongSubject | Zayıf: $weakSubject | Trend: $trendInfo
${conversationHistory.isNotEmpty ? 'Geçmiş: $conversationHistory' : ''}

$firstName: "$lastUserMessage"

KURALLAR:
- Gereksiz sorular YASAK, direkt taktik ver
- "Planlı ol", "düzenli çalış" gibi boş laflar YASAK
- Somut strateji ver: kaynak adı, teknik, süre, soru sayısı belirt
- Türk genci gibi samimi konuş
- 5-6 CÜMLE YAZ, fazlası kesilir
''';
  }
}
