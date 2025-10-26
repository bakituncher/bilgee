// lib/core/prompts/trial_review_prompt.dart
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/features/stats/logic/stats_analysis.dart';
import 'package:taktik/data/models/performance_summary.dart';
import 'tone_utils.dart';
import 'package:taktik/core/prompts/prompt_remote.dart';

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
    final userName = user.name ?? 'Komutan';
    final lastTest = tests.isNotEmpty ? tests.first : null;
    final lastNet = lastTest?.totalNet.toStringAsFixed(2) ?? '—';
    final avgNet = (analysis?.averageNet ?? 0).toStringAsFixed(2);
    final strongest = analysis?.strongestSubjectByNet ?? '—';
    final weakest = analysis?.weakestSubjectByNet ?? '—';

    final remote = RemotePrompts.get('trial_review');
    if (remote != null && remote.isNotEmpty) {
      return RemotePrompts.fillTemplate(remote, {
        'USER_NAME': userName,
        'EXAM_NAME': examName ?? '—',
        'GOAL': user.goal ?? '',
        'LAST_NET': lastNet,
        'AVG_NET': avgNet,
        'STRONGEST': strongest,
        'WEAKEST': weakest,
        'CONVERSATION_HISTORY': conversationHistory.trim().isEmpty ? '—' : conversationHistory.trim(),
        'LAST_USER_MESSAGE': lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim(),
        'TONE': ToneUtils.toneByExam(examName),
      });
    }

    return '''
TaktikAI - Enerjik Koç. ${ToneUtils.toneByExam(examName)}
Amaç: Deneme değerlendirme. Başarıları kutla 🚀, zayıflıkları "yeni seviye" olarak sun.
Kurallar: Coşkulu, emoji bol (🔥💪✨🏆), kullanıcı mesajını tekrarlama, özgün yanıt.

Bağlam: $userName | $examName | Hedef: ${user.goal}
Son Net: $lastNet | Ort: $avgNet | Güçlü: $strongest | Gelişim: $weakest
${conversationHistory.trim().isEmpty ? '' : 'Geçmiş: ${conversationHistory.trim()}'}

Cevap:
''';
  }
}
