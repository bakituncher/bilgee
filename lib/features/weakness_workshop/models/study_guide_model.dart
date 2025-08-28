// lib/features/weakness_workshop/models/study_guide_model.dart
import 'package:bilge_ai/core/utils/json_text_cleaner.dart';

class StudyGuideAndQuiz {
  final String studyGuide; // Markdown formatında
  final List<QuizQuestion> quiz;
  final String topic;
  final String subject;

  StudyGuideAndQuiz({
    required this.studyGuide,
    required this.quiz,
    required this.topic,
    required this.subject,
  });

  factory StudyGuideAndQuiz.fromJson(Map<String, dynamic> json) {
    var quizList = (json['quiz'] as List<dynamic>?)
        ?.map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
        .toList() ??
        [];

    return StudyGuideAndQuiz(
      studyGuide: json['studyGuide'] ?? "# Bilgi Alınamadı",
      quiz: quizList,
      topic: json['topic'] ?? "Bilinmeyen Konu",
      subject: json['subject'] ?? "Bilinmeyen Ders",
    );
  }
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    // BİLGEAI UYARI: Gelecekteki ben veya başka bir geliştirici için not:
    // Bu fonksiyon, yapay zekanın döndürebileceği beklenmedik metin formatlarını
    // temizlemek için kritik öneme sahiptir. Zırh merkezileştirildi: JsonTextCleaner kullanılmalıdır.

    List<String> parsedOptions = [];

    // --- NİHAİ ÇÖZÜM: ÇİFT KATMANLI SAVUNMA MEKANİZMASI ---
    // 1. ÖNCELİK: Yeni ve güvenli "optionA, optionB..." formatını dene (A-E, 5 şık desteği).
    if (json.containsKey('optionA')) {
      parsedOptions = [
        JsonTextCleaner.cleanDynamic(json['optionA'] ?? ''),
        JsonTextCleaner.cleanDynamic(json['optionB'] ?? ''),
        JsonTextCleaner.cleanDynamic(json['optionC'] ?? ''),
        JsonTextCleaner.cleanDynamic(json['optionD'] ?? ''),
        if (json.containsKey('optionE')) JsonTextCleaner.cleanDynamic(json['optionE'] ?? ''),
      ];
      parsedOptions = parsedOptions.where((e) => e != '').toList();
    }
    // 2. YEDEK PLAN: Eğer yeni format yoksa, eski "options" listesi formatını
    // zırhlı temizleyici ile işlemeyi dene.
    else if (json['options'] is List) {
      parsedOptions = (json['options'] as List)
          .map((option) => JsonTextCleaner.cleanDynamic(option))
          .toList();
    }

    // Boşları doldur
    for (int i = 0; i < parsedOptions.length; i++) {
      if (parsedOptions[i].isEmpty) {
        parsedOptions[i] = "Seçenek ${String.fromCharCode(65 + i)}";
      }
    }

    // Şık sayısını en az 5 olacak şekilde doldur (A-E). 4 gelirse E'yi ekle.
    while (parsedOptions.length < 5) {
      final idx = parsedOptions.length;
      parsedOptions.add("Seçenek ${String.fromCharCode(65 + idx)}");
    }
    // Çok fazlaysa 5'e kısalt
    if (parsedOptions.length > 5) {
      parsedOptions = parsedOptions.sublist(0, 5);
    }

    // Doğru cevap indeksini güvenli aralığa sabitle
    int idx = 0;
    try {
      idx = (json['correctOptionIndex'] as num?)?.toInt() ?? 0;
    } catch (_) {
      idx = 0;
    }
    if (idx < 0) idx = 0;
    if (idx >= parsedOptions.length) idx = 0;

    return QuizQuestion(
      question: JsonTextCleaner.cleanDynamic(json['question'] ?? 'Soru yüklenemedi.'),
      options: parsedOptions,
      correctOptionIndex: idx,
      explanation: JsonTextCleaner.cleanDynamic(json['explanation'] ?? 'Bu soru için açıklama bulunamadı.'),
    );
  }
}
