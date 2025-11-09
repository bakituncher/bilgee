// lib/features/weakness_workshop/models/study_guide_model.dart
import 'package:taktik/core/utils/json_text_cleaner.dart';

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

    // 1) Yeni format: optionA..E
    bool hasOptionE = false;
    if (json.containsKey('optionA')) {
      parsedOptions = [
        JsonTextCleaner.cleanDynamic(json['optionA'] ?? ''),
        JsonTextCleaner.cleanDynamic(json['optionB'] ?? ''),
        JsonTextCleaner.cleanDynamic(json['optionC'] ?? ''),
        JsonTextCleaner.cleanDynamic(json['optionD'] ?? ''),
        if (json.containsKey('optionE')) JsonTextCleaner.cleanDynamic(json['optionE'] ?? ''),
      ];
      hasOptionE = json.containsKey('optionE');
      parsedOptions = parsedOptions.where((e) => e != '').toList();
    }
    // 2) Eski format: options list
    else if (json['options'] is List) {
      parsedOptions = (json['options'] as List)
          .map((option) => JsonTextCleaner.cleanDynamic(option))
          .toList();
    }

    // Boşları etiketle (çok kısa olanları da boş say)
    for (int i = 0; i < parsedOptions.length; i++) {
      if (parsedOptions[i].trim().isEmpty) {
        parsedOptions[i] = '';
      }
    }

    // Hedef minimum: optionE varsa 5; yoksa 4 (LGS ile uyum)
    final int desiredMin = hasOptionE ? 5 : 4;
    while (parsedOptions.length < desiredMin) {
      parsedOptions.add(''); // doldurma yapma; kalite koruma tamamlayacak ya da eleyecek
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
