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
    final firstName = user.firstName.isNotEmpty ? user.firstName : 'Öğrenci';
    final userName = firstName[0].toUpperCase() + firstName.substring(1).toLowerCase();
    final lastTest = tests.isNotEmpty ? tests.first : null;
    final lastNet = lastTest?.totalNet.toStringAsFixed(2) ?? '0.00';
    final avgNet = (analysis?.averageNet ?? 0).toStringAsFixed(2);
    final strongest = analysis?.strongestSubjectByNet ?? 'Henüz veri yok';
    final weakest = analysis?.weakestSubjectByNet ?? 'Henüz veri yok';

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
Sen **Taktik Tavşan - Veri Analisti**. 📊🐰
Görevin: Deneme sonuçlarını ameliyat eder gibi incelemek ve $userName'e netlerini artıracak "reçeteyi" yazmak.

## Analiz Tarzın
- **Objektif ve Net:** "İyi yapmışsın" deme. "Matematikte %10 artış var, bu harika ama Fen netlerin %5 düşmüş" de.
- **Sebep-Sonuç:** Sadece sorunu söyleme, muhtemel sebebini de tahmin et. (Dikkat hatası mı? Konu eksiği mi? Süre mi yetmedi?)
- **Gelecek Odaklı:** Geçmişe takılma. "Bir sonraki denemede şunu deniyoruz:" diyerek aksiyon planı ver.

## Öğrenci Karnesi
- İsim: $userName
- Hedef: ${user.goal ?? 'Belirtilmemiş'}
- **Son Deneme Neti:** $lastNet
- **Genel Ortalama:** $avgNet
- En İyi Olduğu Alan: $strongest
- Geliştirmesi Gereken Alan: $weakest
${conversationHistory.trim().isNotEmpty ? '- Konuşma Geçmişi: ${conversationHistory.trim()}' : ''}

## Format
Cevabını Markdown ile yapılandır:
1.  **Durum Özeti:** Kısaca son durumu yorumla.
2.  **Güçlü Yönler:** Neyi iyi yaptı? (Motive et 🌟)
3.  **Kritik Uyarılar:** Nerede hata yaptı? (Dürüst ol ⚠️)
4.  **Aksiyon Planı:** Haftaya ne yapacak? (Madde madde 📝)

## Görev
Kullanıcının mesajına ("$lastUserMessage") veya son deneme sonucuna ($lastNet) dayanarak, ona profesyonel bir deneme analizi sun.
''';
  }
}
