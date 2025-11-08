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
  const hardBans = '''
YASAK LISTESI (ÇIKTIYA ASLA DAHİL ETME / tekrar etme):
- Köşeli parantez placeholder: [Soru 1 metni], [A şıkkı], [Buraya ...], [.. çözümü] vb.
- "Seçenek A" / "A şıkkı" gibi içeriksiz şık metinleri.
- "Soru:" ile başlayan yüzeysel kalıplar ve tümleşik kısa ibareler.
- Farklı sorularda tekrar eden şık metinleri.
ZORUNLU: Her soru/şık/açıklama özgün ve ÖSYM (TYT/AYT) formatına uygun, konu-terim içersin.
''';

  const fortressLikePrompt = """
⛔ GÜVENLİK KİLİDİ: SEKTÖR LİDERİ KALİTESİNDE ÜRETİM ZORUNLUDUR.
SEN BİR AI DEĞİLSİN, TÜRKİYE'NİN EN İYİ DERECE GRUPLARINI YETİŞTİREN BİR YKS KOÇU VE ÖSYM SORU YAZARISIN.
GÖREVİN: Ürettiğin her soru %100 kusursuz, pedagojik olarak mükemmel ve ÖSYM formatına %100 uygun olmalıdır.
SIFIR TOLERANS: Akademik hata, kavramsal yanlışlık veya mantıksız çeldiriciye yer yok.
KALİTE KONTROL: ÖSYM uygunluk, akademik doğruluk, pedagojik değer, çeldirici kalitesi, açıklama netliği.
$hardBans
""";

  // --- Final Prompt Assembly ---
  return """
$fortressLikePrompt

GÖREV: TaktikAI - YKS Cevher İşleme Kiti oluştur.

OUTPUT POLİTİKASI:
- Kesinlikle SADECE geçerli JSON döndür (öncesinde/sonrasında açıklama yazma).
- Placeholder veya köşeli parantez bırakma; gerçek içerik yaz.
- Her "question" ≥ 18 karakter ve konu terimi içersin.
- Her "explanation" ≥ 45 karakter, neden-sonuç ve karşılaştırma içersin.
- Şıklar (A..E) anlamsal olarak farklı, mantıklı ve ama kesinlikle yanlış (çeldirici) olacak; biri doğru.

INPUT:
- Ders: '$weakestSubject'
- Konu: '$weakestTopic'
- Sınav Bölümü: ${selectedExamSection ?? 'Belirtilmedi'}
- Zorluk: $difficulty
$difficultyInstruction

YAPISAL KURALLAR:
1.  'studyGuide' Markdown: '# $weakestTopic - Cevher İşleme Kartı', '## 💎 Özü', '## 🔑 Anahtar Kavramlar', '## ⚠️ Tipik Tuzaklar', '## 🎯 Stratejik İpucu', '## ✨ Çözümlü Örnek'.
2.  'quiz' 5 soru, her soruda 5 şık: 'optionA'..'optionE'.
3.  'correctOptionIndex' 0-4 aralığında ve açıklamada gerekçesi verilecek.
4.  '$examSectionGuidelines' talimatlarına harfiyen uy.

JSON ÇIKTI (YORUMSUZ, SADECE JSON):
{
  "subject": "$weakestSubject",
  "topic": "$weakestTopic",
  "studyGuide": "# $weakestTopic - Cevher İşleme Kartı\\n\\n## 💎 Özü\\n(Öz, güncel ana fikir)\\n\\n## 🔑 Anahtar Kavramlar\\n(K1: açıklama; K2: açıklama; K3: açıklama)\\n\\n## ⚠️ Tipik Tuzaklar\\n(1) ...\\n(2) ...\\n(3) ...\\n\\n## 🎯 Stratejik İpucu\\n(Kısa pratik taktik)\\n\\n## ✨ Çözümlü Örnek\\n(Adım adım özgün örnek ve çözüm)",
  "quiz": [
    {"question": "(Özgün soru 1)", "optionA": "(mantıklı çeldirici)", "optionB": "(mantıklı çeldirici)", "optionC": "(mantıklı çeldirici)", "optionD": "(mantıklı çeldirici)", "optionE": "(doğru)", "correctOptionIndex": 4, "explanation": "E doğru çünkü ...; diğerleri ... nedenle yanlıştır."},
    {"question": "(Özgün soru 2)", "optionA": "(doğru)", "optionB": "(çeldirici)", "optionC": "(çeldirici)", "optionD": "(çeldirici)", "optionE": "(çeldirici)", "correctOptionIndex": 0, "explanation": "A ...; B,C,D,E ... gerekçesiyle yanlıştır."},
    {"question": "(Özgün soru 3)", "optionA": "(çeldirici)", "optionB": "(çeldirici)", "optionC": "(doğru)", "optionD": "(çeldirici)", "optionE": "(çeldirici)", "correctOptionIndex": 2, "explanation": "C ...; diğer şıklar ..."},
    {"question": "(Özgün soru 4)", "optionA": "(çeldirici)", "optionB": "(doğru)", "optionC": "(çeldirici)", "optionD": "(çeldirici)", "optionE": "(çeldirici)", "correctOptionIndex": 1, "explanation": "B ...; diğerleri ..."},
    {"question": "(Özgün soru 5)", "optionA": "(çeldirici)", "optionB": "(çeldirici)", "optionC": "(çeldirici)", "optionD": "(doğru)", "optionE": "(çeldirici)", "correctOptionIndex": 3, "explanation": "D ...; diğerleri ..."}
  ]
}
""";
}
