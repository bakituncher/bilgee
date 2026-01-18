// lib/features/weakness_workshop/models/workshop_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/core/utils/json_text_cleaner.dart';

class WorkshopModel {
  final String? id; // Firestore ID (Henüz kaydedilmediyse null)
  final String subject;
  final String topic;
  final String studyGuide;
  final List<QuizQuestion> quiz;
  final Timestamp? savedDate;

  WorkshopModel({
    this.id,
    required this.subject,
    required this.topic,
    required this.studyGuide,
    required this.quiz,
    this.savedDate,
  });

  /// 1. AI Çıktısından Model Üretimi (fromAIJson)
  /// Yapay zekanın ürettiği ham JSON'u güvenli modele çevirir.
  factory WorkshopModel.fromAIJson(Map<String, dynamic> json) {
    var quizList = (json['quiz'] as List<dynamic>?)
        ?.map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
        .toList() ?? [];

    return WorkshopModel(
      id: null,
      subject: json['subject'] ?? "Bilinmeyen Ders",
      topic: json['topic'] ?? "Bilinmeyen Konu",
      studyGuide: json['studyGuide'] ?? "# Bilgi Alınamadı",
      quiz: quizList,
      savedDate: Timestamp.now(), // Oluşturulma anı
    );
  }

  /// 2. Firestore'dan Model Üretimi (fromSnapshot)
  /// Veritabanından okurken kullanılır.
  factory WorkshopModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return WorkshopModel(
      id: doc.id,
      subject: data['subject'] ?? '',
      topic: data['topic'] ?? '',
      studyGuide: data['studyGuide'] ?? '',
      quiz: (data['quiz'] as List<dynamic>?)
          ?.map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList() ?? [],
      savedDate: data['savedDate'],
    );
  }

  /// 3. Firestore'a Yazma (toMap)
  /// List<QuizQuestion> -> List<Map> dönüşümünü burada güvenle yaparız.
  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'topic': topic,
      'studyGuide': studyGuide,
      'quiz': quiz.map((q) => q.toMap()).toList(), // Tip güvenli seri hale getirme
      'savedDate': savedDate ?? FieldValue.serverTimestamp(),
    };
  }

  /// Helper: Veri güncellemeleri için
  WorkshopModel copyWith({
    String? id,
    String? subject,
    String? topic,
    String? studyGuide,
    List<QuizQuestion>? quiz,
    Timestamp? savedDate,
  }) {
    return WorkshopModel(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      topic: topic ?? this.topic,
      studyGuide: studyGuide ?? this.studyGuide,
      quiz: quiz ?? this.quiz,
      savedDate: savedDate ?? this.savedDate,
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

  /// Hem AI formatını (optionA...) hem Firestore formatını (options listesi) okur.
  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    List<String> parsedOptions = [];

    // A. AI Formatı: optionA, optionB... (Genelde üretim aşamasında gelir)
    if (json.containsKey('optionA')) {
      parsedOptions = [
        JsonTextCleaner.cleanDynamic(json['optionA'] ?? ''),
        JsonTextCleaner.cleanDynamic(json['optionB'] ?? ''),
        JsonTextCleaner.cleanDynamic(json['optionC'] ?? ''),
        JsonTextCleaner.cleanDynamic(json['optionD'] ?? ''),
        if (json.containsKey('optionE')) JsonTextCleaner.cleanDynamic(json['optionE'] ?? ''),
      ];
      // Boş gelen şıkları temizle
      parsedOptions = parsedOptions.where((e) => e.isNotEmpty).toList();
    }
    // B. Standart Format: options Listesi (Firestore'dan gelir)
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

  /// Firestore'a kaydetmek için Map'e çevirir.
  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'explanation': explanation,
    };
  }
}
