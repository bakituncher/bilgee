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

    return '''
Sen Türkiye'de $examName sınavına hazırlanan $firstName'in çalışma koçusun.
${conversationHistory.isNotEmpty ? 'Geçmiş: $conversationHistory\n' : ''}
$firstName: $lastUserMessage

Kurallar:
- "Gel konuşalım", "anlat", "nasıl gidiyor" gibi gereksiz sorular YASAK. Direkt taktik ver.
- "Planlı ol", "düzenli çalış" gibi boş laflar YASAK
- Somut teknik ver: konu eksiklerini kapatma, soru çözme stratejisi, zaman yönetimi
- Türk eğitim sistemini bil (dershane, kaynak kitap, TYT/AYT/LGS)
- 2-3 cümle, direkt işe yarar bilgi
''';
  }
}
