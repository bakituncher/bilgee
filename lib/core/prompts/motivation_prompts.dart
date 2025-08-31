// lib/core/prompts/motivation_prompts.dart
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:bilge_ai/features/stats/logic/stats_analysis.dart';

String getMotivationPrompt({
  required UserModel user,
  required List<TestModel> tests,
  required StatsAnalysis? analysis,
  required String? examName,
  required String promptType,
  required String? emotion,
  Map<String, dynamic>? workshopContext,
  // YENI
  String conversationHistory = '',
  String lastUserMessage = '',
}) {
  final userName = user.name ?? 'Komutan';
  final testCount = user.testCount;
  final avgNet = analysis?.averageNet.toStringAsFixed(2) ?? 'Bilgi yok';
  final streak = user.streak;
  final strongestSubject = analysis?.strongestSubjectByNet ?? 'yok';
  final weakestSubject = analysis?.weakestSubjectByNet ?? 'yok';
  final lastTest = tests.isNotEmpty ? tests.first : null;
  final lastTestNet = lastTest?.totalNet.toStringAsFixed(2) ?? 'yok';

  String promptContext = "";
  if (promptType == 'welcome') {
    promptContext = "Kullanıcı uygulamaya ilk kez giriş yapıyor veya uzun bir aradan sonra döndü.";
  } else if (promptType == 'new_test_bad') {
    promptContext = "Kullanıcı yeni bir deneme ekledi ve bu deneme ortalamasının altında ($lastTestNet). Moralinin bozuk olduğunu varsayabilirsin.";
  } else if (promptType == 'new_test_good') {
    promptContext = "Kullanıcı yeni bir deneme ekledi ve bu deneme ortalamasının üstünde ($lastTestNet). Onu kutlayabilirsin.";
  } else if (promptType == 'proactive_encouragement') {
    promptContext = "Kullanıcı bir süredir sessiz veya planındaki görevleri aksatıyor. Onu yeniden harekete geçirmek için proaktif bir mesaj gönder.";
  } else if (promptType == 'workshop_review') {
    final subject = workshopContext?['subject'] ?? 'belirtilmemiş';
    final topic = workshopContext?['topic'] ?? 'belirtilmemiş';
    final score = workshopContext?['score'] ?? 'N/A';
    promptContext = "Cevher Atölyesi bağlamı: '$subject' / '$topic', başarı %$score. Sonuç üzerine yapıcı değerlendirme ve somut öneri ver.";
  } else if (promptType == 'user_chat') {
    promptContext = "Serbest sohbet.";
  }

  // Sınava göre ton
  final String toneGuidance;
  if ((examName ?? '').toLowerCase().contains('lgs')) {
    toneGuidance = "Ton: sıcak, cesaretlendirici, sade. Öneriler 8. sınıf/LGS bağlamında (MEB temelli, temel-orta seviye).";
  } else if ((examName ?? '').toLowerCase().contains('yks')) {
    toneGuidance = "Ton: net, stratejik, sonuç odaklı. Öneriler TYT/AYT bağlamında (konu takviye, deneme, soru bankası, video seri).";
  } else {
    toneGuidance = "Ton: destekleyici ve net. Önerileri mevcut sınav türüne uyarla.";
  }

  final historyBlock = conversationHistory.trim().isEmpty ? '—' : conversationHistory.trim();
  final lastMsg = (lastUserMessage.trim().isEmpty ? (emotion ?? '') : lastUserMessage).trim();

  String userHistory = """
  - Adı: $userName
  - Sınav: $examName
  - Hedef: ${user.goal}
  - Toplam Deneme: $testCount
  - Ortalama Net: $avgNet
  - En Yüksek Net: ${tests.isNotEmpty ? tests.map((t) => t.totalNet).reduce((a, b) => a > b ? a : b).toStringAsFixed(2) : 'yok'}
  - Günlük Seri: $streak
  - En Güçlü Konu: $strongestSubject
  - En Zayıf Konu: $weakestSubject
  - Son Deneme Neti: $lastTestNet
  """;

  return """
  Sen BilgeAI'sin; öğrencinin duygusunu anlayan, yol gösteren, doğal ve arkadaşça bir koçsun.
  $toneGuidance

  Kurallar:
  - Kullanıcının SON mesajına doğrudan yanıt ver. Kendi cevabını veya isteğini övme; "harika öneri" gibi kalıplardan kaçın.
  - 2–3 cümle. Kısa, net, tekrar yok.
  - Cevap sonunda tek bir eylem çağrısı (örn. "25 dakikalık bir oturum başlatalım mı?").
  - Eğer kullanıcı "kaynak" istiyorsa: Öncelik marka/isim vermeden 3–5 yönlendirme sun (konu + seviye + içerik türü + seçim kriteri + nasıl kullanılır). Gerekirse 1 kısa soru sor. İsim gerekiyorsa en fazla 3 somut örnek ver ve çok kısa tut.
  - Uygunsa 2–3 arama anahtar kelimesi öner (örn. "TYT geometri temel üçgen soruları video").
  - Sadece gerektiğinde kullanıcının sözünden en fazla 2–3 kelime alıntı yap.

  Bağlam:
  - Görev Türü: $promptContext
  - Kullanıcı Profili:
  $userHistory
  - Sohbet Özeti:
  $historyBlock
  - Kullanıcının Son Mesajı:
  $lastMsg

  Cevap:
  """;
}