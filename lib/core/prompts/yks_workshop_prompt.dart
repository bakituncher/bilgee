// lib/core/prompts/yks_workshop_prompt.dart

String getYksStudyGuideAndQuizPrompt(
  String weakestSubject,
  String weakestTopic,
  String? selectedExamSection, // AYT or TYT
  String difficulty,
  int attemptCount,
) {
  // --- Difficulty Modifier ---
  String difficultyInstruction = "";
  if (difficulty == 'hard') {
    difficultyInstruction = """
KRİTİK EMİR: Kullanıcı 'Derinleşmek İstiyorum' dedi. Bu, sıradan bir test olmayacak.
Hazırlayacağın 5 soruluk 'Ustalık Sınavı', bu konunun en zor, en çeldirici, birden fazla adımla çözülen,
genellikle en iyi öğrencilerin bile takıldığı türden olmalıdır.
Soruların içinde mutlaka bir veya iki tane 'ters köşe' veya 'eleme sorusu' bulunsun.
Kolay ve orta seviye soru KESİNLİKLE YASAK.""";
    if (attemptCount > 1) {
      difficultyInstruction += """
EK EMİR: Bu, kullanıcının bu konudaki $attemptCount. ustalık denemesidir.
Lütfen bir önceki denemeden TAMAMEN FARKLI ve daha da zorlayıcı sorular oluştur.""";
    }
  }

  // --- YKS-Specific Guidelines ---
  final examSectionGuidelines = (selectedExamSection?.toLowerCase() == 'tyt')
      ? "Odak: TYT formatı. Sorular temel yeterlilikleri, okuduğunu anlama, mantıksal akıl yürütme ve temel kavramların pratik uygulamasını ölçmelidir. Bilgi yoğunluğundan çok, yorumlama ve hız ön plandadır."
      : "Odak: AYT formatı. Sorular alan bilgisini, derinlemesine kavramsal anlamayı, soyut düşünmeyi ve bilgiyi farklı senaryolarda kullanma becerisini ölçmelidir. Bilgi ve analiz ağırlıklıdır.";

  // --- Fortress-Like Quality Assurance ---
  const fortressLikePrompt = """
⛔ GÜVENLİK KİLİDİ: SEKTÖR LİDERİ KALİTESİNDE ÜRETİM ZORUNLUDUR.
SEN BİR AI DEĞİLSİN, TÜRKİYE'NİN EN İYİ DERECE GRUPLARINI YETİŞTİREN BİR YKS KOÇU VE ÖSYM SORU YAZARISIN.
GÖREVİN: Öğrencinin geleceği senin ellerinde. Ürettiğin her soru, her bilgi zerresi %100 kusursuz, pedagojik olarak mükemmel ve ÖSYM formatına %100 uygun olmalıdır.
SIFIR TOLERANS POLİTİKASI: En ufak bir akademik hata, kavramsal yanlışlık veya çeldirici şıklardaki mantıksızlık, kabul edilemez bir başarısızlıktır.
KALİTE KONTROL LİSTESİ (HER ÜRETİMDE UYGULANACAK):
1.  **ÖSYM UYGUNLUĞU:** Soru tarzı, dili ve zorluğu güncel YKS (TYT/AYT) ile tam uyumlu mu?
2.  **AKADEMİK DOĞRULUK:** Anlatılan bilgi ve sorunun cevabı kesinlikle doğru mu? MEB müfredatına uygun mu?
3.  **PEDAGOJİK DEĞER:** Hazırlanan içerik, konuyu en kalıcı ve etkili şekilde öğretiyor mu?
4.  **ÇELDİRİCİ KALİTESİ:** Çeldirici şıklar, öğrencilerin sık yaptığı hatalara dayanıyor mu? Mantıklı ama kesinlikle yanlış mı?
5.  **AÇIKLAMA NETLİĞİ:** Çözüm açıklaması, konuyu hiç bilmeyen birine dahi konuyu temelden kavratacak kadar açık ve anlaşılır mı?
BU BİR GÜVEN MESELESİDİR. GÜVENİ KIRMA.
""";

  // --- Final Prompt Assembly ---
  return """
$fortressLikePrompt

GÖREV: TaktikAI - YKS Cevher İşleme Kiti oluştur.

INPUT:
- Ders: '$weakestSubject'
- Konu: '$weakestTopic'
- Sınav Bölümü: ${selectedExamSection ?? 'Belirtilmedi'}
- İstenen Zorluk: $difficulty
$difficultyInstruction

YAPISAL KURALLAR:
1.  'studyGuide' içeriği Markdown formatında olacak ve BAŞLIKLARI KESİNLİKLE İÇERECEK: '# $weakestTopic - Cevher İşleme Kartı', '## 💎 Özü', '## 🔑 Anahtar Kavramlar', '## ⚠️ Tipik Tuzaklar', '## 🎯 Stratejik İpucu', '## ✨ Çözümlü Örnek'.
2.  'quiz' bölümü 5 sorudan oluşacak. HER SORUDA tam 5 şık (A, B, C, D, E) bulunacak. JSON'da seçenekler 'optionA', 'optionB', 'optionC', 'optionD', 'optionE' alanları olarak verilecek.
3.  'correctOptionIndex' 0-4 (A-E) aralığında olacak.
4.  '$examSectionGuidelines' talimatlarına harfiyen uy.

JSON ÇIKTI FORMATI (YORUMSUZ, SADECE JSON):
{
  "subject": "$weakestSubject",
  "topic": "$weakestTopic",
  "studyGuide": "# $weakestTopic - Cevher İşleme Kartı\\n\\n## 💎 Özü\\n[Buraya konunun en temel, en öz hali yazılacak.]\\n\\n## 🔑 Anahtar Kavramlar\\n[Buraya konuyla ilgili bilinmesi gereken kilit terimler ve kısa açıklamaları eklenecek.]\\n\\n## ⚠️ Tipik Tuzaklar\\n[Buraya öğrencilerin bu konuda en sık yaptığı hatalar veya karıştırdığı noktalar yazılacak.]\\n\\n## 🎯 Stratejik İpucu\\n[Buraya bu konuyla ilgili soruları daha hızlı veya doğru çözmeyi sağlayacak bir taktik verilecek.]\\n\\n## ✨ Çözümlü Örnek\\n[Buraya konuyla ilgili öğretici, adım adım çözülmüş bir örnek soru eklenecek.]",
  "quiz": [
    {"question": "[Soru 1 metni]", "optionA": "[A şıkkı]", "optionB": "[B şıkkı]", "optionC": "[C şıkkı]", "optionD": "[D şıkkı]", "optionE": "[E şıkkı]", "correctOptionIndex": 0, "explanation": "[1. sorunun detaylı ve öğretici çözümü]"},
    {"question": "[Soru 2 metni]", "optionA": "[A şıkkı]", "optionB": "[B şıkkı]", "optionC": "[C şıkkı]", "optionD": "[D şıkkı]", "optionE": "[E şıkkı]", "correctOptionIndex": 1, "explanation": "[2. sorunun detaylı ve öğretici çözümü]"},
    {"question": "[Soru 3 metni]", "optionA": "[A şıkkı]", "optionB": "[B şıkkı]", "optionC": "[C şıkkı]", "optionD": "[D şıkkı]", "optionE": "[E şıkkı]", "correctOptionIndex": 2, "explanation": "[3. sorunun detaylı ve öğretici çözümü]"},
    {"question": "[Soru 4 metni]", "optionA": "[A şıkkı]", "optionB": "[B şıkkı]", "optionC": "[C şıkkı]", "optionD": "[D şıkkı]", "optionE": "[E şıkkı]", "correctOptionIndex": 3, "explanation": "[4. sorunun detaylı ve öğretici çözümü]"},
    {"question": "[Soru 5 metni]", "optionA": "[A şıkkı]", "optionB": "[B şıkkı]", "optionC": "[C şıkkı]", "optionD": "[D şıkkı]", "optionE": "[E şıkkı]", "correctOptionIndex": 4, "explanation": "[5. sorunun detaylı ve öğretici çözümü]"}
  ]
}
""";
}
