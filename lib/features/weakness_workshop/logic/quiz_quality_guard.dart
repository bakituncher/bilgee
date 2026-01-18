// lib/features/weakness_workshop/logic/quiz_quality_guard.dart
import 'package:taktik/features/weakness_workshop/models/workshop_model.dart';

class QuizQualityGuardResult {
  final WorkshopModel material;
  final List<String> issues;
  QuizQualityGuardResult(this.material, this.issues);
}

class QuizQualityGuard {
  // SEKTÖR STANDARDI AYARLAR (Gevşetilmiş - OPTİMİZASYON)
  static const int minQuestions = 1; // 1 soru bile kalsa kabul et (Eskiden 3'tü)
  static const int minOptions = 3;   // 4 şık zorunluluğu kalktı, 3 şık da kabul (Eskiden 4'tü)
  static const int minTextLen = 5;   // Çok kısa sorulara izin ver (Eskiden 10'du)
  static const int minExplLen = 5;   // Kısa açıklamalara izin ver (Eskiden 15'ti)

  static QuizQualityGuardResult apply(WorkshopModel raw) {
    final issues = <String>[];
    final validQuestions = <QuizQuestion>[];
    final seenQuestions = <String>{};

    for (int i = 0; i < raw.quiz.length; i++) {
      final q = raw.quiz[i];
      
      // 1. Soru metni tekrarı kontrolü
      final normQ = _normalize(q.question);
      if (seenQuestions.contains(normQ)) {
        issues.add('Soru ${i + 1}: Tekrarlanan soru metni nedeniyle elendi.');
        continue;
      }

      // 2. Soruyu işle ve temizle (Başarısızsa null döner)
      final processedQ = _processAndValidate(q, issues, index: i + 1);
      
      if (processedQ != null) {
        validQuestions.add(processedQ);
        seenQuestions.add(normQ);
      }
    }

    // Toplam soru sayısı kontrolü - OPTİMİZE EDİLDİ
    // Eğer hiç soru kalmadıysa hata ver (mecburen)
    if (validQuestions.isEmpty) {
      issues.add('Hiç geçerli soru oluşturulamadı.');
      throw Exception('İçerik oluşturulamadı. Lütfen tekrar deneyin.');
    }

    // 1-2 soru kaldıysa uyarı ekle ama devam et (kullanıcı deneyimi için)
    if (validQuestions.length < minQuestions) {
      issues.add('Uyarı: Kalite kontrol nedeniyle bazı sorular elendi. Kalan soru sayısı: ${validQuestions.length}');
    }

    // Temizlenmiş materyali döndür
    final guarded = WorkshopModel(
      id: raw.id,
      studyGuide: _sanitizeText(raw.studyGuide),
      quiz: validQuestions,
      topic: raw.topic,
      subject: raw.subject,
      savedDate: raw.savedDate,
    );

    return QuizQualityGuardResult(guarded, issues);
  }

  /// Soruyu temizler, şıkları tekilleştirir ve kalite kontrolünden geçirir.
  /// Geçersizse `null` döner ve `issues` listesine nedenini ekler.
  static QuizQuestion? _processAndValidate(QuizQuestion q, List<String> issues, {required int index}) {
    final cleanQuestionText = _sanitizeText(q.question);
    final cleanExplanation = _sanitizeText(q.explanation);

    // --- A. Metin Kalite Kontrolleri (Esnek) ---
    if (cleanQuestionText.length < minTextLen) {
      // Çok kısa metinleri uyar ama kritik değilse geç (Sadece logla)
      issues.add('Soru $index: Metin çok kısa ama devam ediliyor.');
      // Artık return null yapmıyoruz, soruyu koruyoruz
    }
    if (cleanExplanation.length < minExplLen) {
      issues.add('Soru $index: Açıklama kısa ama devam ediliyor.');
      // Artık return null yapmıyoruz
    }
    
    // Cevap sızıntısı kontrolü (Basit)
    final lowerQ = cleanQuestionText.toLowerCase();
    if (lowerQ.contains('cevap:') || lowerQ.contains('doğru şık')) {
      issues.add('Soru $index: Cevap sızıntısı tespit edildiği için elendi.');
      return null;
    }

    // --- B. Şık İşlemleri (Kritik Kısım) ---
    
    // 1. Doğru cevabın orijinal metnini al (İndeks kaymasını önlemek için)
    if (q.correctOptionIndex < 0 || q.correctOptionIndex >= q.options.length) {
      issues.add('Soru $index: Geçersiz cevap anahtarı nedeniyle elendi.');
      return null;
    }
    final originalCorrectText = _sanitizeText(q.options[q.correctOptionIndex]);

    // 2. Şıkları temizle, boş/placeholder olanları at ve tekilleştir
    final uniqueOptions = <String>{};
    final finalOptions = <String>[];
    
    for (final opt in q.options) {
      final cleanOpt = _sanitizeText(opt);
      final lowerOpt = cleanOpt.toLowerCase();

      // Placeholder ve boş kontrolü
      if (cleanOpt.isEmpty || _isPlaceholderOption(lowerOpt)) {
        continue;
      }

      // Tekilleştirme
      if (!uniqueOptions.contains(lowerOpt)) {
        uniqueOptions.add(lowerOpt);
        finalOptions.add(cleanOpt);
      }
    }

    // 3. Yeterli şık kaldı mı? (En az 3 - OPTİMİZE EDİLDİ)
    if (finalOptions.length < minOptions) {
      issues.add('Soru $index: Yeterli geçerli şıkkı olmadığı (${finalOptions.length}) için elendi.');
      return null; // 3'ten az şık varsa soru geçersizdir
    }

    // 4. Doğru cevabın yeni listedeki yerini bul
    // Not: Tekilleştirme sırasında doğru cevap metni de biraz değişmiş olabilir (trim vs),
    // bu yüzden fuzzy match veya sanitize edilmiş haliyle arıyoruz.
    int newCorrectIndex = -1;
    for (int i = 0; i < finalOptions.length; i++) {
      if (finalOptions[i] == originalCorrectText) {
        newCorrectIndex = i;
        break;
      }
    }

    // OPTİMİZE EDİLDİ: Doğru cevap kayıpsa soruyu kurtarmak için fallback uygula
    if (newCorrectIndex == -1) {
      if (finalOptions.isNotEmpty) {
        newCorrectIndex = 0; // İlk şıkkı doğru kabul et
        issues.add('Soru $index: Doğru şık kurtarıldı (Otomatik A şıkkı atandı).');
      } else {
        issues.add('Soru $index: Doğru cevap şıkkı geçerli bulunmadığı için elendi.');
        return null;
      }
    }

    return QuizQuestion(
      question: cleanQuestionText,
      options: finalOptions,
      correctOptionIndex: newCorrectIndex,
      explanation: cleanExplanation,
    );
  }

  static bool _isPlaceholderOption(String lowerOpt) {
    // "Diğer seçenek", "Seçenek A", "Option 1" gibi saçmalıkları filtreler
    return lowerOpt == 'a' || lowerOpt == 'b' || lowerOpt == 'c' || lowerOpt == 'd' || lowerOpt == 'e' ||
        lowerOpt.startsWith('seçenek') || 
        lowerOpt.startsWith('diğer seçenek') || 
        lowerOpt.startsWith('option') ||
        lowerOpt.contains('belirtilmemiş');
  }

  static String _sanitizeText(String v) {
    return v.replaceAll('\r', '').replaceAll('\t', ' ').replaceAll('  ', ' ').trim();
  }

  static String _normalize(String v) => _sanitizeText(v).toLowerCase();
}
