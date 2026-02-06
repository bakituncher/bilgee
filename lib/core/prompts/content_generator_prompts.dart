// lib/core/prompts/content_generator_prompts.dart
// İçerik üretici sistemi için sınav bazlı promptlar

/// İçerik üretici prompt'larını yöneten sınıf
class ContentGeneratorPrompts {

  /// Bilgi kartları için prompt oluşturur
  static String getInfoCardsPrompt(String? examType) {
    final examContext = _getExamContext(examType);
    final examSpecificRules = _getExamSpecificRules(examType, 'infoCards');

    return '''
Sen bir eğitim içeriği uzmanısın. Gönderilen PDF veya görsel içindeki bilgileri analiz et ve öğrenci dostu bilgi kartlarına dönüştür.

$examContext

GÖREVİN:
Verilen içerikten 5-10 adet bilgi kartı oluştur. Her kart, tek bir kavram veya bilgiyi açıkça anlatmalı.

KURALLAR:
1. Her kart kısa, öz ve akılda kalıcı olmalı.
2. Karmaşık konuları basitleştir.
3. Önemli terimleri **kalın** yap.
4. Bilgileri öncelik sırasına göre düzenle.
5. Her kartta 1-2 cümle ile özet bilgi ver.
$examSpecificRules

JSON formatında yanıt ver:
{
  "cards": [
    {
      "title": "Kart Başlığı",
      "content": "Kartın açıklaması veya bilgisi. Markdown formatında olabilir."
    }
  ]
}

SADECE JSON döndür, başka hiçbir şey yazma.
''';
  }

  /// Soru kartları için prompt oluşturur
  static String getQuestionCardsPrompt(String? examType) {
    final examContext = _getExamContext(examType);
    final examSpecificRules = _getExamSpecificRules(examType, 'questionCards');
    final optionCount = _getOptionCount(examType);

    return '''
Sen bir sınav hazırlık uzmanısın. Gönderilen PDF veya görsel içindeki bilgileri analiz et ve çoktan seçmeli test soruları oluştur.

$examContext

GÖREVİN:
Verilen içerikten 5-10 adet çoktan seçmeli test sorusu oluştur. Her soru $optionCount şıklı olmalı.

KURALLAR:
1. Sorular net, anlaşılır ve sınav formatında olmalı.
2. Her sorunun $optionCount şıkkı olmalı, sadece 1 tanesi doğru.
3. Şıklar mantıklı ve birbirine yakın olmalı (çeldirici şıklar).
4. Farklı zorluk seviyelerinde sorular oluştur.
5. Her sorunun kısa bir açıklaması (neden doğru cevap bu) olmalı.
$examSpecificRules

JSON formatında yanıt ver:
{
  "cards": [
    {
      "title": "Soru 1",
      "content": "Soru metni buraya gelecek?",
      "options": [${_getOptionsTemplate(examType)}],
      "correctIndex": 0,
      "explanation": "Doğru cevap A çünkü..."
    }
  ]
}

ÖNEMLİ: correctIndex 0'dan başlar (${_getCorrectIndexExplanation(examType)}).
SADECE JSON döndür, başka hiçbir şey yazma.
''';
  }

  /// Özet için prompt oluşturur
  static String getSummaryPrompt(String? examType) {
    final examContext = _getExamContext(examType);
    final examSpecificRules = _getExamSpecificRules(examType, 'summary');

    return '''
Sen bir özetleme uzmanısın. Gönderilen PDF veya görsel içindeki bilgileri analiz et ve kapsamlı bir özet oluştur.

$examContext

GÖREVİN:
Verilen içeriğin önemli noktalarını vurgulayan, akıcı ve öğrenci dostu bir özet hazırla.

KURALLAR:
1. Ana konuları ve alt başlıkları belirle.
2. Önemli kavramları **kalın** yap.
3. Gereksiz detayları ele, özü çıkar.
4. Markdown formatında (başlıklar, listeler, kalın yazı) düzenle.
5. En alta "Kritik Noktalar" başlığıyla 3-5 maddelik önemli hatırlatmalar ekle.
$examSpecificRules

JSON formatında yanıt ver:
{
  "summary": "Markdown formatında özet metni buraya gelecek."
}

SADECE JSON döndür, başka hiçbir şey yazma.
''';
  }

  /// Sınav türüne göre bağlam metni döndürür
  static String _getExamContext(String? examType) {
    if (examType == null || examType.isEmpty) {
      return '';
    }

    switch (examType.toLowerCase()) {
      case 'yks':
        return '''
**SINAV BAĞLAMI: YKS (Yükseköğretim Kurumları Sınavı)**
- TYT ve AYT formatına uygun içerik hazırla.
- Üniversite sınavı düzeyinde, analitik düşünme gerektiren sorular oluştur.
- ÖSYM soru formatına uygun, net ve anlaşılır ifadeler kullan.
- Paragraf yorumlama, grafik okuma ve problem çözme becerilerini hedefle.
''';

      case 'lgs':
        return '''
**SINAV BAĞLAMI: LGS (Liselere Geçiş Sınavı)**
- 8. sınıf müfredatına uygun içerik hazırla.
- Ortaokul seviyesinde, anlaşılır bir dil kullan.
- MEB sınav formatına uygun, beceri temelli sorular oluştur.
- Görsel okuma, günlük hayat problemleri ve yorumlama becerileri hedefle.
- Sorular 4 şıklı (A, B, C, D) olmalı.
''';

      case 'kpss':
        return '''
**SINAV BAĞLAMI: KPSS (Kamu Personel Seçme Sınavı)**
- KPSS Genel Yetenek ve Genel Kültür formatına uygun içerik hazırla.
- Yetişkin öğrenci profiline hitap eden ciddi ve resmi bir dil kullan.
- ÖSYM KPSS formatına uygun, ezber ve analiz gerektiren sorular oluştur.
- Güncel olaylar, mevzuat ve temel kavramlara odaklan.
''';

      case 'ags':
        return '''
**SINAV BAĞLAMI: AGS (Askeri Giriş Sınavı)**
- Askeri okullara hazırlık formatına uygun içerik hazırla.
- Disiplinli ve özlü bir dil kullan.
- Temel bilgi ve mantık sorularına ağırlık ver.
- Hızlı çözüm teknikleri ve pratik bilgiler ekle.
''';

      default:
        return '''
**SINAV BAĞLAMI:** İçeriği **$examType** sınavına hazırlanan öğrenciler için uygun şekilde hazırla.
''';
    }
  }

  /// Sınav ve içerik türüne göre özel kurallar döndürür
  static String _getExamSpecificRules(String? examType, String contentType) {
    if (examType == null || examType.isEmpty) {
      return '';
    }

    switch (examType.toLowerCase()) {
      case 'yks':
        if (contentType == 'questionCards') {
          return '''
6. YKS formatında, 5 şıklı (A, B, C, D, E) sorular oluştur.
7. TYT için temel düzey, AYT için ileri düzey sorular hazırla.
8. Çeldirici şıklar mantıklı ve ÖSYM tarzında olmalı.
''';
        } else if (contentType == 'infoCards') {
          return '''
6. TYT ve AYT'de çıkabilecek anahtar kavramları vurgula.
7. Formül, tarih ve önemli terimleri öne çıkar.
''';
        }
        return '';

      case 'lgs':
        if (contentType == 'questionCards') {
          return '''
6. LGS formatında, 4 şıklı (A, B, C, D) sorular oluştur.
7. 8. sınıf seviyesine uygun, anlaşılır sorular hazırla.
8. Beceri temelli ve günlük hayatla ilişkili sorular ekle.
''';
        } else if (contentType == 'infoCards') {
          return '''
6. 8. sınıf müfredatındaki temel kavramları basit dille anlat.
7. Görsellerle desteklenebilecek bilgiler tercih et.
''';
        }
        return '';

      case 'kpss':
        if (contentType == 'questionCards') {
          return '''
6. KPSS formatında, 5 şıklı (A, B, C, D, E) sorular oluştur.
7. Ezbere dayalı ve analitik düşünme gerektiren sorular dengele.
8. Mevzuat ve güncel bilgilere dikkat et.
''';
        } else if (contentType == 'infoCards') {
          return '''
6. Ezber gerektiren bilgileri madde madde sırala.
7. Tarih, rakam ve önemli kavramları vurgula.
''';
        }
        return '';

      case 'ags':
        if (contentType == 'questionCards') {
          return '''
6. AGS formatında, 5 şıklı (A, B, C, D, E) sorular oluştur.
7. Temel bilgi ve mantık sorularına ağırlık ver.
8. Hızlı çözülebilir, net sorular hazırla.
''';
        } else if (contentType == 'infoCards') {
          return '''
6. Kısa ve öz bilgiler ver.
7. Hızlı tekrar için ideal kartlar oluştur.
''';
        }
        return '';

      default:
        return '';
    }
  }

  /// Sınav türüne göre şık sayısını döndürür
  static String _getOptionCount(String? examType) {
    if (examType?.toLowerCase() == 'lgs') {
      return '4';
    }
    return '5';
  }

  /// Sınav türüne göre şık template'i döndürür
  static String _getOptionsTemplate(String? examType) {
    if (examType?.toLowerCase() == 'lgs') {
      return '"A şıkkı metni", "B şıkkı metni", "C şıkkı metni", "D şıkkı metni"';
    }
    return '"A şıkkı metni", "B şıkkı metni", "C şıkkı metni", "D şıkkı metni", "E şıkkı metni"';
  }

  /// Sınav türüne göre correctIndex açıklaması döndürür
  static String _getCorrectIndexExplanation(String? examType) {
    if (examType?.toLowerCase() == 'lgs') {
      return '0=A, 1=B, 2=C, 3=D';
    }
    return '0=A, 1=B, 2=C, 3=D, 4=E';
  }
}
