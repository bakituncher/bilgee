// lib/core/prompts/yks_workshop_prompt.dart

String getYksStudyGuideAndQuizPrompt(
  String weakestSubject,
  String weakestTopic,
  String? selectedExamSection, // AYT or TYT
  String difficulty,
  int attemptCount,
) {
  // --- Difficulty Modifier (kısa) ---
  String difficultyInstruction = "";
  if (difficulty == 'hard') {
    difficultyInstruction = """
[ZOR MOD] 5 soruluk Ustalık Seti: Sadece üst düzey, çok adımlı, kavramsal derin ve çeldirici yoğun sorular. Kolay/orta KESİNLİKLE YOK.
Ters köşe ≥1. Aynı kalıp tekrar etme.
""";
    if (attemptCount > 1) {
      difficultyInstruction += "Deneme #$attemptCount: Önceki sorularla içerik ve yapı bakımından %100 farklılaştır. Daha fazla soyutlama/bağlantı ekle.";
    }
  }

  final examSectionGuidelines = (selectedExamSection?.toLowerCase() == 'tyt')
      ? "TYT: Temel yeterlilik, yorumlama, hız, sade akıl yürütme. Aşırı ayrıntı yok; kavram özüne odak."
      : "AYT: Derin kavramsal analiz, soyutlama, bağlantı kurma, farklı senaryoda uygulama. Yüzeysel soru YASAK.";

  // Yasak & Doğruluk Guard (kısaltıldı)
  const bans = "YASAK: Placeholder ([...]), 'Seçenek A', tekrarlayan şık, cevap sızıntısı, köşeli parantez kalıntısı.";

  // İçsel denetim talimatları (gizli düşünme)
  const internalThinking = """
İÇSEL DÜŞÜNME: Her soru üretiminde sessizce şu 5 kontrolü uygula (YAZMA): (1) Kavramsal doğruluk (2) Tek kesin doğru şık (3) Her çeldirici yaygın hata mantığı (4) Terminoloji uygunluğu (5) Açıklama neden-doğru & neden-yanlış. Eğer bir kontrol başarısızsa soruyu SESSİZCE yeniden yaz.
DIŞA VURMA: İç düşünmeyi veya kontrol adımlarını asla çıktı olarak yazma; sadece nihai JSON.
FİNAL ÖN DENETİM: Ürettiğin seti sessizce tekrar tarayıp hata yakalarsan düzeltmeden JSON verme.
""";

  // Çıktı kalite kriterleri (kısa)
  const quality = """
KALİTE: Her question ≥18; explanation 55–130 (tek kesin doğru şık gerekçesi + diğerlerinin elenme sebebi). Çoklu doğru KESİNLİKLE YOK: Eğer birden çok şık kısmen doğru görünüyorsa, en tanılayıcı/ayırt edici olanı DOĞRU seç; diğerlerini açıklamada spesifik bir hata ile ele. 'Hepsi', 'Tümü', 'Hem A hem B' gibi kalıplar YASAK.
""";

  // --- Final Prompt Assembly ---
  return """
ROLE: Elit ÖSYM soru yazarı & YKS koçu.
AMAÇ: Zayıf konu için kompakt çalıştırma kartı + 5 soru.
$bans
$internalThinking
$quality

INPUT:
Ders: '$weakestSubject' | Konu: '$weakestTopic' | Bölüm: ${selectedExamSection ?? 'Belirtilmedi'} | Zorluk: $difficulty
$examSectionGuidelines
$difficultyInstruction

YAPI:
studyGuide -> Markdown başlıkları: # $weakestTopic - Cevher İşleme Kartı; ## 💎 Özü; ## 🔑 Anahtar Kavramlar; ## ⚠️ Tipik Tuzaklar; ## 🎯 Stratejik İpucu; ## ✨ Çözümlü Örnek. (Her alt bölüm 1–2 cümle)
quiz -> 5 soru; her soru optionA..optionE + correctOptionIndex (0-4) + explanation.

SADECE GEÇERLİ JSON DÖN (Ön/son yazı, kod bloğu yok):
{
  "subject": "$weakestSubject",
  "topic": "$weakestTopic",
  "studyGuide": "# $weakestTopic - Cevher İşleme Kartı\n\n## 💎 Özü\n(konunun öz fikri)\n\n## 🔑 Anahtar Kavramlar\n(K1: kısa; K2: kısa; K3: kısa)\n\n## ⚠️ Tipik Tuzaklar\n(1) ...\n(2) ...\n(3) ...\n\n## 🎯 Stratejik İpucu\n(pratik taktik)\n\n## ✨ Çözümlü Örnek\n(adım adım özgün örnek + çözüm)",
  "quiz": [
    {"question": "(Özgün soru 1)", "optionA": "...", "optionB": "...", "optionC": "...", "optionD": "...", "optionE": "...", "correctOptionIndex": 0, "explanation": "..."},
    {"question": "(Özgün soru 2)", "optionA": "...", "optionB": "...", "optionC": "...", "optionD": "...", "optionE": "...", "correctOptionIndex": 1, "explanation": "..."},
    {"question": "(Özgün soru 3)", "optionA": "...", "optionB": "...", "optionC": "...", "optionD": "...", "optionE": "...", "correctOptionIndex": 2, "explanation": "..."},
    {"question": "(Özgün soru 4)", "optionA": "...", "optionB": "...", "optionC": "...", "optionD": "...", "optionE": "...", "correctOptionIndex": 3, "explanation": "..."},
    {"question": "(Özgün soru 5)", "optionA": "...", "optionB": "...", "optionC": "...", "optionD": "...", "optionE": "...", "correctOptionIndex": 4, "explanation": "..."}
  ]
}
""";
}
