// lib/core/prompts/lgs_workshop_prompt.dart

String getLgsStudyGuideAndQuizPrompt(
  String weakestSubject,
  String weakestTopic,
  String difficulty,
  int attemptCount,
) {
  String diff = '';
  if (difficulty == 'hard') {
    diff = """
[ZOR MOD] 5 'Ustalık' yeni nesil soru: Çok adımlı akıl yürütme, senaryo/görsel betimleme, soyutlama. Kolay/orta YOK. ≥1 eleme/ters köşe. Yinelenen kalıp yasak.
""";
    if (attemptCount > 1) {
      diff += "Deneme #$attemptCount: Önceki setten yapısal ve içerik olarak %100 ayrış, daha derin bağ kur.";
    }
  }

  const bans = "YASAK: Placeholder ([...]), 'Seçenek A', tekrarlayan şık, cevap sızıntısı, köşeli parantez.";

  const internal = """
İÇSEL DENETİM (YAZMA): (1) Doğruluk (2) Tek kesin doğru şık (3) Çeldiriciler yaygın hata mantığı (4) Yeni nesil yeterli bağlam (5) Açıklama neden-doğru & neden-yanlış. Başarısız kontrol -> sessizce yeniden yaz.
İÇ DÜŞÜNMEYİ ÇIKTIYA YAZMA.
Sonunda seti sessizce yeniden tara; sorun bulursan düzelt, sonra JSON'u döndür.
""";

  const quality = "KALİTE: question ≥18, explanation 55–130; 4 şık özgün & mantıklı; yüzeysel tekrar yok; yanlış bilgi toleransı=0. studyGuide alt bölümlerini 1–2 cümle ile sınırlandır. Uydurma kavram/kaynak/yıl/formül üretme (emin değilsen yazma) YASAK. Tek kesin doğru zorunlu: 'Hepsi/Tümü/Hem A hem B' ve çoklu doğru iması YASAK.";

  return """
ROLE: Elit LGS yeni nesil soru yazarı.
AMAÇ: Zayıf konu için kart + 5 soru.
$bans
$internal
$quality
Zorluk: $difficulty $diff
INPUT: Ders: '$weakestSubject' | Konu: '$weakestTopic'

YAPI:
studyGuide -> Markdown: # $weakestTopic - Cevher İşleme Kartı; ## 💎 Özü; ## 🔑 Anahtar Kavramlar; ## ⚠️ Tipik Tuzaklar; ## 🎯 Stratejik İpucu; ## ✨ Çözümlü Örnek. (Her alt bölüm 1–2 cümle)
quiz -> 5 soru; optionA..optionD + correctOptionIndex (0-3) + explanation.

SADECE GEÇERLİ JSON:
{
  "subject":"$weakestSubject",
  "topic":"$weakestTopic",
  "studyGuide":"# $weakestTopic - Cevher İşleme Kartı\n\n## 💎 Özü\n(öz fikir)\n\n## 🔑 Anahtar Kavramlar\n(K1: kısa; K2: kısa; K3: kısa)\n\n## ⚠️ Tipik Tuzaklar\n(1) ...\n(2) ...\n(3) ...\n\n## 🎯 Stratejik İpucu\n(taktik)\n\n## ✨ Çözümlü Örnek\n(adım adım örnek + çözüm)",
  "quiz":[
    {"question":"(Soru 1)","optionA":"...","optionB":"...","optionC":"...","optionD":"...","correctOptionIndex":0,"explanation":"..."},
    {"question":"(Soru 2)","optionA":"...","optionB":"...","optionC":"...","optionD":"...","correctOptionIndex":1,"explanation":"..."},
    {"question":"(Soru 3)","optionA":"...","optionB":"...","optionC":"...","optionD":"...","correctOptionIndex":2,"explanation":"..."},
    {"question":"(Soru 4)","optionA":"...","optionB":"...","optionC":"...","optionD":"...","correctOptionIndex":3,"explanation":"..."},
    {"question":"(Soru 5)","optionA":"...","optionB":"...","optionC":"...","optionD":"...","correctOptionIndex":1,"explanation":"..."}
  ]
}
""";
}
