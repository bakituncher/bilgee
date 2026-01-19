// lib/features/weakness_workshop/models/workshop_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/core/utils/json_text_cleaner.dart';

class WorkshopModel {
  final String? id; // Firestore ID (Henüz kaydedilmediyse null)
  final String subject;
  final String topic;
  final String? studyGuide; // Optional: Sadece quiz seçildiyse null olabilir
  final List<QuizQuestion>? quiz; // Optional: Sadece konu anlatımı seçildiyse null/empty olabilir
  final Timestamp? savedDate;

  WorkshopModel({
    this.id,
    required this.subject,
    required this.topic,
    this.studyGuide,
    this.quiz,
    this.savedDate,
  });

  /// 1. AI Çıktısından Model Üretimi (fromAIJson)
  /// Yapay zekanın ürettiği ham JSON'u güvenli modele çevirir.
  factory WorkshopModel.fromAIJson(Map<String, dynamic> json) {
    var quizList = (json['quiz'] as List<dynamic>?)
        ?.map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
        .toList();

    return WorkshopModel(
      id: null,
      subject: json['subject'] ?? "Bilinmeyen Ders",
      topic: json['topic'] ?? "Bilinmeyen Konu",
      studyGuide: json['studyGuide'], // Null olabilir (sadece quiz modu)
      quiz: quizList, // Null olabilir (sadece konu anlatımı modu)
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
      if (studyGuide != null) 'studyGuide': studyGuide,
      if (quiz != null) 'quiz': quiz!.map((q) => q.toMap()).toList(),
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

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    List<String> parsedOptions = [];

    // DURUM 1: Firestore Kaydı (Liste Formatı)
    if (json['options'] is List) {
      parsedOptions = (json['options'] as List)
          .map((e) => JsonTextCleaner.cleanDynamic(e))
          .toList();
    }
    // DURUM 2: AI Çıktısı (Key Formatı - Prompt Kuralına Uygun)
    else {
      // "Defensive coding" zehrinden arındırılmış, net mantık:
      // Prompt optionA...optionE dönecek dendi, o zaman bunları alıyoruz.
      final opts = [
        json['optionA'],
        json['optionB'],
        json['optionC'],
        json['optionD'],
        json['optionE']
      ];
      // Null olmayanları temizle ve ekle
      parsedOptions = opts
          .where((e) => e != null)
          .map((e) => JsonTextCleaner.cleanDynamic(e))
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return QuizQuestion(
      question: JsonTextCleaner.cleanDynamic(json['question'] ?? 'Soru Metni Yok'),
      options: parsedOptions,
      correctOptionIndex: (json['correctOptionIndex'] as num?)?.toInt() ?? 0,
      explanation: JsonTextCleaner.cleanDynamic(json['explanation'] ?? ''),
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
