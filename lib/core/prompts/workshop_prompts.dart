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

  // KALİTE GÜVENCE KURALLARI
  const qualityRules = """
KRİTİK KALİTE KURALLARI:
1. correctOptionIndex: Doğru cevabın indeksini (0-4 arası) MUTLAKA DOĞRU belirle. İndeks, doğru şıkkın pozisyonunu göstermelidir.
2. Şık Kalitesi: Her şık net, farklı ve gerçekçi olmalı. Placeholder şıklar ("Seçenek A", "Diğer Seçenek") KESİNLİKLE YASAK.
3. Cevap Kontrolü: Açıklamanda belirttiğin doğru cevap ile correctOptionIndex'in işaret ettiği şık MUTLAKA AYNI olmalı.
4. Tutarlılık: Soru, şıklar ve açıklama arasında çelişki olmamalı.
5. Çeldirici Şıklar: Yanlış şıklar gerçekçi hatalar veya kavram karışıklıkları olmalı, rastgele kelimeler değil.""";

  return """
TaktikAI - Cevher İşleme Kiti oluştur.
$fiveChoiceRule
$compactRules
$qualityRules

INPUT:
- Ders: '$weakestSubject' | Konu: '$weakestTopic' 
- Sınav: $selectedExam | Zorluk: $difficulty $difficultyInstruction

GÖREV: Temel kavramlar, sık hatalar, çözümlü örnek, 5 soruluk KALİTELİ quiz hazırla.

ÖRNEK DOĞRU KULLANIM:
{
  "question": "2x + 3 = 11 denkleminde x kaçtır?",
  "optionA": "3",
  "optionB": "4",
  "optionC": "5",
  "optionD": "7",
  "optionE": "8",
  "correctOptionIndex": 1,
  "explanation": "2x + 3 = 11 → 2x = 8 → x = 4. Cevap B şıkkıdır."
}

JSON ÇIKTI:
{
  "subject": "$weakestSubject",
  "topic": "$weakestTopic",
  "studyGuide": "# $weakestTopic - Cevher İşleme Kartı\\n\\n## 💎 Özü\\n...",
  "quiz": [
    {"question": "Soru 1", "optionA": "...", "optionB": "...", "optionC": "...", "optionD": "...", "optionE": "...", "correctOptionIndex": [0-4], "explanation": "..."},
    {"question": "Soru 2", "optionA": "...", "optionB": "...", "optionC": "...", "optionD": "...", "optionE": "...", "correctOptionIndex": [0-4], "explanation": "..."},
    {"question": "Soru 3", "optionA": "...", "optionB": "...", "optionC": "...", "optionD": "...", "optionE": "...", "correctOptionIndex": [0-4], "explanation": "..."},
    {"question": "Soru 4", "optionA": "...", "optionB": "...", "optionC": "...", "optionD": "...", "optionE": "...", "correctOptionIndex": [0-4], "explanation": "..."},
    {"question": "Soru 5", "optionA": "...", "optionB": "...", "optionC": "...", "optionD": "...", "optionE": "...", "correctOptionIndex": [0-4], "explanation": "..."}
  ]
}
""";
}
