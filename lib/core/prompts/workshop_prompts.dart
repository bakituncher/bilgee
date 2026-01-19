// lib/core/prompts/workshop_prompts.dart

String getStudyGuideAndQuizPrompt(
    String weakestSubject,
    String weakestTopic,
    String? selectedExam,
    String difficulty,
    int attemptCount, {
    String contentType = 'both', // 'quizOnly', 'studyOnly', 'both'
    }) {

  // Sınav bazlı zorluk seviyesi ayarlaması
  String examLevelDifficulty = _getExamAppropriateLevel(selectedExam, difficulty);

  String difficultyInstruction = "";
  if (difficulty == 'hard') {
    difficultyInstruction = """
📈 ZORLUK SEVİYESİ: $examLevelDifficulty
Kullanıcı 'Derinleşmek İstiyorum' seçeneğini kullandı. 
Ancak dikkat: $selectedExam seviyesini ASLA aşma.
${_getDifficultyGuidelines(selectedExam)}
Sorular zorlayıcı olmalı ama ÖĞRENCİNİN SEVİYESİNE UYGUN.
""";
    if (attemptCount > 1) {
      difficultyInstruction += "\n⚡ Bu, kullanıcının ${attemptCount}. derinleşme denemesi. FARKLI sorular üret, aynılarını tekrarlama.";
    }
  }

  // Sınava özel yönergeler: ton, kapsam ve vurgu
  String examGuidelines = "";
  final examLower = (selectedExam ?? '').toLowerCase();

  if (examLower.contains('kpss')) {
    examGuidelines = """
**KPSS ÖZEL TALİMATLAR:**
- Yetişkin, profesyonel dil kullan
- GY: Sözel/Sayısal mantık, zaman yönetimi, çeldirici analizi
- GK: Ezber teknikleri, kronoloji, coğrafi ilişkiler
- Çalışan adaylar için: Verimli, yoğun içerik

🎓 MÜFREDAT SINIRI:
- SADECE KPSS müfredatındaki konular
- Lisans seviyesi bilgi yeterli
- Lisansüstü/akademik detaylar YASAK
- Örnek YASAK: "Kuantum fiziği detayları"
- Örnek OK: "Genel fizik prensipleri"
""";
  } else if (examLower.contains('yks') || examLower.contains('tyt') || examLower.contains('ayt') || examLower.contains('ydt')) {
    examGuidelines = """
**YKS ÖZEL TALİMATLAR:**
- Lise seviyesi akademik ton
- TYT: Temel kavramlar, hız-doğruluk dengesi
- AYT: Derin kavram ilişkileri, modelleme, analiz
- YDT: Dil becerisi, kelime, gramer, okuma stratejileri (B1-B2 seviyesi MAX)
- Grafik/tablo yorumlama
""";
  } else if (examLower.contains('lgs')) {
    examGuidelines = """
**LGS ÖZEL TALİMATLAR:**
- Ortaokul seviyesi (14 yaş), pozitif ton
- Yeni nesil sorular: Metin-grafik ilişkilendirme
- Beceri temelli düşünme: Akıl yürütme, strateji
- ORTAOKUL ÖĞRENCİSİNE UYGUN: Basit dil, net açıklamalar
- Motivasyon: "Sen yapabilirsin" mesajı
- İNGİLİZCE SORULARINDA: A1-A2 seviyesi MAX, günlük dil
""";
  } else if (examLower.contains('ags')) {
    examGuidelines = """
**AGS (AKADEMİ GİRİŞ SINAVI) ÖZEL TALİMATLAR:**
- MEB Öğretmen Adayları için (2025-2026 sistemi)
- Akademik ve profesyonel ton
""";
  } else {
    examGuidelines = "**GENEL:** Profesyonel, sınav odaklı yaklaşım. Net çözüm ve strateji.";
  }

  // Sınava göre şık sayısı belirleme
  final choiceRule = _getChoiceRule(selectedExam);

  // KISALTILMIŞ KURALLAR + AÇIKLAMA UZUNLUĞU KISITLAMASI + DİL KONTROLÜ
  final languageControl = _getLanguageControl(weakestSubject);

  final compactRules = """
📏 KURALLAR:
- StudyGuide max 650 kelime
- Quiz açıklamaları max 30-35 kelime (MUTLAK SINIR)
- Açıklamalar: Doğrudan, kısa, öz. Gereksiz lafı kes.
$languageControl
- Şıklar ayırt edilebilir, cevap sızdırma yasak
$examGuidelines
""";

  // KRİTİK FAKTÖRİYEL DOĞRULUK UYARISI + GÖRSEL İÇERİK YASAĞI
  const factualAccuracyWarning = """
⛔ MUTLAK ZORUNLULUK: %100 DOĞRULUK.
HATA YAPMA. TEK YANLIŞ BİLGİ = SİLİNME.
TARA. DOĞRULA. RİSKE ATMA.

🚫 GRAFİK/GÖRSEL İÇERİK YASAĞI:
- "Aşağıdaki grafik/şekil/tablo/çizim" gibi referanslar YASAK
- "Yukarıdaki grafik" veya benzeri ifadeler YASAK
- Görsel olmayan metin tabanlı sorular oluştur
- Grafik gerekiyorsa SADECE sözel/matematiksel açıklama yap
- Örnek YANLIŞ: "Aşağıdaki grafikte görüldüğü gibi..."
- Örnek DOĞRU: "f(x) = 2x + 3 fonksiyonu için..."
⚠️ BU YASAK HALLÜSİNASYON = GÖREV İPTAL
""";

  return """
Taktik Tavşan - Cevher İşleme Kiti oluştur.
$choiceRule
$compactRules

$factualAccuracyWarning

INPUT:
- Ders: '$weakestSubject' | Konu: '$weakestTopic' 
- Sınav: $selectedExam | Zorluk: $difficulty $difficultyInstruction

${_getTaskByContentType(contentType, weakestSubject, weakestTopic, selectedExam)}
""";
}

// Sınava göre şık sayısı kuralı
String _getChoiceRule(String? exam) {
  final examLower = (exam ?? '').toLowerCase();

  if (examLower.contains('lgs')) {
    return """
✅ LGS ŞIK KURALI: Her soruda TAM 4 ŞIK (A, B, C, D).
- JSON'da optionA, optionB, optionC, optionD alanları
- correctOptionIndex 0-3 aralığında (0=A, 1=B, 2=C, 3=D)
- E şıkkı YASAK - LGS'de 4 şık vardır
⚠️ 5 ŞIK OLUŞTURURSAN GÖREV İPTAL!
""";
  }

  // Diğer tüm sınavlar için 5 şık
  return """
✅ ŞIK KURALI: Her soruda TAM 5 ŞIK (A, B, C, D, E).
- JSON'da optionA, optionB, optionC, optionD, optionE alanları
- correctOptionIndex 0-4 aralığında (0=A, 1=B, 2=C, 3=D, 4=E)
""";
}

// Sınav seviyesine uygun zorluk belirle
String _getExamAppropriateLevel(String? exam, String requestedDifficulty) {
  if (requestedDifficulty != 'hard') return 'Normal';

  final examLower = (exam ?? '').toLowerCase();

  if (examLower.contains('lgs')) {
    return 'Ortaokul Zor (8. sınıf seviyesi, A2 İngilizce max)';
  } else if (examLower.contains('yks') || examLower.contains('tyt')) {
    return 'Lise Zor (11-12. sınıf, B1-B2 İngilizce max)';
  } else if (examLower.contains('ayt')) {
    return 'Üniversite Hazırlık Zor (Akademik, C1 max)';
  } else if (examLower.contains('ydt')) {
    return 'Dil Yeterliliği Zor (B2-C1 arası)';
  } else if (examLower.contains('kpss')) {
    return 'Lisans/Lisansüstü Zor (Profesyonel seviye)';
  }

  return 'Zorlayıcı';
}

// Sınava özel zorluk yönergeleri
String _getDifficultyGuidelines(String? exam) {
  final examLower = (exam ?? '').toLowerCase();

  if (examLower.contains('lgs')) {
    return """
LGS İÇİN ZORLUK KURALLARI:
- İngilizce: A1-A2 seviyesi, günlük kelimeler, basit yapılar
- Matematik: 8. sınıf müfredatı, çok adımlı ama anlaşılır
- Fen: Görsel destekli, günlük hayat örnekleri
- Türkçe: Anlaşılır metinler, temel dil bilgisi
YASAK: Üniversite terimleri, karmaşık akademik dil, B2+ İngilizce
""";
  } else if (examLower.contains('yks') || examLower.contains('tyt') || examLower.contains('ayt')) {
    return """
YKS İÇİN ZORLUK KURALLARI:
- İngilizce: B1-B2 max, lise müfredatı uygun
- Matematik/Fen: Kavramsal derin ama lise düzeyi
- Paragraf: Akademik ama anlaşılır metinler
YASAK: C1-C2 İngilizce, üniversite ders kitabı zorlukları
""";
  } else if (examLower.contains('ydt')) {
    return """
YDT İÇİN ZORLUK KURALLARI:
- Seviye: B2-C1 arası
- Akademik kelime dağarcığı uygun
- Karmaşık cümle yapıları OK
- Native speaker zorluğu YASAK
""";
  }

  return 'Sınav seviyesine uygun zorlayıcı sorular.';
}

// Ders bazlı dil kontrolü
String _getLanguageControl(String subject) {
  final subjectLower = subject.toLowerCase();

  // İngilizce dersi ise özel kontrol yok
  if (subjectLower.contains('i̇ngilizce') ||
      subjectLower.contains('ingilizce') ||
      subjectLower.contains('english')) {
    return '';
  }

  // Tüm diğer dersler için TÜRKÇE zorunlu
  return """
🇹🇷 DİL KONTROLÜ - KRİTİK:
- Ders: "$subject" - Bu TÜRKÇE bir derstir.
- SORU, ŞIK ve AÇIKLAMALAR TAMAMEN TÜRKÇE OLMALI.
- İngilizce kelime, cümle veya ifade KESİNLİKLE YASAK.
- Matematik/Fizik/Kimya/Biyoloji formülleri ve sembolleri OK, ama açıklamalar Türkçe.
- Örnek YANLIŞ: "velocity", "force", "equation" 
- Örnek DOĞRU: "hız", "kuvvet", "denklem"
⚠️ BU KURALDAN SAPMA = GÖREV BAŞARISIZLIĞI
""";
}

String _getTaskByContentType(String contentType, String subject, String topic, String? exam) {
  final examLower = (exam ?? '').toLowerCase();
  final isLgs = examLower.contains('lgs');

  // LGS için 4 şık, diğerleri için 5 şık
  final exampleQuestions = isLgs ? _getLgsQuestionExamples() : _getStandardQuestionExamples();

  if (contentType == 'quizOnly') {
    return """
GÖREV: 🎯 SADECE SORU OLUŞTUR
Kullanıcı sadece sorular istedi. Konu anlatımı YAPMA.
5 adet kaliteli, zorlayıcı soru hazırla.
⚠️ AÇIKLAMA SINIRI: Max 30-35 kelime. Kısa, net, öz.

JSON ÇIKTI:
{
  "subject": "$subject",
  "topic": "$topic",
  "quiz": $exampleQuestions
}""";
  } else if (contentType == 'studyOnly') {
    return """
GÖREV: 📚 SADECE KONU ANLATIMI OLUŞTUR
Kullanıcı sadece konu anlatımı istedi. Quiz/Soru YAPMA.
Detaylı, örneklerle zenginleştirilmiş çalışma rehberi (max 650 kelime).

JSON ÇIKTI:
{
  "subject": "$subject",
  "topic": "$topic",
  "studyGuide": "# $topic - Cevher İşleme Kartı\\n\\n## 💎 Özü\\n...\\n\\n## 📊 Temel Kavramlar\\n...\\n\\n## ⚠️ Sık Hatalar\\n...\\n\\n## 🎯 Strateji\\n...\\n\\n## 📝 Örnekler\\n..."
}""";
  } else {
    // both (varsayılan)
    return """
GÖREV: 🚀 HEM KONU ANLATIMI HEM SORU OLUŞTUR
Temel kavramlar, sık hatalar, çözümlü örnek içeren çalışma rehberi + 5 soruluk quiz.
⚠️ AÇIKLAMA SINIRI: Max 30-35 kelime. Kısa, net, öz.

JSON ÇIKTI:
{
  "subject": "$subject",
  "topic": "$topic",
  "studyGuide": "# $topic - Cevher İşleme Kartı\\n\\n## 💎 Özü\\n...",
  "quiz": $exampleQuestions
}""";
  }
}

// LGS için 4 şıklı soru örnekleri
String _getLgsQuestionExamples() {
  return """[
    {"question": "Soru 1", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "correctOptionIndex": 0, "explanation": "Kısa açıklama (max 35 kelime)"},
    {"question": "Soru 2", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "correctOptionIndex": 1, "explanation": "Kısa açıklama"},
    {"question": "Soru 3", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "correctOptionIndex": 2, "explanation": "Kısa açıklama"},
    {"question": "Soru 4", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "correctOptionIndex": 3, "explanation": "Kısa açıklama"},
    {"question": "Soru 5", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "correctOptionIndex": 0, "explanation": "Kısa açıklama"}
  ]""";
}

// Standart 5 şıklı soru örnekleri (YKS, KPSS, vb.)
String _getStandardQuestionExamples() {
  return """[
    {"question": "Soru 1", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 0, "explanation": "Kısa açıklama (max 35 kelime)"},
    {"question": "Soru 2", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 1, "explanation": "Kısa açıklama"},
    {"question": "Soru 3", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 2, "explanation": "Kısa açıklama"},
    {"question": "Soru 4", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 3, "explanation": "Kısa açıklama"},
    {"question": "Soru 5", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 4, "explanation": "Kısa açıklama"}
  ]""";
}
