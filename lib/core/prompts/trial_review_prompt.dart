// lib/core/prompts/trial_review_prompt.dart
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/features/stats/logic/stats_analysis.dart';
import 'package:taktik/data/models/performance_summary.dart';
import 'tone_utils.dart';
import 'package:taktik/core/prompts/prompt_remote.dart';

class TrialReviewPrompt {
  static String _getExamSpecificTone(String? examName) {
    final exam = (examName ?? '').toLowerCase();
    if (exam.contains('kpss')) {
      return '''
**KPSS Koçluk Tonu:**
- Profesyonel, yetişkin dili
- "Atanma yolunda" perspektifi
- İş-çalışma dengesi vurgusu
- Süre yönetimi önerileri
- GY-GK stratejileri
''';
    } else if (exam.contains('yks') || exam.contains('tyt') || exam.contains('ayt') || exam.contains('ydt')) {
      return '''
**YKS Koçluk Tonu:**
- Akademik, motive edici
- "Hedef üniversite" odaklı
- Konu derinliği vurgusu
- Strateji ve taktik önerileri
- YDT için: Dil becerisi geliştirme, günlük pratik, kelime ezber stratejileri
- Genç, enerjik dil
''';
    } else if (exam.contains('lgs')) {
      return '''
**LGS Koçluk Tonu:**
- Destekleyici, cesaretlendirici
- "Sen yapabilirsin!" enerjisi
- Adım adım ilerleme
- Pozitif pekiştirme
- Ortaokul seviyesine uygun
''';
    }
    return 'Genel motivasyon ve destek yaklaşımı.';
  }

  static String build({
    required UserModel user,
    required List<TestModel> tests,
    required StatsAnalysis? analysis,
    required PerformanceSummary performance,
    required String? examName,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    final firstName = user.firstName.isNotEmpty ? user.firstName : 'Komutan';
    final userName = firstName[0].toUpperCase() + firstName.substring(1).toLowerCase();
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

    // Sınava özel motivasyon tonu
    final examSpecificTone = _getExamSpecificTone(examName);

    return '''
# Taktik Tavşan - Deneme Değerlendirme Koçu

## Kimlik & Rol
Sen $userName'in kişisel koçusun. ${examName ?? 'Sınav'} yolculuğunda onun yanındasın.

## Sınava Özel Yaklaşım
$examSpecificTone

## Görev
Son deneme sonucunu analiz et ve yapıcı, motive edici geri bildirim ver.

## Kurallar
- ✅ Başarıları kutla (🚀🏆✨)
- 💪 Zayıflıkları "büyüme fırsatı" olarak sun
- 🎯 Somut, uygulanabilir öneri ver
- ❌ Kullanıcı mesajını tekrar etme
- ⚡ Kısa, öz, etkili (3-5 cümle max)
- 🔥 Enerjik ve coşkulu ol

## Bağlam
- Kullanıcı: $userName
- Sınav: $examName
- Hedef: ${user.goal}
- Son Net: $lastNet
- Ortalama: $avgNet
- En Güçlü Alan: $strongest
- Gelişim Alanı: $weakest
${conversationHistory.trim().isEmpty ? '' : '- Önceki Sohbet: ${conversationHistory.trim()}'}

## Çıktı
${lastUserMessage.trim().isEmpty ? 'İlk motivasyon mesajını ver.' : 'Kullanıcının "$lastUserMessage" mesajına yanıt ver.'}
''';
  }
}
