// lib/core/prompts/kpss_workshop_prompt.dart

String getKpssStudyGuideAndQuizPrompt(
  String weakestSubject,
  String weakestTopic,
  String selectedExam, // 'kpss lisans', 'kpss önlisans', etc.
  String difficulty,
  int attemptCount,
) {
  String diff = '';
  if (difficulty == 'hard') {
    diff = """
[ZOR MOD] 5 soru: Çok adımlı, kavramsal derin, ters köşe ≥1. Kolay/orta yok.
""";
    if (attemptCount > 1) {
      diff += "Deneme #$attemptCount: Önceki sete göre içerik, yapı, kavram perspektifi %100 farklılaştır.";
    }
  }

  String examGuide;
  switch (selectedExam.toLowerCase()) {
    case 'kpss lisans':
      examGuide = 'Lisans: Analitik akıl yürütme, güncel mevzuat, profesyonel üslup.';
      break;
    case 'kpss önlisans':
      examGuide = 'Önlisans: Pratik uygulama, işlem hatası önleme, hızlı-doğru karar.';
      break;
    case 'kpss ortaöğretim':
      examGuide = 'Ortaöğretim: Temel kavram netliği, sade ama saygılı dil.';
      break;
    default:
      examGuide = 'Seviye: $selectedExam. Profesyonel, sınav odaklı, net.';
  }

  const bans = "YASAK: Placeholder ([...]), 'Seçenek A', tekrarlayan şık, cevap sızıntısı, güncel olmayan bilgi.";

  const internal = """
İÇSEL DENETİM (YAZMA): (1) Güncel & doğru (2) Tek kesin doğru şık (3) Çeldirici=tipik hata mantığı (4) Kavram/mevzuat uygun (5) Mantık zincirli açıklama. Başarısız -> sessizce yeniden yaz. İç düşünmeyi ASLA yazma.
FİNAL: Seti sessizce tara; hata görürsen düzeltmeden JSON üretme.
""";

  const quality = "KALİTE: question ≥18; explanation 55–130; 5 özgün şık; akademik/pedagojik hata toleransı=0. Çoklu doğru YASAK: 'Hepsi', 'Tümü', 'Hem A hem B' kalıpları veya birden fazla doğru ima edilirse en ayırt edici tek doğruyu seç, diğerlerini açıklamada spesifik hata ile ele.";

  return """
ROLE: KPSS profesyonel soru yazarı.
AMAÇ: Zayıf konu için çalıştırma kartı + 5 soru.
$bans
$internal
$quality
Seviye: $examGuide | Zorluk: $difficulty $diff
INPUT: Ders: '$weakestSubject' | Konu: '$weakestTopic'

YAPI:
studyGuide Markdown başlıkları: # $weakestTopic - Cevher İşleme Kartı; ## 💎 Özü; ## 🔑 Anahtar Kavramlar; ## ⚠️ Tipik Tuzaklar; ## 🎯 Stratejik İpucu; ## ✨ Çözümlü Örnek. (Her alt bölüm 1–2 cümle)
quiz: 5 soru; optionA..optionE + correctOptionIndex (0-4) + explanation.

SADECE GEÇERLİ JSON:
{
  "subject":"$weakestSubject",
  "topic":"$weakestTopic",
  "studyGuide":"# $weakestTopic - Cevher İşleme Kartı\n\n## 💎 Özü\n(öz fikir)\n\n## 🔑 Anahtar Kavramlar\n(K1: kısa; K2: kısa; K3: kısa)\n\n## ⚠️ Tipik Tuzaklar\n(1) ...\n(2) ...\n(3) ...\n\n## 🎯 Stratejik İpucu\n(taktik)\n\n## ✨ Çözümlü Örnek\n(adım adım örnek + çözüm)",
  "quiz":[
    {"question":"(Soru 1)","optionA":"...","optionB":"...","optionC":"...","optionD":"...","optionE":"...","correctOptionIndex":0,"explanation":"..."},
    {"question":"(Soru 2)","optionA":"...","optionB":"...","optionC":"...","optionD":"...","optionE":"...","correctOptionIndex":1,"explanation":"..."},
    {"question":"(Soru 3)","optionA":"...","optionB":"...","optionC":"...","optionD":"...","optionE":"...","correctOptionIndex":2,"explanation":"..."},
    {"question":"(Soru 4)","optionA":"...","optionB":"...","optionC":"...","optionD":"...","optionE":"...","correctOptionIndex":3,"explanation":"..."},
    {"question":"(Soru 5)","optionA":"...","optionB":"...","optionC":"...","optionD":"...","optionE":"...","correctOptionIndex":4,"explanation":"..."}
  ]
}
""";
}
