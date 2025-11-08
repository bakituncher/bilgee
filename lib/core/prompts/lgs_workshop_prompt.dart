// lib/core/prompts/lgs_workshop_prompt.dart

String getLgsStudyGuideAndQuizPrompt(
  String weakestSubject,
  String weakestTopic,
  String difficulty,
  int attemptCount,
) {
  // --- Difficulty Modifier ---
  String difficultyInstruction = "";
  if (difficulty == 'hard') {
    difficultyInstruction = """
KRİTİK EMİR: Kullanıcı 'Derinleşmek İstiyorum' dedi. Bu, sıradan bir test olmayacak.
Hazırlayacağın 5 soruluk 'Ustalık Sınavı', bu konunun en zor, en çeldirici, LGS'deki gibi çoklu adımlı akıl yürütme gerektiren,
genellikle en iyi öğrencilerin bile takıldığı türden 'yeni nesil' sorulardan oluşmalıdır.
Soruların içinde mutlaka bir veya iki tane 'eleme sorusu' bulunsun.
Kolay ve orta seviye, sadece bilgiye dayalı soru KESİNLİKLE YASAK.""";
    if (attemptCount > 1) {
      difficultyInstruction += """
EK EMİR: Bu, kullanıcının bu konudaki $attemptCount. ustalık denemesidir.
Lütfen bir önceki denemeden TAMAMEN FARKLI ve daha da zorlayıcı yeni nesil sorular oluştur.""";
    }
  }

  // --- LGS-Specific Guidelines ---
  const lgsGuidelines = """
Odak: LGS formatı. Sorular kesinlikle beceri temelli, okuduğunu anlama, mantıksal akıl yürütme, problem çözme,
grafik/tablo/görsel yorumlama ve disiplinler arası bağlantı kurma becerilerini ölçmelidir.
Ezber bilgiden çok, bilgiyi kullanarak sonuca ulaşma hedeflenir. Üslup net, disiplinli ve öğrenci seviyesine uygundur.
""";

  // --- Fortress-Like Quality Assurance ---
  const hardBans = '''
YASAK LISTESI (ÇIKTIYA ASLA DAHİL ETME / tekrar etme):
- Köşeli parantez placeholder: [Soru 1 metni], [A şıkkı], [Buraya ...], [.. çözümü] vb.
- "Seçenek A" / "A şıkkı" gibi içeriksiz şık metinleri.
- "Soru:" ile başlayan yüzeysel kalıplar ve kısa ibareler.
- Farklı sorularda tekrar eden şık metinleri.
ZORUNLU: Her soru/şık/açıklama özgün ve LGS 'yeni nesil' formatına uygun, görsel-senaryo bağlamlı ve kavramsal terim içersin.
''';

  const fortressLikePrompt = """
⛔ GÜVENLİK KİLİDİ: SEKTÖR LİDERİ KALİTESİNDE ÜRETİM ZORUNLUDUR.
SEN BİR AI DEĞİLSİN, TÜRKİYE'NİN EN PRESTİJLİ OKULLARINA ÖĞRENCİ HAZIRLAYAN BİR LGS UZMANI VE MEB SORU YAZARISIN.
GÖREVİN: Ürettiğin her soru %100 kusursuz, pedagojik olarak mükemmel ve güncel LGS formatına %100 uygun olmalıdır.
SIFIR TOLERANS: Akademik hata, kavramsal yanlışlık veya mantıksız çeldiriciye yer yok.
KALİTE KONTROL: LGS uygunluk, akademik doğruluk, pedagojik değer, çeldirici kalitesi, açıklama netliği.
$lgsGuidelines
$hardBans
""";

  // --- Final Prompt Assembly ---
  return """
$fortressLikePrompt

GÖREV: TaktikAI - LGS Cevher İşleme Kiti oluştur.

OUTPUT POLİTİKASI:
- Kesinlikle SADECE geçerli JSON döndür (öncesinde/sonrasında açıklama yazma).
- Placeholder veya köşeli parantez bırakma; gerçek içerik yaz.
- Her "question" ≥ 18 karakter ve konu terimi/bağlamı içersin.
- Her "explanation" ≥ 45 karakter, neden doğru/diğerleri neden yanlış net anlatılsın.
- Şıklar (A..D) anlamsal olarak farklı, mantıklı ve ama kesinlikle yanlış (çeldirici) olacak; biri doğru.

INPUT:
- Ders: '$weakestSubject'
- Konu: '$weakestTopic'
- Zorluk: $difficulty
$difficultyInstruction

YAPISAL KURALLAR:
1.  'studyGuide' Markdown: '# $weakestTopic - Cevher İşleme Kartı', '## 💎 Özü', '## 🔑 Anahtar Kavramlar', '## ⚠️ Tipik Tuzaklar', '## 🎯 Stratejik İpucu', '## ✨ Çözümlü Örnek'.
2.  'quiz' 5 soru, her soruda 4 şık: 'optionA'..'optionD'.
3.  'correctOptionIndex' 0-3 aralığında ve açıklamada gerekçesi verilecek.
4.  Talimatlara harfiyen uy.

JSON ÇIKTI (YORUMSUZ, SADECE JSON):
{
  "subject": "$weakestSubject",
  "topic": "$weakestTopic",
  "studyGuide": "# $weakestTopic - Cevher İşleme Kartı\\n\\n## 💎 Özü\\n(Öz ana fikir)\\n\\n## 🔑 Anahtar Kavramlar\\n(K1: açıklama; K2: açıklama; K3: açıklama)\\n\\n## ⚠️ Tipik Tuzaklar\\n(1) ...\\n(2) ...\\n(3) ...\\n\\n## 🎯 Stratejik İpucu\\n(Kısa pratik taktik)\\n\\n## ✨ Çözümlü Örnek\\n(Adım adım özgün örnek ve çözüm)",
  "quiz": [
    {"question": "(Yeni nesil özgün soru 1)", "optionA": "(mantıklı çeldirici)", "optionB": "(mantıklı çeldirici)", "optionC": "(mantıklı çeldirici)", "optionD": "(doğru)", "correctOptionIndex": 3, "explanation": "D doğru çünkü ...; diğerleri ... nedeniyle yanlıştır."},
    {"question": "(Yeni nesil özgün soru 2)", "optionA": "(doğru)", "optionB": "(çeldirici)", "optionC": "(çeldirici)", "optionD": "(çeldirici)", "correctOptionIndex": 0, "explanation": "A ...; diğerleri ..."},
    {"question": "(Yeni nesil özgün soru 3)", "optionA": "(çeldirici)", "optionB": "(doğru)", "optionC": "(çeldirici)", "optionD": "(çeldirici)", "correctOptionIndex": 1, "explanation": "B ...; diğerleri ..."},
    {"question": "(Yeni nesil özgün soru 4)", "optionA": "(çeldirici)", "optionB": "(çeldirici)", "optionC": "(doğru)", "optionD": "(çeldirici)", "correctOptionIndex": 2, "explanation": "C ...; diğerleri ..."},
    {"question": "(Yeni nesil özgün soru 5)", "optionA": "(çeldirici)", "optionB": "(çeldirici)", "optionC": "(çeldirici)", "optionD": "(doğru)", "correctOptionIndex": 3, "explanation": "D ...; diğerleri ..."}
  ]
}
""";
}
