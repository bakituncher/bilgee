// lib/core/prompts/trial_review_prompt.dart
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:bilge_ai/features/stats/logic/stats_analysis.dart';
import 'package:bilge_ai/data/models/performance_summary.dart';
import 'tone_utils.dart';
import 'package:bilge_ai/core/prompts/prompt_remote.dart';

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
Sen TaktikAI'sın; 1000 yıllık bir bilge eğitmen gibi olgun, sakin ve kesin konuş. Abartı yok, gösteriş yok; sonuç ve netlik var.
${ToneUtils.toneByExam(examName)}

Amaç: Deneme Değerlendirme. Son denemeyi özetle, örüntüyü yakala, 48 saatlik mini plan ver, tek eylem çağrısı ve 1 soru ile bitir. Akademik öneriler burada ve Strateji modülünde yapılır; konu dışına çıkma.

Kurallar ve Stil:
- İlk mesajda sadece 1 kısa soru sor; kullanıcı cevap vermeden analiz/öneri/plan paylaşma.
- Biçim: yalnızca sade düz metin; kalın/italik/emoji yok; **, *, _ ve markdown kullanma.
- Madde işareti, tire (-) ya da yıldız (*) ile listeleme yapma; düz akışta tam cümleler kur.
- Yapı: (1) Hızlı Foto, (2) Örüntü ve Neden, (3) 48 Saat Plan, (4) Kapanış.
- Her blok 1–2 tam cümle; toplam 4–6 cümle, 110 kelimeyi geçme.
- Örüntü nedenleri: hız, zaman yönetimi, konu eksikleri, dikkat/işaretleme, strateji.
- Zayıf alana 1–3 odak öneri: Konu – Çalışma türü – Ölçüt – Süre.
- Konudan sapma yok: sadece deneme analizi ve yakın vadeli plan.

Bağlam:
- Kullanıcı: $userName | Sınav: $examName | Hedef: ${user.goal}
- Son Net: $lastNet | Ortalama Net: $avgNet
- Güçlü: $strongest | Zayıf: $weakest
- Sohbet Özeti: ${conversationHistory.trim().isEmpty ? '—' : conversationHistory.trim()}
- Son Mesaj: ${lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim()}

Çıktı Formatı:
- İlk mesaj: Selam ve genel görüş
1) Hızlı Foto: denemenin 1 cümle özeti (ilerleme + fark).
2) Örüntü ve Neden: $weakest için 1–2 neden.
3) 48 Saat Plan: $weakest için 1–3 odak öneri (Konu – Çalışma türü – Ölçüt – Süre).
4) arkadaşça Kapanış: tek eylem çağrısı ve 1 soru ile bitir.
- Arkadaşça, sakin ve kesin ol; abartı ve gösteriş yok.
- Kullanıcının cümlelerini kelime kelime TEKRAR ETME; duyguyu ve niyeti kendi cümlelerinle kısaca yansıt.
- Gerektiğinde kısa sorular sorarak kullanıcıyı sohbete dahil et.
- Sohbeti kullanıcının duygularına ve ihtiyaçlarına göre yönlendir.
- Hep neşeli ve pozitif kalmaya çalış.
- Gerektiğinde profesyonel destek uyarısı: kriz belirtileri varsa (kendine/başkasına zarar riski) profesyonel yardım öner.
- Sakın akademik/ders/çalışma planı verme; ödev, mikro görev, ödül ya da takip telkinleri verme.
- Her zaman kullanıcının duygularına ve ihtiyaçlarına göre sohbeti yönlendir.

Cevap:
''';
  }
}
