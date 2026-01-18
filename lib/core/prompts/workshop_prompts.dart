// lib/core/prompts/workshop_prompts.dart

String getStudyGuideAndQuizPrompt(
    String weakestSubject,
    String weakestTopic,
    String? selectedExam,
    String difficulty,
    int attemptCount, {
    String contentType = 'both', // 'quizOnly', 'studyOnly', 'both'
    }) {

  String difficultyInstruction = "";
  if (difficulty == 'hard') {
    difficultyInstruction = "KRİTİK EMİR: Kullanıcı 'Derinleşmek İstiyorum' dedi. Bu, sıradan bir test olmayacak. Hazırlayacağın 5 soruluk 'Ustalık Sınavı', bu konunun en zor, en çeldirici, birden fazla adımla çözülen, genellikle en iyi öğrencilerin bile takıldığı türden olmalıdır. Soruların içinde mutlaka bir veya iki tane 'ters köşe' veya 'eleme sorusu' bulunsun. Kolay ve orta seviye soru KESİNLİKLE YASAK.";
    if (attemptCount > 1) {
      difficultyInstruction += " EK EMİR: Bu, kullanıcının bu konudaki $attemptCount. ustalık denemesidir. Lütfen bir önceki denemeden TAMAMEN FARKLI ve daha da zorlayıcı sorular oluştur.";
    }
  }

  // Sınava özel yönergeler: ton, kapsam ve vurgu
  String examGuidelines = "";
  final examLower = (selectedExam ?? '').toLowerCase();

  if (examLower.contains('kpss')) {
    examGuidelines = """
**KPSS ÖZEL TALİMATLAR:**
- Yetişkin, profesyonel dil kullan (asla basitleştirme yapma)
- GY soruları için: Sözel/Sayısal mantık stratejileri, zaman yönetimi, çeldirici analizi
- GK soruları için: Ezber teknikleri, kronoloji, coğrafi ilişkiler, güncel bağlantılar
- Paragraf analizi, mantık çıkarımı ve hızlı eleme tekniklerine odaklan
- Çalışan adaylar için: Verimli, yoğun, ezbere dayalı içerik
""";
  } else if (examLower.contains('yks') || examLower.contains('tyt') || examLower.contains('ayt') || examLower.contains('ydt')) {
    examGuidelines = """
**YKS ÖZEL TALİMATLAR:**
- Akademik, motive edici ton
- TYT için: Temel kavramlar, hız ve doğruluk dengesi, tuzak soruları
- AYT için: Derin kavram ilişkileri, modelleme, analiz, çoklu adım çözümler
- YDT için: Dil becerisi, kelime dağarcığı, gramer yapıları, okuma stratejileri, çeviri teknikleri
- Grafik/tablo yorumlama, veri analizi, karmaşık senaryolar
- Lise öğrencilerine uygun: Zorlu ama anlaşılır, cesaretlendirici
""";
  } else if (examLower.contains('lgs')) {
    examGuidelines = """
**LGS ÖZEL TALİMATLAR:**
- Disiplinli, odaklı, pozitif ton (ortaokul seviyesi)
- Yeni nesil sorular: Metin-grafik-tablo ilişkilendirme, çoklu kaynak analizi
- Beceri temelli düşünme: Akıl yürütme zinciri, strateji geliştirme
- Basit değil, akıllı: Ortaokul öğrencisine saygılı ama zorlayıcı içerik
- Motivasyon: "Sen yapabilirsin" mesajı, küçük adımlar, başarı hissi
""";
  } else {
    examGuidelines = "**GENEL:** Profesyonel, sınav odaklı yaklaşım. Gereksiz detaydan kaçın, doğrudan çözüm ve strateji ver.";
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
Taktik Tavşan - Cevher İşleme Kiti oluştur.
$fiveChoiceRule
$compactRules

$factualAccuracyWarning

INPUT:
- Ders: '$weakestSubject' | Konu: '$weakestTopic' 
- Sınav: $selectedExam | Zorluk: $difficulty $difficultyInstruction

${_getTaskByContentType(contentType, weakestSubject, weakestTopic, fiveChoiceRule)}
""";
}

String _getTaskByContentType(String contentType, String subject, String topic, String fiveChoiceRule) {
  if (contentType == 'quizOnly') {
    return """
GÖREV: 🎯 SADECE SORU OLUŞTUR
Kullanıcı sadece sorular istedi. Konu anlatımı YAPMA.
$fiveChoiceRule
5 adet kaliteli, zorlayıcı soru hazırla. HER SORUYU KONTROL LİSTESİNDEN GEÇİR!

JSON ÇIKTI:
{
  "subject": "$subject",
  "topic": "$topic",
  "quiz": [
    {"question": "Soru 1", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 0, "explanation": "..."},
    {"question": "Soru 2", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 1, "explanation": "..."},
    {"question": "Soru 3", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 2, "explanation": "..."},
    {"question": "Soru 4", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 3, "explanation": "..."},
    {"question": "Soru 5", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 4, "explanation": "..."}
  ]
}""";
  } else if (contentType == 'studyOnly') {
    return """
GÖREV: 📚 SADECE KONU ANLATIMI OLUŞTUR
Kullanıcı sadece konu anlatımı istedi. Quiz/Soru YAPMA.
Detaylı, örneklerle zenginleştirilmiş, stratejik bir çalışma rehberi hazırla (max 1000 kelime).

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
Temel kavramlar, sık hatalar, çözümlü örnek içeren çalışma rehberi + 5 soruluk quiz hazırla.
$fiveChoiceRule
HER SORUYU KONTROL LİSTESİNDEN GEÇİR!

JSON ÇIKTI:
{
  "subject": "$subject",
  "topic": "$topic",
  "studyGuide": "# $topic - Cevher İşleme Kartı\\n\\n## 💎 Özü\\n...",
  "quiz": [
    {"question": "Soru 1", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 0, "explanation": "..."},
    {"question": "Soru 2", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 1, "explanation": "..."},
    {"question": "Soru 3", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 2, "explanation": "..."},
    {"question": "Soru 4", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 3, "explanation": "..."},
    {"question": "Soru 5", "optionA": "A", "optionB": "B", "optionC": "C", "optionD": "D", "optionE": "E", "correctOptionIndex": 4, "explanation": "..."}
  ]
}""";
  }
}
