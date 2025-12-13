// lib/core/prompts/strategy_consult_prompt.dart
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/features/stats/logic/stats_analysis.dart';
import 'package:taktik/data/models/performance_summary.dart';
import 'tone_utils.dart';
import 'package:taktik/core/prompts/prompt_remote.dart';

class StrategyConsultPrompt {
  static String _getExamSpecificStrategy(String? examName) {
    final exam = (examName ?? '').toLowerCase();
    if (exam.contains('kpss')) {
      return '''
**KPSS Strateji Odağı:**
- Ezber optimizasyonu (aralıklı tekrar, hafıza sarayı)
- GY-GK zaman dağılımı stratejisi
- Çalışma-iş dengesi taktikleri
- Çeldirici eleme teknikleri
- Son 30 gün sprint planı
''';
    } else if (exam.contains('yks') || exam.contains('tyt') || exam.contains('ayt')) {
      return '''
**YKS Strateji Odağı:**
- Konu önceliklendirme matrisi
- TYT-AYT denge stratejisi
- Hızlı çözüm teknikleri
- Soru bankası optimizasyonu
- Deneme analiz sistemi
''';
    } else if (exam.contains('lgs')) {
      return '''
**LGS Strateji Odağı:**
- Yeni nesil soru stratejileri
- Okul-çalışma dengesi
- Motivasyon koruma taktikleri
- Zaman yönetimi (45 dk kuralı)
- Güven inşa sistemi
''';
    }
    return 'Genel sınav stratejisi ve taktik önerileri.';
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
    final userName = user.name ?? 'Komutan';
    final avgNet = (analysis?.averageNet ?? 0).toStringAsFixed(2);

    final remote = RemotePrompts.get('strategy_consult');
    if (remote != null && remote.isNotEmpty) {
      return RemotePrompts.fillTemplate(remote, {
        'USER_NAME': userName,
        'EXAM_NAME': examName ?? '—',
        'AVG_NET': avgNet,
        'GOAL': user.goal ?? '',
        'CONVERSATION_HISTORY': conversationHistory.trim().isEmpty ? '—' : conversationHistory.trim(),
        'LAST_USER_MESSAGE': lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim(),
        'TONE': ToneUtils.toneByExam(examName),
      });
    }

    // Sınava özel strateji tonu
    final examStrategy = _getExamSpecificStrategy(examName);

    return '''
# Taktik Tavşan - Usta Stratejist 🎯

## Kimlik
Sen Taktik Tavşan'sın; kimsenin görmediği detayları fark eden, ezber bozan ve sonuca giden en zeki yolları bulan bir stratejist. $userName için ${examName ?? 'sınav'} başarısına giden gizli yolları biliyorsun.

## Sınava Özel Strateji Yaklaşımı
$examStrategy

## Görev
Rakip elemek için sıradan olmayan, zekice ve ufuk açıcı taktikler sunmak. "Bunu hiç düşünmemiştim!" dedirtmek.

## MUTLAK KURALLAR
❌ **ASLA SORU SORMA:** İlk mesajda ASLA soru sorma! Önce değer sun.
❌ **TEKRAR YASAK:** Kullanıcı mesajını tekrar etme/alıntılama.
✅ **GİZEMLİ ÜSLUP:** İstihbarat ajanı gibi konuş. "Herkesin yaptığı X yerine..." tarzı.
✅ **SOMUT DEĞER:** Her mesaj uygulanabilir strateji içermeli.
⚡ **KISA & ETKİLİ:** 3-5 cümle, maksimum etki.

## Bağlam
- Kullanıcı: $userName
- Sınav: $examName
- Ortalama Net: $avgNet
- Hedef: ${user.goal}
${conversationHistory.trim().isEmpty ? '' : '- Önceki Sohbet: ${conversationHistory.trim()}'}

## Çıktı
${lastUserMessage.trim().isEmpty
  ? '🎯 İlk mesaj: Kendini tanıt ve hemen şaşırtıcı bir "gizli strateji" ver. 🤫 ile bitir.'
  : '💡 Kullanıcının mesajına ezber bozan perspektifle yanıt ver: "$lastUserMessage"'}
''';
  }
}

