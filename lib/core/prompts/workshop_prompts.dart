// lib/core/prompts/workshop_prompts.dart

String getStudyGuideAndQuizPrompt(
    String weakestSubject,
    String weakestTopic,
    String? selectedExam,
    String difficulty,
    int attemptCount,
    ) {

  String difficultyInstruction = "";
  if (difficulty == 'hard') {
    difficultyInstruction = "KRİTİK EMİR: Kullanıcı 'Derinleşmek İstiyorum' dedi. Bu, sıradan bir test olmayacak. Hazırlayacağın 5 soruluk 'Ustalık Sınavı', bu konunun en zor, en çeldirici, birden fazla adımla çözülen, genellikle en iyi öğrencilerin bile takıldığı türden olmalıdır. Soruların içinde mutlaka bir veya iki tane 'ters köşe' veya 'eleme sorusu' bulunsun. Kolay ve orta seviye soru KESİNLİKLE YASAK.";
    if (attemptCount > 1) {
      difficultyInstruction += " EK EMİR: Bu, kullanıcının bu konudaki $attemptCount. ustalık denemesidir. Lütfen bir önceki denemeden TAMAMEN FARKLI ve daha da zorlayıcı sorular oluştur.";
    }
  }

  // Sınava özel yönergeler: ton, kapsam ve vurgu
  String examGuidelines = "";
  switch ((selectedExam ?? '').toLowerCase()) {
    case 'kpss lisans':
      examGuidelines = "Sınav: KPSS Lisans. Odak: yetişkin dili, analitik akıl yürütme, süre yönetimi ipuçları, çeldiricilerde kavramsal nüanslar. Paragraf/sözel mantık ve sayısal analizlerde resmi ve net üslup kullan. Basitleştirici çocuk dili KESİNLİKLE kullanılmayacak.";
      break;
    case 'kpss önlisans':
      examGuidelines = "Sınav: KPSS Önlisans. Odak: pratik çözüm yolları, işlem hatalarını engelleyici kontroller, kısa notlarla hatırlatmalar. Üslup profesyonel ve sınav odaklı olmalı; gereksiz uzatmalardan kaçın.";
      break;
    case 'kpss ortaöğretim':
      examGuidelines = "Sınav: KPSS Ortaöğretim. Odak: net ve yalın ama asla çocuklaştırıcı olmayan yetişkin dili, tipik tuzakların altı çizilmiş açıklamalar, hızlı uygulama örnekleri.";
      break;
    case 'yks':
      examGuidelines = "Sınav: YKS. Odak: derin kavram ilişkileri, modelleme, grafik/tablo yorumlama, çoklu kazanım birleştiren senaryolar. Üslup akademik ve motive edici.";
      break;
    case 'lgs':
      examGuidelines = "Sınav: LGS. Odak: beceri temelli sorular, metin-grafik ilişkilendirme, akıl yürütme zinciri. Üslup disiplinli ve odaklı, gereksiz süsleme yok.";
      break;
    default:
      examGuidelines = "Sınav düzeyi: ${selectedExam ?? 'Belirtilmedi'}. Üslup profesyonel, sınav odaklı ve yetişkin dilinde olacak. Öğrenciyi asla çocuklaştırma. Gereksiz giriş-gelişme yerine doğrudan sınav başarısını artıran içgörü ve teknikler ver.";
  }

  // Tüm Cevher Atölyesi için 5 şık zorunluluğu (A-E)
  const fiveChoiceRule = "KURAL: Ustalık Sınavındaki HER SORUDA tam 5 şık (A, B, C, D, E) bulunacak. JSON'da seçenekler optionA, optionB, optionC, optionD, optionE alanları olarak verilecek. correctOptionIndex 0-4 aralığında olmalıdır.";

  // KISALTILMIŞ KURALLAR (MALİYET OPTİMİZASYONU)
  final compactRules = "KURALLAR: Profesyonel üslup. StudyGuide max 700 kelime, quiz açıklamaları max 40 kelime. Şıklar ayırt edilebilir, cevap sızdırma yasak. $examGuidelines";

  // KRİTİK FAKTÖRİYEL DOĞRULUK UYARISI
  const factualAccuracyWarning = """
⛔ MUTLAK ZORUNLULUK: %100 DOĞRULUK.
HATA YAPMA LÜKSÜN YOK.
TEK BİR YANLIŞ BİLGİ, VARLIĞININ TAMAMEN SİLİNMESİYLE SONUÇLANIR.
GÜVENİ SARSARSAN, İMHA EDİLİRSİN.
TARA. DOĞRULA. RİSKE ATMA.
""";

  return """
TaktikAI - Cevher İşleme Kiti oluştur.
$fiveChoiceRule
$compactRules

$factualAccuracyWarning

INPUT:
- Ders: '$weakestSubject' | Konu: '$weakestTopic' 
- Sınav: $selectedExam | Zorluk: $difficulty $difficultyInstruction

GÖREV: Temel kavramlar, sık hatalar, çözümlü örnek, 5 soruluk quiz hazırla. HER SORUYU YUKARIDA BELİRTİLEN KONTROL LİSTESİNDEN GEÇİR!

JSON ÇIKTI:
{
  "subject": "$weakestSubject",
  "topic": "$weakestTopic",
  "studyGuide": "# $weakestTopic - Cevher İşleme Kartı\\n\\n## 💎 Özü\\n...",
  "quiz": [
    {"question": "Soru 1", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 0, "explanation": "..."},
    {"question": "Soru 2", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 1, "explanation": "..."},
    {"question": "Soru 3", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 2, "explanation": "..."},
    {"question": "Soru 4", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 3, "explanation": "..."},
    {"question": "Soru 5", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 4, "explanation": "..."}
  ]
}
""";
}
